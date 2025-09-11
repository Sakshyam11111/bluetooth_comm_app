import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../../services/bluetooth_service.dart';
import '../../models/call_record.dart';

enum CallType { voice, video }
enum CallStatus { connecting, connected, disconnected, failed, declined }

class CallService extends ChangeNotifier {
  static const String CALL_RECORDS_BOX = 'call_records';
  static const String AGORA_APP_ID = 'your_agora_app_id_here'; // Replace with your Agora App ID
  
  final BluetoothService _bluetoothService;
  final Uuid _uuid = const Uuid();
  
  RtcEngine? _engine;
  Box<CallRecord>? _callRecordsBox;
  
  bool _isInCall = false;
  bool _isMuted = false;
  bool _isVideoEnabled = true;
  bool _isSpeakerEnabled = false;
  
  String? _currentChannelName;
  String? _currentCallId;
  CallType? _currentCallType;
  CallStatus _callStatus = CallStatus.disconnected;
  
  List<CallRecord> _callHistory = [];
  Map<int, String> _remoteUsers = {};

  // Getters
  bool get isInCall => _isInCall;
  bool get isMuted => _isMuted;
  bool get isVideoEnabled => _isVideoEnabled;
  bool get isSpeakerEnabled => _isSpeakerEnabled;
  String? get currentChannelName => _currentChannelName;
  String? get currentCallId => _currentCallId;
  CallType? get currentCallType => _currentCallType;
  CallStatus get callStatus => _callStatus;
  List<CallRecord> get callHistory => _callHistory;
  Map<int, String> get remoteUsers => _remoteUsers;

  CallService(this._bluetoothService) {
    _initializeBoxes();
    _initializeAgora();
  }

  Future<void> _initializeBoxes() async {
    try {
      _callRecordsBox = await Hive.openBox<CallRecord>(CALL_RECORDS_BOX);
      _loadCallHistory();
    } catch (e) {
      debugPrint('Error initializing call records box: $e');
    }
  }

  void _loadCallHistory() {
    if (_callRecordsBox != null) {
      _callHistory = _callRecordsBox!.values.toList();
      _callHistory.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      notifyListeners();
    }
  }

