// models/chat_room.dart
import 'package:hive/hive.dart';
import 'user.dart';
import 'message.dart';

part 'chat_room.g.dart';

enum ChatRoomType { direct, group }

@HiveType(typeId: 2)
class ChatRoom extends HiveObject {
  @HiveField(0)
  String id;
  
  @HiveField(1)
  String name;
  
  @HiveField(2)
  int type; // ChatRoomType as int
  
  @HiveField(3)
  List<String> participantIds;
  
  @HiveField(4)
  String? lastMessage;
  
  @HiveField(5)
  DateTime lastMessageTime;
  
  @HiveField(6)
  String? adminId;
  
  @HiveField(7)
  String? groupPicture;
  
  @HiveField(8)
  bool isEncrypted;

  ChatRoom({
    required this.id,
    required this.name,
    this.type = 0, // ChatRoomType.direct
    required this.participantIds,
    this.lastMessage,
    required this.lastMessageTime,
    this.adminId,
    this.groupPicture,
    this.isEncrypted = false,
  });

  ChatRoomType get chatType => ChatRoomType.values[type];

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'participantIds': participantIds,
    'lastMessage': lastMessage,
    'lastMessageTime': lastMessageTime.toIso8601String(),
    'adminId': adminId,
    'groupPicture': groupPicture,
    'isEncrypted': isEncrypted,
  };

  factory ChatRoom.fromJson(Map<String, dynamic> json) => ChatRoom(
    id: json['id'],
    name: json['name'],
    type: json['type'],
    participantIds: List<String>.from(json['participantIds']),
    lastMessage: json['lastMessage'],
    lastMessageTime: DateTime.parse(json['lastMessageTime']),
    adminId: json['adminId'],
    groupPicture: json['groupPicture'],
    isEncrypted: json['isEncrypted'] ?? false,
  );
}

