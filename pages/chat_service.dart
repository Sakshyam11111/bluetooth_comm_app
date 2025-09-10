import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_room.dart';
import '../models/message.dart';
import '../models/user.dart';
import 'bluetooth_service.dart';
import 'firebase_service.dart';

class ChatService extends ChangeNotifier {
  static const String CHAT_ROOMS_BOX = 'chat_rooms';
  static const String MESSAGES_BOX = 'messages';
  
  final BluetoothService _bluetoothService;
  final FirebaseService _firebaseService;
  final Uuid _uuid = Uuid();
  
  Box<ChatRoom>? _chatRoomsBox;
  Box<Message>? _messagesBox;
  
  List<ChatRoom> _chatRooms = [];
  Map<String, List<Message>> _messagesCache = {};
  String? _currentChatRoomId;

  // Getters
  List<ChatRoom> get chatRooms => _chatRooms;
  String? get currentChatRoomId => _currentChatRoomId;
  
  ChatService(this._bluetoothService, this._firebaseService) {
    _initializeBoxes();
    _listenToBluetoothMessages();
  }

  Future<void> _initializeBoxes() async {
    try {
      _chatRoomsBox = await Hive.openBox<ChatRoom>(CHAT_ROOMS_BOX);
      _messagesBox = await Hive.openBox<Message>(MESSAGES_BOX);
      _loadChatRooms();
    } catch (e) {
      debugPrint('Error initializing chat boxes: $e');
    }
  }

  void _loadChatRooms() {
    if (_chatRoomsBox != null) {
      _chatRooms = _chatRoomsBox!.values.toList();
      _chatRooms.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
      notifyListeners();
    }
  }

  void _listenToBluetoothMessages() {
    // This would be implemented to listen to incoming messages from BluetoothService
    // For now, this is a placeholder
  }

  // Create a new direct chat room
  Future<ChatRoom> createDirectChatRoom(String participantId, String participantName) async {
    final chatRoomId = _uuid.v4();
    
    final chatRoom = ChatRoom(
      id: chatRoomId,
      name: participantName,
      type: ChatRoomType.direct.index,
      participantIds: [participantId],
      lastMessageTime: DateTime.now(),
    );

    await _saveChatRoom(chatRoom);
    return chatRoom;
  }

  // Create a new group chat room
  Future<ChatRoom> createGroupChatRoom(String groupName, List<String> participantIds, String adminId) async {
    final chatRoomId = _uuid.v4();
    
    final chatRoom = ChatRoom(
      id: chatRoomId,
      name: groupName,
      type: ChatRoomType.group.index,
      participantIds: participantIds,
      adminId: adminId,
      lastMessageTime: DateTime.now(),
    );

    await _saveChatRoom(chatRoom);
    return chatRoom;
  }

  // Send a message
  Future<bool> sendMessage({
    required String chatRoomId,
    required String content,
    required String senderId,
    required String senderName,
    MessageType messageType = MessageType.text,
    String? filePath,
  }) async {
    final messageId = _uuid.v4();
    
    final message = Message(
      id: messageId,
      senderId: senderId,
      senderName: senderName,
      chatRoomId: chatRoomId,
      content: content,
      messageType: messageType.index,
      timestamp: DateTime.now(),
      status: MessageStatus.sending.index,
      filePath: filePath,
    );

    // Save message locally
    await _saveMessage(message);
    
    // Send via Bluetooth
    final success = await _bluetoothService.sendMessage(message);
    
    // Update message status
    message.status = success ? MessageStatus.sent.index : MessageStatus.failed.index;
    await _updateMessage(message);
    
    // Update chat room's last message
    await _updateChatRoomLastMessage(chatRoomId, content);
    
    // Sync to Firebase if internet is available
    _syncToFirebase(message);
    
    return success;
  }

  // Get messages for a specific chat room
  List<Message> getMessages(String chatRoomId) {
    if (_messagesCache.containsKey(chatRoomId)) {
      return _messagesCache[chatRoomId]!;
    }

    if (_messagesBox != null) {
      final messages = _messagesBox!.values
          .where((message) => message.chatRoomId == chatRoomId)
          .toList();
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      
      _messagesCache[chatRoomId] = messages;
      return messages;
    }

    return [];
  }

  // Set current chat room
  void setCurrentChatRoom(String chatRoomId) {
    _currentChatRoomId = chatRoomId;
    notifyListeners();
  }

