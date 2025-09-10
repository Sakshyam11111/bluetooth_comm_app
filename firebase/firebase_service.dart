import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../models/user.dart' as app_user;
import '../models/message.dart';
import '../models/chat_room.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Collections
  static const String USERS_COLLECTION = 'users';
  static const String CHAT_ROOMS_COLLECTION = 'chatRooms';
  static const String MESSAGES_COLLECTION = 'messages';

  // Authentication Methods
  Future<app_user.User?> signInWithEmailPassword(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (credential.user != null) {
        return await _getUserData(credential.user!.uid);
      }
    } catch (e) {
      debugPrint('Error signing in: $e');
      throw e;
    }
    return null;
  }

  Future<app_user.User?> registerWithEmailPassword(
    String email, 
    String password, 
    String name
  ) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (credential.user != null) {
        final user = app_user.User(
          id: credential.user!.uid,
          name: name,
          email: email,
          lastSeen: DateTime.now(),
        );
        
        await _saveUserData(user);
        return user;
      }
    } catch (e) {
      debugPrint('Error registering: $e');
      throw e;
    }
    return null;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  firebase_auth.User? get currentFirebaseUser => _auth.currentUser;

  // User Data Methods
  Future<void> _saveUserData(app_user.User user) async {
    await _firestore
        .collection(USERS_COLLECTION)
        .doc(user.id)
        .set(user.toJson());
  }

  Future<app_user.User?> _getUserData(String userId) async {
    try {
      final doc = await _firestore
          .collection(USERS_COLLECTION)
          .doc(userId)
          .get();
      
      if (doc.exists) {
        return app_user.User.fromJson(doc.data()!);
      }
    } catch (e) {
      debugPrint('Error getting user data: $e');
    }
    return null;
  }

  Future<void> updateUserOnlineStatus(String userId, bool isOnline) async {
    try {
      await _firestore
          .collection(USERS_COLLECTION)
          .doc(userId)
          .update({
        'isOnline': isOnline,
        'lastSeen': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error updating online status: $e');
    }
  }

  Future<void> updateUserBluetoothAddress(String userId, String bluetoothAddress) async {
    try {
      await _firestore
          .collection(USERS_COLLECTION)
          .doc(userId)
          .update({
        'bluetoothAddress': bluetoothAddress,
      });
    } catch (e) {
      debugPrint('Error updating Bluetooth address: $e');
    }
  }

  // Chat Room Methods
  Future<void> saveChatRoom(ChatRoom chatRoom) async {
    try {
      await _firestore
          .collection(CHAT_ROOMS_COLLECTION)
          .doc(chatRoom.id)
          .set(chatRoom.toJson());
    } catch (e) {
      debugPrint('Error saving chat room: $e');
    }
  }

  Future<List<ChatRoom>> getUserChatRooms(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(CHAT_ROOMS_COLLECTION)
          .where('participantIds', arrayContains: userId)
          .orderBy('lastMessageTime', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => ChatRoom.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error getting user chat rooms: $e');
      return [];
    }
  }

  Stream<List<ChatRoom>> getChatRoomsStream(String userId) {
    return _firestore
        .collection(CHAT_ROOMS_COLLECTION)
        .where('participantIds', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatRoom.fromJson(doc.data()))
            .toList());
  }

  // Message Methods
  Future<void> saveMessage(Message message) async {
    try {
      // Save message
      await _firestore
          .collection(MESSAGES_COLLECTION)
          .doc(message.id)
          .set(message.toJson());

      // Update chat room's last message
      await _firestore
          .collection(CHAT_ROOMS_COLLECTION)
          .doc(message.chatRoomId)
          .update({
        'lastMessage': message.content,
        'lastMessageTime': message.timestamp.toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error saving message: $e');
    }
  }

  Future<List<Message>> getChatRoomMessages(String chatRoomId, {int limit = 50}) async {
    try {
      final querySnapshot = await _firestore
          .collection(MESSAGES_COLLECTION)
          .where('chatRoomId', isEqualTo: chatRoomId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => Message.fromJson(doc.data()))
          .toList()
          .reversed
          .toList();
    } catch (e) {
      debugPrint('Error getting chat room messages: $e');
      return [];
    }
  }

  Stream<List<Message>> getChatRoomMessagesStream(String chatRoomId) {
    return _firestore
        .collection(MESSAGES_COLLECTION)
        .where('chatRoomId', isEqualTo: chatRoomId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Message.fromJson(doc.data()))
            .toList());
  }

  Future<void> updateMessageStatus(String messageId, MessageStatus status) async {
    try {
      await _firestore
          .collection(MESSAGES_COLLECTION)
          .doc(messageId)
          .update({'status': status.index});
    } catch (e) {
      debugPrint('Error updating message status: $e');
    }
  }

  Future<void> deleteMessage(String messageId) async {
    try {
      await _firestore
          .collection(MESSAGES_COLLECTION)
          .doc(messageId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting message: $e');
    }
  }

  // File Upload Methods
  Future<String?> uploadFile(File file, String fileName, String folder) async {
    try {
      final ref = _storage.ref().child('$folder/$fileName');
      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading file: $e');
      return null;
    }
  }

  Future<String?> uploadImage(File image, String imageId) async {
    return await uploadFile(image, imageId, 'images');
  }

  Future<String?> uploadAudio(File audio, String audioId) async {
    return await uploadFile(audio, audioId, 'audio');
  }

  Future<String?> uploadVideo(File video, String videoId) async {
    return await uploadFile(video, videoId, 'videos');
  }

  Future<String?> uploadDocument(File document, String documentId) async {
    return await uploadFile(document, documentId, 'documents');
  }

  // Search Methods
  Future<List<app_user.User>> searchUsers(String query) async {
    try {
      final querySnapshot = await _firestore
          .collection(USERS_COLLECTION)
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThan: query + '\uf8ff')
          .limit(10)
          .get();

      return querySnapshot.docs
          .map((doc) => app_user.User.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error searching users: $e');
      return [];
    }
  }

  // Sync Methods - for offline-first approach
  Future<void> syncLocalDataToFirebase({
    required List<ChatRoom> chatRooms,
    required List<Message> messages,
  }) async {
    try {
      // Sync chat rooms
      for (final chatRoom in chatRooms) {
        await saveChatRoom(chatRoom);
      }

      // Sync messages
      for (final message in messages) {
        await saveMessage(message);
      }
    } catch (e) {
      debugPrint('Error syncing local data to Firebase: $e');
    }
  }

  Future<Map<String, dynamic>> getFirebaseDataForSync(String userId) async {
    try {
      final chatRooms = await getUserChatRooms(userId);
      final messages = <Message>[];

      // Get messages for all chat rooms
      for (final chatRoom in chatRooms) {
        final roomMessages = await getChatRoomMessages(chatRoom.id);
        messages.addAll(roomMessages);
      }

      return {
        'chatRooms': chatRooms,
        'messages': messages,
      };
    } catch (e) {
      debugPrint('Error getting Firebase data for sync: $e');
      return {
        'chatRooms': <ChatRoom>[],
        'messages': <Message>[],
      };
    }
  }

  // Utility Methods
  bool get hasInternetConnection {
    // This would be implemented with connectivity_plus package
    // For now, assume we have connection
    return true;
  }

  Future<void> enableOfflinePersistence() async {
    try {
      await _firestore.enablePersistence();
    } catch (e) {
      debugPrint('Error enabling offline persistence: $e');
    }
  }
}