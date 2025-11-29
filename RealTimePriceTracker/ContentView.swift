//
//  ContentView.swift
//  RealTimePriceTracker
//
//  Created by danny on 29.11.25.
//

import SwiftUI


struct StockSymbol: Decodable, Hashable {
    var initial_price: Double
    var company: String
    var description: String
    var symbol: String
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
    
    func fetchStocks() -> [StockSymbol] {
        let url = Bundle.main.url(forResource: "stocks", withExtension: "json")
        let data: Data
        data = try! Data(contentsOf: url!)
        return try! JSONDecoder().decode([StockSymbol].self, from: data)
            .sorted(by: { lhs, rhs in
            lhs.initial_price > rhs.initial_price
        })
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
                            Text(item.initial_price, format: .number.precision(.fractionLength(2)))
                            Image(systemName: "arrow.2.circlepath.circle")
                                .imageScale(.large)
                                .foregroundStyle(.tint)
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
        }
    }
}

#Preview {
    ContentView()
}
