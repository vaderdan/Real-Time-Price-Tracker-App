//
//  ContentView.swift
//  RealTimePriceTracker
//
//  Created by danny on 29.11.25.
//

import SwiftUI
import Starscream
import Combine

struct StockDelta: Decodable, Hashable {
    var symbol: String
    var delta_price: Double
}

struct StockSymbol: Decodable, Hashable {
    var initial_price: Double
    var company: String
    var description: String
    var symbol: String

    var delta_price_old: Double? = 0.0
    var delta_price: Double? = 0.0
}

class StockManager: ObservableObject {
    @Published var stocks: [StockSymbol] = []
    @Published var blinking: [Bool] = []
    
    
    init()
    {
        stocks = fetchStocks()
    }
    
    func fetchStocks() -> [StockSymbol] {
        let url = Bundle.main.url(forResource: "stocks", withExtension: "json")
        let data: Data
        data = try! Data(contentsOf: url!)
        return try! JSONDecoder().decode([StockSymbol].self, from: data)
            .sorted(by: { lhs, rhs in
                lhs.initial_price > rhs.initial_price
            })
    }
    
    func updateDeltaPrice(delta : StockDelta) {
        stocks = stocks
            .map { item in
                if item.symbol == delta.symbol {
                    return StockSymbol(
                        initial_price: item.initial_price,
                        company: item.company,
                        description: item.description,
                        symbol: item.symbol,
                        delta_price_old: item.delta_price ?? 0.0,
                        delta_price: delta.delta_price
                    )
                }
                return item
            }
            .sorted(by: { lhs, rhs in
                (lhs.initial_price + (lhs.delta_price ?? 0)) >
                (rhs.initial_price + (rhs.delta_price ?? 0))
            })
    }
}

struct StockDetailView: View {
    @ObservedObject var stockManager: StockManager
    let symbol: String

    private var stock: StockSymbol? {
        stockManager.stocks.first(where: { $0.symbol == symbol })
    }
    
    @State private var cancelables: Set<AnyCancellable> = []
    @State private var blinking: Bool = false
    
    var body: some View {
        Group {
            if let stock {
                HStack {
                    Text("Selected stock: \(stock.company)")
                    Text(stock.symbol)
                    Spacer()
                    Text(stock.initial_price + (stock.delta_price ?? 0.0), format: .number.precision(.fractionLength(2)))
                    Image((stock.delta_price ?? 0) >= 0 ? "up" : "down")
                        .resizable()
                        .frame(width: 20, height: 20)
                        .scaledToFill()
                        .clipped()
                        .foregroundStyle(.tint)
                }
                .opacity(blinking ? 0 : 1)
                .animation(.easeOut(duration: 0.5))
                .task {
                    self.stockManager.$stocks
                        .compactMap { item -> StockSymbol? in
                            let firstItem = item.first { item -> Bool  in
                                return symbol == item.symbol
                            }
                            return firstItem
                        }
                        .removeDuplicates()
                        .sink(receiveValue: { s in
//                            print(">", s.delta_price as Any, s.delta_price_old as Any)
                            withAnimation {
                                blinking = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                                    blinking = false
                                })
                            }
                        })
                        .store(in: &cancelables)
                }
            } else {
                Text("Stock not found")
            }
        }
        
    }
}

struct StockListView: View {
    @ObservedObject var stockManager: StockManager
    @State private var blinking: Bool = false
    @State private var cancelables: Set<AnyCancellable> = []
    var item: StockSymbol
    
    var body: some View {
        HStack{
            Text(item.symbol)
            Text(item.initial_price + (item.delta_price ?? 0.0), format: .number.precision(.fractionLength(2)))
            Image((item.delta_price ?? 0) >= 0 ? "up" : "down")
                .resizable()
                .frame(width: 20, height: 20)
                .scaledToFill()
                .clipped()
                .foregroundStyle(.tint)
        }
        .opacity(blinking ? 0 : 1)
        .animation(.easeOut(duration: 0.5))
        .task {
            self.stockManager.$stocks
                .compactMap { item -> StockSymbol? in
                    let firstItem = item.first { item -> Bool  in
                        return self.item.symbol == item.symbol
                    }
                    return firstItem
                }
                .removeDuplicates()
                .sink(receiveValue: { s in
//                            print(">", s.delta_price as Any, s.delta_price_old as Any)
                    withAnimation {
                        blinking = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                            blinking = false
                        })
                    }
                })
                .store(in: &cancelables)
        }
    }
}

struct ContentView: View {
    @StateObject private var stockManager: StockManager = .init()
    @State private var started: Bool = true
    @State private var sockets: [WebSocket] = []
    @State private var connectedCount: Int = 0
    
    
    
    func disconnectAllSockets() {
        connectedCount = sockets.count
        sockets.forEach { socket in
            socket.disconnect()
        }
    }
    
    func connectAllSockets() {
        sockets.forEach { socket in
            socket.connect()
        }
    }
    
    func startSocket(stock: StockSymbol, isConnectedCallback: @escaping (Bool) -> Void, callback: @escaping (StockDelta) -> Void) -> WebSocket {
        var request = URLRequest(url: URL(string: "wss://ws.postman-echo.com/raw")!)
        request.timeoutInterval = 5
        let socket = WebSocket(request: request)
        
        socket.onEvent = { event in
            switch event {
            case .connected(_):
                isConnectedCallback(true)
            case .cancelled:
                isConnectedCallback(false)
            case .text(let string):
                if let data = string.data(using: .utf8),
                   let delta = try? JSONDecoder().decode(StockDelta.self, from: data) {
                    callback(delta)
                }
            case .error(let error):
                print("Error: \(String(describing: error))")
            default:
                break
            }
        }
        socket.connect()
        
        Timer.scheduledTimer(withTimeInterval: 2 + Double.random(in: 0..<0.5), repeats: true) { _ in
            socket.write(string: "{ \"symbol\": \"\(stock.symbol)\", \"delta_price\": \(Double.random(in: -20...20)) }", completion: nil)
        }
        
        return socket
    }
    
    var body: some View {
        VStack {
            NavigationStack {
                List(stockManager.stocks, id: \.self) { item in
                    NavigationLink {
                        StockDetailView(stockManager: stockManager, symbol: item.symbol)
                    } label: {
                        StockListView(stockManager: stockManager, item: item)
                    }
                    
                }
                .navigationTitle("Stocks")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { Image(connectedCount >= sockets.count ? "on" : "off")
                        .resizable()
                        .frame(width: 20, height: 20) }
                    ToolbarItem(placement: .primaryAction) {
                        Button(started == true ? "Stop" : "Start") {
                            started.toggle()
                            
                            if (!started) {
                                disconnectAllSockets()
                            } else {
                                connectAllSockets()
                            }
                        }
                    }
                }
            }
            
        }
        .padding()
        .onAppear {
            sockets = stockManager.stocks.map { item in
                startSocket(stock: item, isConnectedCallback: { connected in
                    if(connected) {
                        connectedCount += 1
                    } else {
                        connectedCount -= 1
                    }
                }) { delta in
                    // Ensure state mutation happens on the main actor
                    DispatchQueue.main.async {
                        stockManager.updateDeltaPrice(delta: delta)
                    }
                }
            }
        }
    }
    
}

#Preview {
    ContentView()
}
