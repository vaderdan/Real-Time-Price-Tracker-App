//
//  ContentView.swift
//  RealTimePriceTracker
//
//  Created by danny on 29.11.25.
//

import SwiftUI
import Starscream

struct StockDelta: Decodable, Hashable {
    var symbol: String
    var delta_price: Double
}

struct StockSymbol: Decodable, Hashable {
    var initial_price: Double
    var company: String
    var description: String
    var symbol: String

    var delta_price: Double? = 0.0
}

struct StockDetailView: View {
    @State var stock: StockSymbol
    var sockets: [WebSocket] = []
    @State private var cached_onEvent: [((WebSocketEvent) -> Void)?] = []

    var body: some View {
        HStack {
            Text("Selected stock: \(stock.company)")
            Text(stock.symbol)
            Text(stock.initial_price + (stock.delta_price ?? 0.0), format: .number.precision(.fractionLength(2)))
            Image((stock.delta_price ?? 0) >= 0 ? "up" : "down")
                .resizable()
                .frame(width: 20, height: 20)
                .scaledToFill()
                .clipped()
                .foregroundStyle(.tint)
        }
        .onDisappear() {
            sockets.forEach { item in
                item.onEvent = cached_onEvent.popLast()!
            }
        }
        .onAppear() {
            sockets.forEach { item in
                cached_onEvent.append(item.onEvent)
                item.onEvent = { event in
                    switch event {
                    case .text(let string):
                        if let data = string.data(using: .utf8),
                           let delta = try? JSONDecoder().decode(StockDelta.self, from: data) {
                            if stock.symbol == delta.symbol {
                                stock.delta_price = delta.delta_price
                            }
                        }
                    case .error(let error):
                        print("Error: \(String(describing: error))")
                    default:
                        break
                    }
                }
            }
        }
        
    }
}

struct ContentView: View {
    @State private var stocks: [StockSymbol] = []
    @State private var started: Bool = true
    @State private var sockets: [WebSocket] = []
    @State private var connectedCount: Int = 0
    
    func fetchStocks() -> [StockSymbol] {
        let url = Bundle.main.url(forResource: "stocks", withExtension: "json")
        let data: Data
        data = try! Data(contentsOf: url!)
        return try! JSONDecoder().decode([StockSymbol].self, from: data)
            .sorted(by: { lhs, rhs in
                lhs.initial_price > rhs.initial_price
            })
    }
    
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
        
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            socket.write(string: "{ \"symbol\": \"\(stock.symbol)\", \"delta_price\": \(Double.random(in: -20...20)) }", completion: nil)
        }
        
        return socket
    }
    
    var body: some View {
        VStack {
            NavigationStack {
                List(stocks, id: \.self) { item in
                    NavigationLink {
                        StockDetailView(stock: item, sockets: sockets)
                    } label: {
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
                    }
                    
                }
                .navigationTitle("Stocks")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { Text( "Conn").foregroundColor(connectedCount >= sockets.count ? .green : .red) }
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
            stocks = fetchStocks()
            
            sockets = stocks.map { item in
                startSocket(stock: item, isConnectedCallback: { connected in
                    if(connected) {
                        connectedCount += 1
                    } else {
                        connectedCount -= 1
                    }
                }) { delta in
                    // Ensure state mutation happens on the main actor
                    DispatchQueue.main.async {
                        stocks = stocks
                            .map { item in
                                if item.symbol == delta.symbol {
                                    return StockSymbol(
                                        initial_price: item.initial_price,
                                        company: item.company,
                                        description: item.description,
                                        symbol: item.symbol,
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
            }
        }
    }
}

#Preview {
    ContentView()
}
