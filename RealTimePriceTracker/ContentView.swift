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
    let stock: StockSymbol

    var body: some View {
        Text("Selected stock: \(stock.company)")
            .font(.largeTitle)
    }
}

struct ContentView: View {
    @State var stocks: [StockSymbol] = []
    @State var started: Bool = true
    
    func fetchStocks() -> [StockSymbol] {
        let url = Bundle.main.url(forResource: "stocks", withExtension: "json")
        let data: Data
        data = try! Data(contentsOf: url!)
        return try! JSONDecoder().decode([StockSymbol].self, from: data)
            .sorted(by: { lhs, rhs in
            lhs.initial_price > rhs.initial_price
        })
    }
    
    func startSocket(stock: StockSymbol, callback: @escaping (StockDelta) -> Void) -> WebSocket {
        var request = URLRequest(url: URL(string: "wss://ws.postman-echo.com/raw")!)
        request.timeoutInterval = 5
        let socket = WebSocket(request: request)
        
        socket.onEvent = { event in
            switch event {
                case .connected(let headers):
                    break
                case .disconnected(let reason, let code):
                    break
                case .text(let string):
//                    print("Received text: \(string)")
                    let data = try! Data(string.utf8)
                    let delta = try! JSONDecoder().decode(StockDelta.self, from: data)
                
                    callback(delta)
                case .error(let error):
                    print("Error: \(error)")
                default:
                    break
            }
        }
        socket.connect()
        
        var timer = Timer()
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true, block: { _ in
            socket.write(string: "{ \"symbol\": \"\(stock.symbol)\", \"delta_price\": \(Double.random(in: -20...20)) }", completion: nil)
            })
        
        return socket
    }
    
    var body: some View {
        VStack {
            NavigationStack {
                List(stocks, id: \.self) { item in
                    NavigationLink {
                        StockDetailView(stock: item)
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
                    ToolbarItem(placement: .topBarLeading) { Text("Conn").foregroundColor(.green) }
                    ToolbarItem(placement: .primaryAction) {
                        Button(started == true ? "Stop" : "Start") {
                            started = !started
                        }
                    }
                }
            }
            
        }
        .navigationTitle("Menu")
        .padding()
        .onAppear()
        {
            stocks = fetchStocks()
            
            stocks.forEach { item in
                startSocket(stock: item, callback: { delta in
                    stocks = stocks.map { item in
                        if(item.symbol == delta.symbol) {
                            return StockSymbol(initial_price: item.initial_price, company: item.company, description: item.description, symbol: item.symbol, delta_price: delta.delta_price)
                        }
                        
                        return item
                    }.sorted(by: { lhs, rhs in
                        lhs.initial_price + (lhs.delta_price ?? 0) > rhs.initial_price + (rhs.delta_price ?? 0)
                    })
                })
            }
        }
    }
}

#Preview {
    ContentView()
}
