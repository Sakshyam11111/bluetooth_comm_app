import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:crypto/crypto.dart';
import '../models/bluetooth_device.dart';
import '../models/message.dart';

class BluetoothService extends ChangeNotifier {
  static const String SERVICE_ID = 'com.bluetoothcomm.app';
  static const String STRATEGY = Strategy.P2P_CLUSTER;
  
  final FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;
  BluetoothConnection? _connection;
  
  bool _isConnectedToClassic = false;
  bool _isAdvertising = false;
  bool _isDiscovering = false;
  bool _isConnectedToNearby = false;
  
  final List<BluetoothDiscoveryResult> _classicDevices = [];
  final List<BluetoothDeviceModel> _nearbyDevices = [];
  final List<String> _connectedDeviceIds = [];
  
  StreamSubscription<BluetoothDiscoveryResult>? _discoverySubscription;
  StreamSubscription<Uint8List>? _dataSubscription;
  
  // Getters
  bool get isBluetoothEnabled => _bluetooth.isEnabled ?? false;
  bool get isConnected => _isConnectedToClassic || _isConnectedToNearby;
  bool get isAdvertising => _isAdvertising;
  bool get isDiscovering => _isDiscovering;
  List<BluetoothDiscoveryResult> get classicDevices => _classicDevices;
  List<BluetoothDeviceModel> get nearbyDevices => _nearbyDevices;
  List<String> get connectedDeviceIds => _connectedDeviceIds;

  BluetoothService() {
    _initializeNearbyConnections();
  }

  Future<void> _initializeNearbyConnections() async {
    await Nearby().initialize();
  }

  // Enable Bluetooth
  Future<bool> enableBluetooth() async {
    try {
      await _bluetooth.requestEnable();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error enabling Bluetooth: $e');
      return false;
    }
  }

  // Start advertising for Nearby Connections
  Future<bool> startAdvertising(String userName) async {
    try {
      await Nearby().startAdvertising(
        userName,
        STRATEGY as Strategy,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
        serviceId: SERVICE_ID,
      );
      _isAdvertising = true;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error starting advertising: $e');
      return false;
    }
  }

  // Start discovery for Nearby Connections
  Future<bool> startDiscovery(String userName) async {
    try {
      await Nearby().startDiscovery(
        userName,
        STRATEGY as Strategy,
        onEndpointFound: _onEndpointFound,
        onEndpointLost: _onEndpointLost,
        serviceId: SERVICE_ID,
      );
      _isDiscovering = true;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error starting discovery: $e');
      return false;
    }
  }

  // Classic Bluetooth discovery
  Future<void> startClassicDiscovery() async {
    try {
      _classicDevices.clear();
      _discoverySubscription?.cancel();
      
      _discoverySubscription = _bluetooth.startDiscovery().listen(
        (result) {
          final existingIndex = _classicDevices.indexWhere(
            (device) => device.device.address == result.device.address,
          );
          
          if (existingIndex >= 0) {
            _classicDevices[existingIndex] = result;
          } else {
            _classicDevices.add(result);
          }
          notifyListeners();
        },
      );
      
      _discoverySubscription!.onDone(() {
        _isDiscovering = false;
        notifyListeners();
      });
    } catch (e) {
      debugPrint('Error starting classic discovery: $e');
    }
  }

  // Connect to classic Bluetooth device
  Future<bool> connectToClassicDevice(BluetoothDevice device) async {
    try {
      _connection = await BluetoothConnection.toAddress(device.address);
      _isConnectedToClassic = true;
      
      _dataSubscription = _connection!.input!.listen(
        _onDataReceived,
        onDone: () {
          _disconnect();
        },
      );
      
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error connecting to classic device: $e');
      return false;
    }
  }

  // Connect to nearby device
  Future<void> connectToNearbyDevice(String endpointId) async {
    try {
      await Nearby().requestConnection(
        'User', // Current user name
        endpointId,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );
    } catch (e) {
      debugPrint('Error connecting to nearby device: $e');
    }
  }

