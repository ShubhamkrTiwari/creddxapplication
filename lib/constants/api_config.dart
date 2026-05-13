class ApiConfig {
  // Socket URL
  static const String socketUrl = 'https://api11.hathmetech.com';
   // static const String socketPath = '/wallet-socket.io'; //
  static const String socketPath = "/wallet-socket.io/socket.io";
  // WebSocket URL for Spot trading (using plain ws:// due to server TLS configuration)
  static const String spotWebSocketUrl = 'ws://api4.creddx.com/ws';
  // REST Base URL for Spot trading
  static const String spotBaseUrl = 'https://api4.creddx.com/orderbook';
  
  // CoinGecko API
  static const String coinGeckoBaseUrl = 'https://api.coingecko.com/api/v3';
  static const String coinGeckoMarketsEndpoint = '$coinGeckoBaseUrl/coins/markets';
}