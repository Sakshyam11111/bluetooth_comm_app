import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/bluetooth_service.dart';
import '../firebase/auth_service.dart';
import '../services/bluetooth_service.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import 'chat/chat_list_screen.dart';
import 'bluetooth/bluetooth_devices_screen.dart';
import 'groups/groups_screen.dart';
import 'calls/call_history_screen.dart';
import 'profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  
  final List<Widget> _screens = [
    const ChatListScreen(),
    const GroupsScreen(),
    const BluetoothDevicesScreen(),
    const CallHistoryScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  void _initializeServices() async {
    final bluetoothService = Provider.of<BluetoothService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    
    // Check if Bluetooth is enabled
    if (!bluetoothService.isBluetoothEnabled) {
      await bluetoothService.enableBluetooth();
    }
    
    // Start advertising with user name
    final currentUser = authService.currentUser;
    if (currentUser != null) {
      await bluetoothService.startAdvertising(currentUser.name);
      await bluetoothService.startDiscovery(currentUser.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final titles = ['Chats', 'Groups', 'Devices', 'Calls', 'Profile'];
    
    return AppBar(
      title: Text(titles[_currentIndex]),
      elevation: 0,
      actions: [
        Consumer<BluetoothService>(
          builder: (context, bluetoothService, child) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Connection status indicator
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: bluetoothService.isConnected 
                        ? Colors.green 
                        : Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        bluetoothService.isConnected 
                            ? Icons.bluetooth_connected 
                            : Icons.bluetooth,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        bluetoothService.connectedDeviceIds.length.toString(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                // More options
                PopupMenuButton<String>(
                  onSelected: _handleMenuSelection,
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'refresh',
                      child: ListTile(
                        leading: Icon(Icons.refresh),
                        title: Text('Refresh Devices'),
                        dense: true,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'settings',
                      child: ListTile(
                        leading: Icon(Icons.settings),
                        title: Text('Settings'),
                        dense: true,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: _currentIndex,
      onTap: (index) {
        setState(() {
          _currentIndex = index;
        });
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.chat),
          label: 'Chats',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.group),
          label: 'Groups',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.bluetooth),
          label: 'Devices',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.call),
          label: 'Calls',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }

  Widget? _buildFloatingActionButton() {
    switch (_currentIndex) {
      case 0: // Chats
        return FloatingActionButton(
          onPressed: () => _showNewChatDialog(),
          child: const Icon(Icons.chat),
        );
      case 1: // Groups
        return FloatingActionButton(
          onPressed: () => _showNewGroupDialog(),
          child: const Icon(Icons.group_add),
        );
      case 2: // Devices
        return FloatingActionButton(
          onPressed: () => _refreshDevices(),
          child: const Icon(Icons.refresh),
        );
      default:
        return null;
    }
  }

  void _handleMenuSelection(String value) {
    switch (value) {
      case 'refresh':
        _refreshDevices();
        break;
      case 'settings':
        Navigator.pushNamed(context, '/settings');
        break;
    }
  }

  void _showNewChatDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start New Chat'),
        content: const Text('Select a connected device to start chatting.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _currentIndex = 2; // Switch to devices tab
              });
            },
            child: const Text('Select Device'),
          ),
        ],
      ),
    );
  }

  void _showNewGroupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Group Name',
                hintText: 'Enter group name',
              ),
            ),
            const SizedBox(height: 16),
            const Text('Select members from connected devices'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement group creation
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _refreshDevices() async {
    final bluetoothService = Provider.of<BluetoothService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    
    await bluetoothService.startClassicDiscovery();
    
    final currentUser = authService.currentUser;
    if (currentUser != null) {
      await bluetoothService.startDiscovery(currentUser.name);
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Refreshing nearby devices...'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}