  Future<void> _initializeAgora() async {
    try {
      // Create RTC engine
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(const RtcEngineContext(
        appId: AGORA_APP_ID,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));

      // Register event handlers
      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            _callStatus = CallStatus.connected;
            _isInCall = true;
            notifyListeners();
            debugPrint('Successfully joined channel: ${connection.channelId}');
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            debugPrint('Remote user joined: $remoteUid');
            _remoteUsers[remoteUid] = 'User $remoteUid';
            notifyListeners();
          },
          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
            debugPrint('Remote user left: $remoteUid');
            _remoteUsers.remove(remoteUid);
            notifyListeners();
          },
          onLeaveChannel: (RtcConnection connection, RtcStats stats) {
            _endCall();
            debugPrint('Left channel');
          },
          onConnectionStateChanged: (RtcConnection connection, ConnectionStateType state, ConnectionChangedReasonType reason) {
            debugPrint('Connection state changed: $state, reason: $reason');
            if (state == ConnectionStateType.connectionStateFailed) {
              _callStatus = CallStatus.failed;
              notifyListeners();
            }
          },
        ),
      );
    } catch (e) {
      debugPrint('Error initializing Agora: $e');
    }
  }

  // Start a voice call
  Future<bool> startVoiceCall(String targetDeviceId, String targetUserName) async {
    if (_isInCall) {
      debugPrint('Already in a call');
      return false;
    }

    try {
      final callId = _uuid.v4();
      final channelName = 'call_$callId';
      
      _currentCallId = callId;
      _currentChannelName = channelName;
      _currentCallType = CallType.voice;
      _callStatus = CallStatus.connecting;
      
      // Send call invitation via Bluetooth
      final callInvitation = {
        'type': 'call_invitation',
        'callId': callId,
        'channelName': channelName,
        'callType': 'voice',
        'callerName': 'Current User', // Replace with actual user name
      };
      
      // This would be sent via Bluetooth to the target device
      // await _bluetoothService.sendMessage(callInvitation);
      
      // Enable audio
      await _engine!.enableAudio();
      await _engine!.disableVideo();
      
      // Join channel with a placeholder token
      await _engine!.joinChannel(
        token: 'Your_Token_Here', // Replace with actual token or a placeholder
        channelId: channelName,
        uid: 0, // Let Agora assign UID
        options: const ChannelMediaOptions(),
      );
      
      // Record call attempt
      await _recordCall(
        callId: callId,
        targetUserName: targetUserName,
        callType: CallType.voice,
        isIncoming: false,
      );
      
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error starting voice call: $e');
      _callStatus = CallStatus.failed;
      notifyListeners();
      return false;
    }
  }

  // Start a video call
  Future<bool> startVideoCall(String targetDeviceId, String targetUserName) async {
    if (_isInCall) {
      debugPrint('Already in a video call');
      return false;
    }

    try {
      final callId = _uuid.v4();
      final channelName = 'call_$callId';
      
      _currentCallId = callId;
      _currentChannelName = channelName;
      _currentCallType = CallType.video;
      _callStatus = CallStatus.connecting;
      
      // Send call invitation via Bluetooth
      final callInvitation = {
        'type': 'call_invitation',
        'callId': callId,
        'channelName': channelName,
        'callType': 'video',
        'callerName': 'Current User', // Replace with actual user name
      };
      
      // This would be sent via Bluetooth to the target device
      // await _bluetoothService.sendMessage(callInvitation);
      
      // Enable audio and video
      await _engine!.enableAudio();
      await _engine!.enableVideo();
      
      // Join channel with a placeholder token
      await _engine!.joinChannel(
        token: 'Your_Token_Here', // Replace with actual token or a placeholder
        channelId: channelName,
        uid: 0, // Let Agora assign UID
        options: const ChannelMediaOptions(),
      );
      
      // Record call attempt
      await _recordCall(
        callId: callId,
        targetUserName: targetUserName,
        callType: CallType.video,
        isIncoming: false,
      );
      
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error starting video call: $e');
      _callStatus = CallStatus.failed;
      notifyListeners();
      return false;
    }
  }

  // Answer an incoming call
  Future<bool> answerCall(String channelName, CallType callType) async {
    try {
      _currentChannelName = channelName;
      _currentCallType = callType;
      _callStatus = CallStatus.connecting;
      
      if (callType == CallType.voice) {
        await _engine!.enableAudio();
        await _engine!.disableVideo();
      } else {
        await _engine!.enableAudio();
        await _engine!.enableVideo();
      }
      
      // Join channel with a placeholder token
      await _engine!.joinChannel(
        token: 'Your_Token_Here', // Replace with actual token or a placeholder
        channelId: channelName,
        uid: 0,
        options: const ChannelMediaOptions(),
      );
      
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error answering call: $e');
      _callStatus = CallStatus.failed;
      notifyListeners();
      return false;
    }
  }

  // Decline an incoming call
  Future<void> declineCall() async {
    _callStatus = CallStatus.declined;
    notifyListeners();
    
    // Send decline message via Bluetooth
    final declineMessage = {
      'type': 'call_declined',
      'callId': _currentCallId,
    };
    // await _bluetoothService.sendMessage(declineMessage);
  }

  // End current call
  Future<void> endCall() async {
    if (!_isInCall) return;
    
    try {
      await _engine!.leaveChannel();
      _endCall();
    } catch (e) {
      debugPrint('Error ending call: $e');
    }
  }

  void _endCall() {
    _isInCall = false;
    _callStatus = CallStatus.disconnected;
    _currentChannelName = null;
    _currentCallId = null;
    _currentCallType = null;
    _remoteUsers.clear();
    notifyListeners();
  }

  // Toggle mute
  Future<void> toggleMute() async {
    if (_engine != null) {
      _isMuted = !_isMuted;
      await _engine!.muteLocalAudioStream(_isMuted);
      notifyListeners();
    }
  }

  // Toggle video
  Future<void> toggleVideo() async {
    if (_engine != null && _currentCallType == CallType.video) {
      _isVideoEnabled = !_isVideoEnabled;
      await _engine!.muteLocalVideoStream(!_isVideoEnabled);
      notifyListeners();
    }
  }

  // Toggle speaker
  Future<void> toggleSpeaker() async {
    if (_engine != null) {
      _isSpeakerEnabled = !_isSpeakerEnabled;
      await _engine!.setEnableSpeakerphone(_isSpeakerEnabled);
      notifyListeners();
    }
  }

  // Switch camera (front/back)
  Future<void> switchCamera() async {
    if (_engine != null && _currentCallType == CallType.video) {
      await _engine!.switchCamera();
    }
  }

  // Record call information
  Future<void> _recordCall({
    required String callId,
    required String targetUserName,
    required CallType callType,
    required bool isIncoming,
  }) async {
    final callRecord = CallRecord(
      id: callId,
      participantName: targetUserName,
      callType: callType.index,
      timestamp: DateTime.now(),
      duration: 0, // Will be updated when call ends
      isIncoming: isIncoming,
      wasAnswered: true,
    );

    if (_callRecordsBox != null) {
      await _callRecordsBox!.put(callId, callRecord);
      _callHistory.insert(0, callRecord);
      notifyListeners();
    }
  }

  // Update call duration when call ends
  Future<void> _updateCallDuration(String callId, int durationSeconds) async {
    if (_callRecordsBox != null) {
      final callRecord = _callRecordsBox!.get(callId);
      if (callRecord != null) {
        callRecord.duration = durationSeconds;
        await _callRecordsBox!.put(callId, callRecord);
        
        final index = _callHistory.indexWhere((record) => record.id == callId);
        if (index >= 0) {
          _callHistory[index] = callRecord;
          notifyListeners();
        }
      }
    }
  }

  // Clear call history
  Future<void> clearCallHistory() async {
    await _callRecordsBox?.clear();
    _callHistory.clear();
    notifyListeners();
  }

  // Delete specific call record
  Future<void> deleteCallRecord(String callId) async {
    await _callRecordsBox?.delete(callId);
    _callHistory.removeWhere((record) => record.id == callId);
    notifyListeners();
  }

  @override
  void dispose() {
    _engine?.release();
    _callRecordsBox?.close();
    super.dispose();
  }
}