//
//  ContentView.swift
//  RealTimePriceTracker
//
//  Created by danny on 29.11.25.
//

import SwiftUI


struct StockSymbol: Decodable {
    var initial_price: Double
    var company: String
    var description: String
}

struct ContentView: View {
    func fetchStocks() -> [StockSymbol] {
        let url = Bundle.main.url(forResource: "stocks", withExtension: "json")
        let data: Data
        data = try! Data(contentsOf: url!)
        return try! JSONDecoder().decode([StockSymbol].self, from: data)
    }
    
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
        .onAppear()
        {
            print(fetchStocks())
        }
    }
}

#Preview {
    ContentView()
}
