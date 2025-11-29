# RealTimePriceTracker

A SwiftUI app that demonstrates real-time stock price updates using WebSockets via Starscream. It loads an initial list of stocks from a bundled JSON file and simulates live price deltas by sending randomized updates to an echo WebSocket server. The UI shows a sortable list of stocks, connection status, and a detail view that live-updates a selected stock.

## Features

- SwiftUI UI with NavigationStack and a detail view
- Real-time price delta updates via WebSockets (Starscream)
- Mock streaming using an echo server (no backend required)
- Live-updating list sorted by current price (initial + delta)
- Connection status indicator and Start/Stop control
- Per-stock detail screen that temporarily intercepts socket events

## Requirements

- Xcode 15 or later
- Swift 5.9 or later
- iOS 17 (adjust as needed)
- Starscream (via Swift Package Manager)

## Architecture Overview

- Models
  - `StockSymbol`: Decodable and Hashable model with initial_price, company, description, symbol, and an optional delta_price.
  - `StockDelta`: Decodable and Hashable model with symbol and delta_price.
- Networking
  - Uses Starscream’s `WebSocket` to connect to `wss://ws.postman-echo.com/raw`.
  - Each stock has its own socket. A repeating timer writes randomized deltas to the socket, which the echo server returns, allowing the app to parse its own messages.
- State & UI
  - `ContentView`:
    - Loads `stocks.json` from the app bundle.
    - Creates a WebSocket per stock with `startSocket`.
    - Maintains an array of `stocks`, an array of `sockets`, and a `connectedCount`.
    - Handles Start/Stop to connect/disconnect all sockets.
    - Updates the list as deltas arrive and keeps it sorted by current price.
  - `StockDetailView`:
    - Displays the selected stock’s live price and direction (up/down image).
    - Temporarily overrides each socket’s `onEvent` handler to update only the selected stock, restoring original handlers on disappear.
- Assets
  - Expects images in the asset catalog: `up`, `down`, `on`, `off`.

## Installation

1. Clone the repository and open in Xcode.
2. Add Starscream via Swift Package Manager:
   - File > Add Packages...
   - Enter: https://github.com/daltoniam/Starscream
   - Add the package to the app target.
3. Ensure the asset catalog contains:
   - `up`, `down`, `on`, `off` images (20x20 or vector recommended).
4. Add `stocks.json` to the app bundle (see format below).

## Configuration

### stocks.json format

Place a `stocks.json` file in the main app bundle. Example:

```json
[
  {
    "initial_price": 150.32,
    "company": "Example Corp",
    "description": "Example description",
    "symbol": "EXMPL"
  },
  {
    "initial_price": 89.10,
    "company": "Another Inc",
    "description": "Another company",
    "symbol": "ANTR"
  }
]
