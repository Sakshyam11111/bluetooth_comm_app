import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/call_service.dart';
import '../../models/call_record.dart';

class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({Key? key}) : super(key: key);

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<CallService>(
        builder: (context, callService, child) {
          final callHistory = callService.callHistory;

          if (callHistory.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.call_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No call history',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Your call history will appear here',
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

          return Column(
            children: [
              if (callHistory.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Calls (${callHistory.length})',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      PopupMenuButton<String>(
                        onSelected: _handleMenuAction,
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'clear_all',
                            child: Row(
                              children: [
                                Icon(Icons.clear_all, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Clear All', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              Expanded(
                child: ListView.builder(
                  itemCount: callHistory.length,
                  itemBuilder: (context, index) {
                    final callRecord = callHistory[index];
                    return _buildCallTile(callRecord);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCallTile(CallRecord callRecord) {
    final callType = CallType.values[callRecord.callType];
    final isVideoCall = callType == CallType.video;
    
    IconData callIcon;
    Color callColor;
    
    if (!callRecord.wasAnswered) {
      if (callRecord.isIncoming) {
        callIcon = Icons.call_received;
        callColor = Colors.red;
      } else {
        callIcon = Icons.call_made;
        callColor = Colors.red;
      }
    } else {
      if (callRecord.isIncoming) {
        callIcon = isVideoCall ? Icons.videocam : Icons.call_received;
        callColor = Colors.green;
      } else {
        callIcon = isVideoCall ? Icons.videocam : Icons.call_made;
        callColor = Colors.blue;
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: callColor.withOpacity(0.1),
          child: Icon(
            callIcon,
            color: callColor,
          ),
        ),
        title: Text(
          callRecord.participantName,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isVideoCall ? Icons.videocam : Icons.call,
                  size: 14,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  '${isVideoCall ? 'Video' : 'Voice'} call',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              callRecord.statusText,
              style: TextStyle(
                fontSize: 12,
                color: callRecord.wasAnswered ? Colors.grey[700] : Colors.red,
                fontWeight: callRecord.wasAnswered ? FontWeight.normal : FontWeight.w500,
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatCallTime(callRecord.timestamp),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => _makeCall(callRecord, CallType.voice),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.call,
                      size: 16,
                      color: Colors.green,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _makeCall(callRecord, CallType.video),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.videocam,
                      size: 16,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: () => _showCallDetails(callRecord),
        onLongPress: () => _showCallOptions(callRecord),
      ),
    );
  }

  String _formatCallTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      if (difference.inDays == 1) {
        return 'Yesterday';
      } else {
        return '${difference.inDays} days ago';
      }
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'clear_all':
        _confirmClearAllCalls();
        break;
    }
  }

  void _confirmClearAllCalls() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Calls'),
        content: const Text('Are you sure you want to clear all call history? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearAllCalls();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  void _clearAllCalls() {
    final callService = Provider.of<CallService>(context, listen: false);
    callService.clearCallHistory();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Call history cleared'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _makeCall(CallRecord callRecord, CallType callType) async {
    final callService = Provider.of<CallService>(context, listen: false);
    
    try {
      bool success;
      if (callType == CallType.video) {
        success = await callService.startVideoCall('device_id', callRecord.participantName);
      } else {
        success = await callService.startVoiceCall('device_id', callRecord.participantName);
      }
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Starting ${callType == CallType.video ? 'video' : 'voice'} call with ${callRecord.participantName}'),
          ),
        );
      } else {
        throw Exception('Failed to start call');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start call: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showCallDetails(CallRecord callRecord) {
    final callType = CallType.values[callRecord.callType];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(callRecord.participantName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Call Type', callType == CallType.video ? 'Video Call' : 'Voice Call'),
            _buildDetailRow('Direction', callRecord.isIncoming ? 'Incoming' : 'Outgoing'),
            _buildDetailRow('Status', callRecord.statusText),
            _buildDetailRow('Date & Time', _formatFullDateTime(callRecord.timestamp)),
            if (callRecord.wasAnswered && callRecord.duration > 0)
              _buildDetailRow('Duration', callRecord.formattedDuration),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _makeCall(callRecord, callType);
            },
            child: const Text('Call Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _formatFullDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showCallOptions(CallRecord callRecord) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.call),
              title: const Text('Voice Call'),
              onTap: () {
                Navigator.pop(context);
                _makeCall(callRecord, CallType.voice);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Video Call'),
              onTap: () {
                Navigator.pop(context);
                _makeCall(callRecord, CallType.video);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Call Details'),
              onTap: () {
                Navigator.pop(context);
                _showCallDetails(callRecord);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Call', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteCall(callRecord);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteCall(CallRecord callRecord) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Call'),
        content: Text('Delete call record with ${callRecord.participantName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteCall(callRecord);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _deleteCall(CallRecord callRecord) {
    final callService = Provider.of<CallService>(context, listen: false);
    callService.deleteCallRecord(callRecord.id);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Call record with ${callRecord.participantName} deleted'),
        backgroundColor: Colors.red,
      ),
    );
  }
}