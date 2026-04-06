import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/material.dart';

class WebSocketTest {
  static const String _wsUrl = 'ws://13.202.34.205:9001';
  static WebSocketChannel? _channel;
  static bool _isConnected = false;
  static String _lastMessage = '';
  static String _connectionStatus = 'Disconnected';

  static Future<bool> testConnection() async {
    try {
      debugPrint('Testing WebSocket connection to: $_wsUrl');
      
      _channel = WebSocketChannel.connect(
        Uri.parse('$_wsUrl/ws'),
        protocols: ['websocket'],
      );

      _connectionStatus = 'Connecting...';
      debugPrint('WebSocket connection initiated');

      // Set a timeout for connection
      await Future.delayed(const Duration(seconds: 5));

      if (_channel != null) {
        _connectionStatus = 'Connected';
        _isConnected = true;
        debugPrint('WebSocket connected successfully');

        // Listen for messages
        _channel!.stream.listen(
          (message) {
            _lastMessage = message.toString();
            debugPrint('WebSocket message received: $_lastMessage');
            
            try {
              final data = json.decode(message);
              debugPrint('Parsed data: $data');
            } catch (e) {
              debugPrint('Error parsing message: $e');
            }
          },
          onError: (error) {
            _connectionStatus = 'Error: $error';
            _isConnected = false;
            debugPrint('WebSocket error: $error');
          },
          onDone: () {
            _connectionStatus = 'Disconnected';
            _isConnected = false;
            debugPrint('WebSocket disconnected');
          },
        );

        // Send a test message
        _channel!.sink.add(json.encode({
          'test': 'connection_check',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }));
        debugPrint('Test message sent');

        return true;
      } else {
        _connectionStatus = 'Failed to connect';
        _isConnected = false;
        debugPrint('Failed to create WebSocket connection');
        return false;
      }
    } catch (e) {
      _connectionStatus = 'Exception: $e';
      _isConnected = false;
      debugPrint('WebSocket connection exception: $e');
      return false;
    }
  }

  static void disconnect() {
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    _connectionStatus = 'Disconnected';
    debugPrint('WebSocket disconnected manually');
  }

  static bool get isConnected => _isConnected;
  static String get connectionStatus => _connectionStatus;
  static String get lastMessage => _lastMessage;
}

// Widget to test WebSocket in UI
class WebSocketTestWidget extends StatefulWidget {
  const WebSocketTestWidget({super.key});

  @override
  State<WebSocketTestWidget> createState() => _WebSocketTestWidgetState();
}

class _WebSocketTestWidgetState extends State<WebSocketTestWidget> {
  String _status = 'Press "Test Connection" to start';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        title: const Text('WebSocket Test', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0D0D0D),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Connection Status
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: WebSocketTest.isConnected 
                    ? const Color(0xFF84BD00).withOpacity(0.2) 
                    : Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: WebSocketTest.isConnected 
                      ? const Color(0xFF84BD00) 
                      : Colors.red,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        WebSocketTest.isConnected ? Icons.wifi : Icons.wifi_off,
                        color: WebSocketTest.isConnected 
                            ? const Color(0xFF84BD00) 
                            : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Status: ${WebSocketTest.connectionStatus}',
                        style: TextStyle(
                          color: WebSocketTest.isConnected 
                              ? const Color(0xFF84BD00) 
                              : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Connected: ${WebSocketTest.isConnected}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Test Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _testConnection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF84BD00),
                  foregroundColor: Colors.black,
                ),
                child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text('Test Connection'),
              ),
            ),
            const SizedBox(height: 16),
            
            // Disconnect Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  WebSocketTest.disconnect();
                  setState(() {
                    _status = 'Disconnected';
                  });
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF84BD00)),
                ),
                child: const Text(
                  'Disconnect',
                  style: TextStyle(color: Color(0xFF84BD00)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Status Display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Test Results:',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _status,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  if (WebSocketTest.lastMessage.isNotEmpty) ...[
                    const Text(
                      'Last Message:',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      WebSocketTest.lastMessage,
                      style: const TextStyle(
                        color: Color(0xFF84BD00),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing connection...';
    });

    try {
      final success = await WebSocketTest.testConnection();
      
      setState(() {
        _isLoading = false;
        _status = success 
            ? 'Connection successful!' 
            : 'Connection failed: ${WebSocketTest.connectionStatus}';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _status = 'Test failed with exception: $e';
      });
    }
  }
}
