class ApiConfig {
  // Socket URL
  static const String socketUrl = 'http://65.0.196.122:8085';
   // static const String socketPath = '/wallet-socket.io'; //
  static const String socketPath = "/wallet-socket.io/socket.io";
  // WebSocket URL for Spot trading
  static const String spotWebSocketUrl = 'wss://api4.creddx.com:9001/ws';
  
  // CoinGecko API
  static const String coinGeckoBaseUrl = 'https://api.coingecko.com/api/v3';
  static const String coinGeckoMarketsEndpoint = '$coinGeckoBaseUrl/coins/markets';
}