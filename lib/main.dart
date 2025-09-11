// main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

// Services
import 'services/bluetooth_service.dart';
import 'firebase/firebase_service.dart';
import 'firebase/auth_service.dart';
import 'services/chat_service.dart';
import 'services/call_service.dart';

// Screens
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'pages/home_screen.dart';

// Theme
import 'theme/app_theme.dart';

// Models
import 'models/user.dart';
import 'models/message.dart';
import 'models/chat_room.dart';
import 'models/call_record.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for local storage
  await Hive.initFlutter();
  
  // Register Hive adapters
  Hive.registerAdapter(UserAdapter() as TypeAdapter);
  Hive.registerAdapter(MessageAdapter() as TypeAdapter);
  Hive.registerAdapter(ChatRoomAdapter() as TypeAdapter);
  Hive.registerAdapter(CallRecordAdapter() as TypeAdapter);

  // Initialize Firebase
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyA4M54igk8VeQQf4RSns1R8op9Jxu_mAiU",
      authDomain: "bluetoothcommapp.firebaseapp.com",
      projectId: "bluetoothcommapp",
      storageBucket: "bluetoothcommapp.firebasestorage.app",
      messagingSenderId: "995276352471",
      appId: "1:995276352471:web:0991869708722a6f467992",
      measurementId: "G-MES4J74L3X",
    ),
  );

  // Request necessary permissions
  await _requestPermissions();

  runApp(const BluetoothCommApp());
}

class ChatRoomAdapter {
}

class CallRecordAdapter {
}

class MessageAdapter {
}

class UserAdapter {
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
        Provider<FirebaseService>(
          create: (_) => FirebaseService(),
        ),
        ChangeNotifierProvider<BluetoothService>(
          create: (_) => BluetoothService(),
        ),
        ChangeNotifierProxyProvider<FirebaseService, AuthService>(
          create: (context) => AuthService(
            Provider.of<FirebaseService>(context, listen: false),
          ),
          update: (context, firebaseService, previous) =>
              previous ?? AuthService(firebaseService),
        ),
        ChangeNotifierProxyProvider2<BluetoothService, FirebaseService, ChatService>(
          create: (context) => ChatService(
            Provider.of<BluetoothService>(context, listen: false),
            Provider.of<FirebaseService>(context, listen: false),
          ),
          update: (context, bluetoothService, firebaseService, previous) =>
              previous ?? ChatService(bluetoothService, firebaseService),
        ),
        ChangeNotifierProxyProvider<BluetoothService, CallService>(
          create: (context) => CallService(
            Provider.of<BluetoothService>(context, listen: false),
          ),
          update: (context, bluetoothService, previous) =>
              previous ?? CallService(bluetoothService),
        ),
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