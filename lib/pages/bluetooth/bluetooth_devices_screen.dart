import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/bluetooth_service.dart';
import '../../services/chat_service.dart';
import '../../firebase/auth_service.dart';
import '../../models/bluetooth_device.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class BluetoothDevicesScreen extends StatefulWidget {
  const BluetoothDevicesScreen({Key? key}) : super(key: key);

  @override
  State<BluetoothDevicesScreen> createState() => _BluetoothDevicesScreenState();
}

class _BluetoothDevicesScreenState extends State<BluetoothDevicesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Consumer<BluetoothService>(
              builder: (context, bluetoothService, child) {
                return FutureBuilder<bool>(
                  future: bluetoothService.isBluetoothEnabled,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    }
                    
                    final isEnabled = snapshot.data ?? false;

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              isEnabled
                                  ? Icons.bluetooth
                                  : Icons.bluetooth_disabled,
                              color: isEnabled ? Colors.blue : Colors.grey,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Bluetooth Status',
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                  Text(
                                    isEnabled ? 'Enabled' : 'Disabled',
                                    style: TextStyle(
                                      color: isEnabled ? Colors.green : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!isEnabled)
                              ElevatedButton(
                                onPressed: () => bluetoothService.enableBluetooth(),
                                child: const Text('Enable'),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Nearby', icon: Icon(Icons.radar)),
              Tab(text: 'Classic', icon: Icon(Icons.bluetooth_searching)),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildNearbyDevicesTab(),
                _buildClassicDevicesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyDevicesTab() {
    return Consumer<BluetoothService>(
      builder: (context, bluetoothService, child) {
        final nearbyDevices = bluetoothService.nearbyDevices;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Nearby Devices (${nearbyDevices.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (bluetoothService.isDiscovering)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    IconButton(
                      onPressed: () => _refreshNearbyDevices(),
                      icon: const Icon(Icons.refresh),
                    ),
                ],
              ),
            ),
            Expanded(
              child: nearbyDevices.isEmpty
                  ? _buildEmptyState('No nearby devices found')
                  : ListView.builder(
                      itemCount: nearbyDevices.length,
                      itemBuilder: (context, index) {
                        final device = nearbyDevices[index];
                        return _buildNearbyDeviceTile(device);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildClassicDevicesTab() {
    return Consumer<BluetoothService>(
      builder: (context, bluetoothService, child) {
        final classicDevices = bluetoothService.classicDevices;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Classic Bluetooth (${classicDevices.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (bluetoothService.isDiscovering)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    IconButton(
                      onPressed: () => _refreshClassicDevices(),
                      icon: const Icon(Icons.refresh),
                    ),
                ],
              ),
            ),
            Expanded(
              child: classicDevices.isEmpty
                  ? _buildEmptyState('No classic devices found')
                  : ListView.builder(
                      itemCount: classicDevices.length,
                      itemBuilder: (context, index) {
                        final result = classicDevices[index];
                        return _buildClassicDeviceTile(result);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bluetooth_searching,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Make sure other devices are discoverable',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyDeviceTile(BluetoothDeviceModel device) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: device.isConnected ? Colors.green : Colors.blue,
          child: Icon(
            device.isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
            color: Colors.white,
          ),
        ),
        title: Text(
          device.name.isNotEmpty ? device.name : 'Unknown Device',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: ${device.id}'),
            if (device.rssi != null)
              Text('Signal: ${device.rssi}dBm'),
          ],
        ),
        trailing: device.isConnected
            ? Chip(
                label: const Text('Connected'),
                backgroundColor: Colors.green[100],
                labelStyle: const TextStyle(color: Colors.green),
              )
            : ElevatedButton(
                onPressed: () => _connectToNearbyDevice(device),
                child: const Text('Connect'),
              ),
        onTap: device.isConnected ? () => _startChatWithDevice(device) : null,
      ),
    );
  }

  Widget _buildClassicDeviceTile(BluetoothDiscoveryResult result) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue,
          child: const Icon(
            Icons.bluetooth,
            color: Colors.white,
          ),
        ),
        title: Text(
          result.device.name ?? 'Unknown Device',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Address: ${result.device.address}'),
            if (result.rssi != null)
              Text('Signal: ${result.rssi}dBm'),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: () => _connectToClassicDevice(result.device),
          child: const Text('Connect'),
        ),
      ),
    );
  }

  void _refreshNearbyDevices() async {
    final bluetoothService = Provider.of<BluetoothService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    
    final currentUser = authService.currentUser;
    if (currentUser != null) {
      await bluetoothService.startDiscovery(currentUser.name);
    }
  }

  void _refreshClassicDevices() async {
    final bluetoothService = Provider.of<BluetoothService>(context, listen: false);
    await bluetoothService.startClassicDiscovery();
  }

  void _connectToNearbyDevice(BluetoothDeviceModel device) async {
    final bluetoothService = Provider.of<BluetoothService>(context, listen: false);
    
    try {
      await bluetoothService.connectToNearbyDevice(device.id);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connecting to ${device.name}...'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to connect: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _connectToClassicDevice(BluetoothDevice device) async {
    final bluetoothService = Provider.of<BluetoothService>(context, listen: false);
    
    try {
      final success = await bluetoothService.connectToClassicDevice(device);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to ${device.name ?? 'Unknown Device'}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Connection failed');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to connect: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _startChatWithDevice(BluetoothDeviceModel device) async {
    final chatService = Provider.of<ChatService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    
    try {
      // Create or get existing chat room
      final chatRoom = await chatService.createDirectChatRoom(
        device.id,
        device.name.isNotEmpty ? device.name : 'Unknown Device',
      );
      
      // TODO: Navigate to chat screen
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Starting chat with ${device.name}'),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start chat: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}