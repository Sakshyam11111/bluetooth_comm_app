// models/call_record.dart
import 'package:hive/hive.dart';

part '../pages/call_record.g.dart';

@HiveType(typeId: 3)
class CallRecord extends HiveObject {
  @HiveField(0)
  String id;
  
  @HiveField(1)
  String participantName;
  
  @HiveField(2)
  int callType; // CallType enum as int (0 = voice, 1 = video)
  
  @HiveField(3)
  DateTime timestamp;
  
  @HiveField(4)
  int duration; // Duration in seconds
  
  @HiveField(5)
  bool isIncoming;
  
  @HiveField(6)
  bool wasAnswered;

  CallRecord({
    required this.id,
    required this.participantName,
    required this.callType,
    required this.timestamp,
    required this.duration,
    required this.isIncoming,
    required this.wasAnswered,
  });

  // Convert duration to readable format
  String get formattedDuration {
    final hours = duration ~/ 3600;
    final minutes = (duration % 3600) ~/ 60;
    final seconds = duration % 60;
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  // Get call status text
  String get statusText {
    if (!wasAnswered) {
      return isIncoming ? 'Missed' : 'Declined';
    }
    return duration > 0 ? formattedDuration : 'Connected';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'participantName': participantName,
    'callType': callType,
    'timestamp': timestamp.toIso8601String(),
    'duration': duration,
    'isIncoming': isIncoming,
    'wasAnswered': wasAnswered,
  };

  factory CallRecord.fromJson(Map<String, dynamic> json) => CallRecord(
    id: json['id'],
    participantName: json['participantName'],
    callType: json['callType'],
    timestamp: DateTime.parse(json['timestamp']),
    duration: json['duration'],
    isIncoming: json['isIncoming'],
    wasAnswered: json['wasAnswered'],
  );
}