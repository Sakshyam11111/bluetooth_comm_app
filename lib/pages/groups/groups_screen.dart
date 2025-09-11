import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/chat_service.dart';
import '../../services/bluetooth_service.dart';
import '../../firebase/auth_service.dart';
import '../../models/chat_room.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({Key? key}) : super(key: key);

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<ChatService>(
        builder: (context, chatService, child) {
          final groupChats = chatService.chatRooms
              .where((room) => room.chatType == ChatRoomType.group)
              .toList();

          if (groupChats.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.group_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No groups yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Create a group to chat with multiple people',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: groupChats.length,
            itemBuilder: (context, index) {
              final group = groupChats[index];
              return _buildGroupTile(group);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateGroupDialog,
        child: const Icon(Icons.group_add),
      ),
    );
  }

  Widget _buildGroupTile(ChatRoom group) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.purple,
          child: group.groupPicture != null
              ? ClipOval(
                  child: Image.network(
                    group.groupPicture!,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _buildGroupIcon(group),
                  ),
                )
              : _buildGroupIcon(group),
        ),
        title: Text(
          group.name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${group.participantIds.length} members',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            if (group.lastMessage != null) ...[
              const SizedBox(height: 2),
              Text(
                group.lastMessage!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey[700],
                ),
              ),
            ],
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatTime(group.lastMessageTime),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 4),
            if (group.isEncrypted)
              Icon(
                Icons.lock,
                size: 16,
                color: Colors.green[600],
              ),
          ],
        ),
        onTap: () => _openGroup(group),
        onLongPress: () => _showGroupOptions(group),
      ),
    );
  }

  Widget _buildGroupIcon(ChatRoom group) {
    return Icon(
      Icons.group,
      color: Colors.white,
      size: 24,
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _showCreateGroupDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const CreateGroupBottomSheet(),
    );
  }

  void _openGroup(ChatRoom group) {
    // TODO: Navigate to group chat screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening group: ${group.name}'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _showGroupOptions(ChatRoom group) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final isAdmin = group.adminId == authService.currentUser?.id;

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Group Info'),
              onTap: () {
                Navigator.pop(context);
                _showGroupInfo(group);
              },
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Manage Members'),
              onTap: () {
                Navigator.pop(context);
                _showManageMembers(group);
              },
            ),
            if (isAdmin) ...[
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Group'),
                onTap: () {
                  Navigator.pop(context);
                  _editGroup(group);
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.notifications_off),
              title: const Text('Mute Group'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement mute functionality
              },
            ),
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.orange),
              title: const Text('Leave Group', style: TextStyle(color: Colors.orange)),
              onTap: () {
                Navigator.pop(context);
                _confirmLeaveGroup(group);
              },
            ),
            if (isAdmin) ...[
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Group', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteGroup(group);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showGroupInfo(ChatRoom group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(group.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Members: ${group.participantIds.length}'),
            const SizedBox(height: 8),
            Text('Created: ${_formatTime(group.lastMessageTime)}'),
            if (group.isEncrypted) ...[
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(Icons.lock, size: 16, color: Colors.green),
                  SizedBox(width: 4),
                  Text('End-to-end encrypted', style: TextStyle(color: Colors.green)),
                ],
              ),
            ],
            if (group.adminId != null) ...[
              const SizedBox(height: 8),
              Text('Admin ID: ${group.adminId}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showManageMembers(ChatRoom group) {
    // TODO: Implement member management
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Member management coming soon'),
      ),
    );
  }

  void _editGroup(ChatRoom group) {
    // TODO: Implement group editing
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Group editing coming soon'),
      ),
    );
  }

  void _confirmLeaveGroup(ChatRoom group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Group'),
        content: Text('Are you sure you want to leave "${group.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _leaveGroup(group);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteGroup(ChatRoom group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Group'),
        content: Text('Are you sure you want to delete "${group.name}"? This action cannot be undone and all messages will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteGroup(group);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _leaveGroup(ChatRoom group) {
    // TODO: Implement leave group functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Left group: ${group.name}'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _deleteGroup(ChatRoom group) {
    final chatService = Provider.of<ChatService>(context, listen: false);
    chatService.deleteChatRoom(group.id);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Group "${group.name}" deleted'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

class CreateGroupBottomSheet extends StatefulWidget {
  const CreateGroupBottomSheet({Key? key}) : super(key: key);

  @override
  State<CreateGroupBottomSheet> createState() => _CreateGroupBottomSheetState();
}

class _CreateGroupBottomSheetState extends State<CreateGroupBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _groupNameController = TextEditingController();
  final List<String> _selectedMembers = [];

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Create New Group',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _groupNameController,
              decoration: const InputDecoration(
                labelText: 'Group Name',
                hintText: 'Enter group name',
                prefixIcon: Icon(Icons.group),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a group name';
                }
                if (value.trim().length < 2) {
                  return 'Group name must be at least 2 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Select Members',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Consumer<BluetoothService>(
                builder: (context, bluetoothService, child) {
                  final connectedDevices = bluetoothService.nearbyDevices
                      .where((device) => device.isConnected)
                      .toList();

                  if (connectedDevices.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bluetooth_disabled, color: Colors.grey),
                          SizedBox(height: 8),
                          Text(
                            'No connected devices',
                            style: TextStyle(color: Colors.grey),
                          ),
                          Text(
                            'Connect to devices first',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: connectedDevices.length,
                    itemBuilder: (context, index) {
                      final device = connectedDevices[index];
                      final isSelected = _selectedMembers.contains(device.id);

                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (selected) {
                          setState(() {
                            if (selected == true) {
                              _selectedMembers.add(device.id);
                            } else {
                              _selectedMembers.remove(device.id);
                            }
                          });
                        },
                        title: Text(device.name.isNotEmpty ? device.name : 'Unknown Device'),
                        subtitle: Text('ID: ${device.id}'),
                        secondary: const CircleAvatar(
                          backgroundColor: Colors.green,
                          child: Icon(Icons.bluetooth_connected, color: Colors.white),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Selected: ${_selectedMembers.length} members',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _selectedMembers.isEmpty ? null : _createGroup,
                    child: const Text('Create Group'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _createGroup() async {
    if (!_formKey.currentState!.validate() || _selectedMembers.isEmpty) {
      return;
    }

    final chatService = Provider.of<ChatService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      final currentUser = authService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final group = await chatService.createGroupChatRoom(
        _groupNameController.text.trim(),
        [currentUser.id, ..._selectedMembers], // Include current user
        currentUser.id, // Current user as admin
      );

      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Group "${group.name}" created successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create group: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}