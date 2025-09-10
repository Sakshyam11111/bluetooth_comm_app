import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import 'services/bluetooth_service.dart';
import 'services/firebase_service.dart';
import 'services/auth_service.dart';
import 'services/chat_service.dart';
import 'services/call_service.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';
import 'models/user.dart';
import 'models/message.dart';
import 'models/chat_room.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for local storage
  await Hive.initFlutter();
  Hive.registerAdapter(UserAdapter());
  Hive.registerAdapter(MessageAdapter());
  Hive.registerAdapter(ChatRoomAdapter());

  // Initialize Firebase
  await Firebase.initializeApp();

  // Request necessary permissions
  await _requestPermissions();

  Firebase.initializeApp(
      options: FirebaseOptions(
          apiKey: "AIzaSyA4M54igk8VeQQf4RSns1R8op9Jxu_mAiU",
          authDomain: "bluetoothcommapp.firebaseapp.com",
          projectId: "bluetoothcommapp",
          storageBucket: "bluetoothcommapp.firebasestorage.app",
          messagingSenderId: "995276352471",
          appId: "1:995276352471:web:0991869708722a6f467992",
          measurementId: "G-MES4J74L3X"));

  runApp(const BluetoothCommApp());
}

Future<void> _requestPermissions() async {
  await [
    Permission.bluetooth,
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    Permission.bluetoothAdvertise,
    Permission.locationWhenInUse,
    Permission.microphone,
    Permission.camera,
    Permission.storage,
    Permission.notification,
  ].request();
}

class BluetoothCommApp extends StatelessWidget {
  const BluetoothCommApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BluetoothService()),
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ChatService()),
        ChangeNotifierProvider(create: (_) => CallService()),
        Provider(create: (_) => FirebaseService()),
      ],
      child: MaterialApp(
        title: 'Bluetooth Comm',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        debugShowCheckedModeBanner: false,
        home: const SplashScreen(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const HomeScreen(),
        },
      ),
    );
  }
}