  // Send message
  Future<bool> sendMessage(Message message) async {
    try {
      final messageJson = jsonEncode(message.toJson());
      final messageBytes = utf8.encode(messageJson);
      
      if (_isConnectedToClassic && _connection != null) {
        _connection!.output.add(messageBytes);
        await _connection!.output.allSent;
        return true;
      }
      
      if (_isConnectedToNearby && _connectedDeviceIds.isNotEmpty) {
        for (String deviceId in _connectedDeviceIds) {
          await Nearby().sendBytesPayload(deviceId, messageBytes);
        }
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('Error sending message: $e');
      return false;
    }
  }

  // Broadcast message to all connected devices
  Future<void> broadcastMessage(Message message) async {
    try {
      final messageJson = jsonEncode(message.toJson());
      final messageBytes = utf8.encode(messageJson);
      
      // Send to all nearby connected devices
      for (String deviceId in _connectedDeviceIds) {
        await Nearby().sendBytesPayload(deviceId, messageBytes);
      }
      
      // Send to classic connection if available
      if (_isConnectedToClassic && _connection != null) {
        _connection!.output.add(messageBytes);
        await _connection!.output.allSent;
      }
    } catch (e) {
      debugPrint('Error broadcasting message: $e');
    }
  }

  // Event handlers for Nearby Connections
  void _onEndpointFound(String endpointId, String endpointName, String serviceId) {
    final device = BluetoothDeviceModel(
      id: endpointId,
      name: endpointName,
      isConnected: false,
    );
    
    final existingIndex = _nearbyDevices.indexWhere((d) => d.id == endpointId);
    if (existingIndex >= 0) {
      _nearbyDevices[existingIndex] = device;
    } else {
      _nearbyDevices.add(device);
    }
    notifyListeners();
  }

  void _onEndpointLost(String endpointId) {
    _nearbyDevices.removeWhere((device) => device.id == endpointId);
    notifyListeners();
  }

  void _onConnectionInitiated(String endpointId, ConnectionInfo connectionInfo) {
    // Auto-accept connection (you might want to show a dialog to user)
    Nearby().acceptConnection(
      endpointId,
      onPayLoadRecieved: _onPayloadReceived,
      onPayloadTransferUpdate: _onPayloadTransferUpdate, onPayLoadRecieved: (String endpointId, Payload payload) {  },
    );
  }

  void _onConnectionResult(String endpointId, Status status) {
    if (status == Status.CONNECTED) {
      _connectedDeviceIds.add(endpointId);
      _isConnectedToNearby = true;
      
      // Update device status
      final deviceIndex = _nearbyDevices.indexWhere((d) => d.id == endpointId);
      if (deviceIndex >= 0) {
        _nearbyDevices[deviceIndex] = _nearbyDevices[deviceIndex].copyWith(isConnected: true);
      }
    } else {
      _connectedDeviceIds.remove(endpointId);
      if (_connectedDeviceIds.isEmpty) {
        _isConnectedToNearby = false;
      }
    }
    notifyListeners();
  }

  void _onDisconnected(String endpointId) {
    _connectedDeviceIds.remove(endpointId);
    if (_connectedDeviceIds.isEmpty) {
      _isConnectedToNearby = false;
    }
    
    // Update device status
    final deviceIndex = _nearbyDevices.indexWhere((d) => d.id == endpointId);
    if (deviceIndex >= 0) {
      _nearbyDevices[deviceIndex] = _nearbyDevices[deviceIndex].copyWith(isConnected: false);
    }
    
    notifyListeners();
  }

  void _onPayloadReceived(String endpointId, Payload payload) {
    if (payload.type == PayloadType.BYTES) {
      _onDataReceived(payload.bytes!);
    }
  }

  void _onPayloadTransferUpdate(String endpointId, PayloadTransferUpdate update) {
    // Handle file transfer updates if needed
  }

  // Handle received data
  void _onDataReceived(Uint8List data) {
    try {
      final messageString = utf8.decode(data);
      final messageJson = jsonDecode(messageString);
      final message = Message.fromJson(messageJson);
      
      // Notify listeners about new message
      // You'll need to implement this in your chat service
      debugPrint('Received message: ${message.content}');
    } catch (e) {
      debugPrint('Error processing received data: $e');
    }
  }

  // Stop all operations
  Future<void> stopAll() async {
    await _disconnect();
    await _stopDiscovery();
    await _stopAdvertising();
  }

  Future<void> _disconnect() async {
    _connection?.close();
    _connection = null;
    _isConnectedToClassic = false;
    
    for (String deviceId in _connectedDeviceIds) {
      await Nearby().disconnectFromEndpoint(deviceId);
    }
    _connectedDeviceIds.clear();
    _isConnectedToNearby = false;
    
    notifyListeners();
  }

  Future<void> _stopDiscovery() async {
    _discoverySubscription?.cancel();
    await Nearby().stopDiscovery();
    _isDiscovering = false;
    notifyListeners();
  }

  Future<void> _stopAdvertising() async {
    await Nearby().stopAdvertising();
    _isAdvertising = false;
    notifyListeners();
  }

  @override
  void dispose() {
    stopAll();
    _discoverySubscription?.cancel();
    _dataSubscription?.cancel();
    super.dispose();
  }
}