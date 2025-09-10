import 'package:hive/hive.dart';

// part 'user.g.dart';

@HiveType(typeId: 0)
class User extends HiveObject {
  @HiveField(0)
  String id;
  
  @HiveField(1)
  String name;
  
  @HiveField(2)
  String email;
  
  @HiveField(3)
  String? profilePicture;
  
  @HiveField(4)
  bool isOnline;
  
  @HiveField(5)
  DateTime lastSeen;
  
  @HiveField(6)
  String? bluetoothAddress;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.profilePicture,
    this.isOnline = false,
    required this.lastSeen,
    this.bluetoothAddress,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'profilePicture': profilePicture,
    'isOnline': isOnline,
    'lastSeen': lastSeen.toIso8601String(),
    'bluetoothAddress': bluetoothAddress,
  };

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'],
    name: json['name'],
    email: json['email'],
    profilePicture: json['profilePicture'],
    isOnline: json['isOnline'] ?? false,
    lastSeen: DateTime.parse(json['lastSeen']),
    bluetoothAddress: json['bluetoothAddress'],
  );
}