  // Handle incoming message
  Future<void> handleIncomingMessage(Message message) async {
    await _saveMessage(message);
    await _updateChatRoomLastMessage(message.chatRoomId, message.content);
    
    // Update cache
    if (_messagesCache.containsKey(message.chatRoomId)) {
      _messagesCache[message.chatRoomId]!.add(message);
    }
    
    // Sync to Firebase if internet is available
    _syncToFirebase(message);
    
    notifyListeners();
  }

  // Save chat room to local storage
  Future<void> _saveChatRoom(ChatRoom chatRoom) async {
    if (_chatRoomsBox != null) {
      await _chatRoomsBox!.put(chatRoom.id, chatRoom);
      _chatRooms.add(chatRoom);
      _chatRooms.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
      notifyListeners();
    }
  }

  // Save message to local storage
  Future<void> _saveMessage(Message message) async {
    if (_messagesBox != null) {
      await _messagesBox!.put(message.id, message);
      
      // Update cache
      if (_messagesCache.containsKey(message.chatRoomId)) {
        _messagesCache[message.chatRoomId]!.add(message);
      }
    }
  }

  // Update message in local storage
  Future<void> _updateMessage(Message message) async {
    if (_messagesBox != null) {
      await _messagesBox!.put(message.id, message);
      
      // Update cache
      if (_messagesCache.containsKey(message.chatRoomId)) {
        final messages = _messagesCache[message.chatRoomId]!;
        final index = messages.indexWhere((m) => m.id == message.id);
        if (index >= 0) {
          messages[index] = message;
        }
      }
      
      notifyListeners();
    }
  }

  // Update chat room's last message
  Future<void> _updateChatRoomLastMessage(String chatRoomId, String lastMessage) async {
    if (_chatRoomsBox != null) {
      final chatRoom = _chatRoomsBox!.get(chatRoomId);
      if (chatRoom != null) {
        chatRoom.lastMessage = lastMessage;
        chatRoom.lastMessageTime = DateTime.now();
        await _chatRoomsBox!.put(chatRoomId, chatRoom);
        
        // Update local list
        final index = _chatRooms.indexWhere((room) => room.id == chatRoomId);
        if (index >= 0) {
          _chatRooms[index] = chatRoom;
          _chatRooms.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
        }
        
        notifyListeners();
      }
    }
  }

  // Sync data to Firebase when internet is available
  void _syncToFirebase(Message message) async {
    try {
      await _firebaseService.saveMessage(message);
    } catch (e) {
      debugPrint('Failed to sync message to Firebase: $e');
    }
  }

  // Search messages
  List<Message> searchMessages(String query) {
    final allMessages = _messagesBox?.values.toList() ?? [];
    return allMessages
        .where((message) =>
            message.content.toLowerCase().contains(query.toLowerCase()) ||
            message.senderName.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  // Delete a message
  Future<void> deleteMessage(String messageId) async {
    if (_messagesBox != null) {
      final message = _messagesBox!.get(messageId);
      if (message != null) {
        await _messagesBox!.delete(messageId);
        
        // Update cache
        if (_messagesCache.containsKey(message.chatRoomId)) {
          _messagesCache[message.chatRoomId]!.removeWhere((m) => m.id == messageId);
        }
        
        notifyListeners();
      }
    }
  }

  // Delete a chat room
  Future<void> deleteChatRoom(String chatRoomId) async {
    if (_chatRoomsBox != null) {
      await _chatRoomsBox!.delete(chatRoomId);
      _chatRooms.removeWhere((room) => room.id == chatRoomId);
      
      // Delete all messages in this chat room
      if (_messagesBox != null) {
        final messagesToDelete = _messagesBox!.values
            .where((message) => message.chatRoomId == chatRoomId)
            .toList();
        
        for (final message in messagesToDelete) {
          await _messagesBox!.delete(message.id);
        }
      }
      
      // Clear cache
      _messagesCache.remove(chatRoomId);
      
      notifyListeners();
    }
  }

  // Clear all chat data
  Future<void> clearAllData() async {
    await _chatRoomsBox?.clear();
    await _messagesBox?.clear();
    _chatRooms.clear();
    _messagesCache.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _chatRoomsBox?.close();
    _messagesBox?.close();
    super.dispose();
  }
}