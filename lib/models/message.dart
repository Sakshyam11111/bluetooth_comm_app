// models/message.dart
import 'package:hive/hive.dart';

// part 'message.g.dart';

enum MessageType { text, image, file, audio, video }
enum MessageStatus { sending, sent, delivered, read, failed }

@HiveType(typeId: 1)
class Message extends HiveObject {
  @HiveField(0)
  String id;
  
  @HiveField(1)
  String senderId;
  
  @HiveField(2)
  String senderName;
  
  @HiveField(3)
  String chatRoomId;
  
  @HiveField(4)
  String content;
  
  @HiveField(5)
  int messageType; // MessageType enum as int
  
  @HiveField(6)
  DateTime timestamp;
  
  @HiveField(7)
  int status; // MessageStatus enum as int
  
  @HiveField(8)
  String? filePath;
  
  @HiveField(9)
  bool isEncrypted;

  Message({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.chatRoomId,
    required this.content,
    this.messageType = 0, // MessageType.text
    required this.timestamp,
    this.status = 0, // MessageStatus.sending
    this.filePath,
    this.isEncrypted = false,
  });

  MessageType get type => MessageType.values[messageType];
  MessageStatus get messageStatus => MessageStatus.values[status];

  Map<String, dynamic> toJson() => {
    'id': id,
    'senderId': senderId,
    'senderName': senderName,
    'chatRoomId': chatRoomId,
    'content': content,
    'messageType': messageType,
    'timestamp': timestamp.toIso8601String(),
    'status': status,
    'filePath': filePath,
    'isEncrypted': isEncrypted,
  };

  factory Message.fromJson(Map<String, dynamic> json) => Message(
    id: json['id'],
    senderId: json['senderId'],
    senderName: json['senderName'],
    chatRoomId: json['chatRoomId'],
    content: json['content'],
    messageType: json['messageType'],
    timestamp: DateTime.parse(json['timestamp']),
    status: json['status'],
    filePath: json['filePath'],
    isEncrypted: json['isEncrypted'] ?? false,
  );
}