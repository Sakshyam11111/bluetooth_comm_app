import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../../models/user.dart';
import 'firebase_service.dart';

class AuthService extends ChangeNotifier {
  static const String USER_BOX = 'current_user';
  static const String AUTH_BOX = 'auth_data';
  
  final FirebaseService _firebaseService;
  Box<User>? _userBox;
  Box<String>? _authBox;
  
  User? _currentUser;
  bool _isAuthenticated = false;
  bool _isLoading = false;

  // Getters
  User? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;

  AuthService(this._firebaseService) {
    _initializeBoxes();
  }

  Future<void> _initializeBoxes() async {
    try {
      _userBox = await Hive.openBox<User>(USER_BOX);
      _authBox = await Hive.openBox<String>(AUTH_BOX);
      await _loadSavedUser();
    } catch (e) {
      debugPrint('Error initializing auth boxes: $e');
    }
  }

  Future<void> _loadSavedUser() async {
    try {
      if (_userBox != null && _userBox!.isNotEmpty) {
        _currentUser = _userBox!.values.first;
        _isAuthenticated = true;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading saved user: $e');
    }
  }

  // Sign in with email and password
  Future<AuthResult> signInWithEmailPassword(String email, String password) async {
    _setLoading(true);
    
    try {
      // Try to sign in with Firebase first
      final firebaseUser = await _firebaseService.signInWithEmailPassword(email, password);
      
      if (firebaseUser != null) {
        await _setCurrentUser(firebaseUser);
        _setLoading(false);
        return AuthResult.success('Sign in successful');
      } else {
        _setLoading(false);
        return AuthResult.failure('Invalid credentials');
      }
    } catch (e) {
      _setLoading(false);
      return AuthResult.failure(e.toString());
    }
  }

  // Register with email, password, and name
  Future<AuthResult> registerWithEmailPassword(
    String email, 
    String password, 
    String name
  ) async {
    _setLoading(true);
    
    try {
      // Validate input
      final validationResult = _validateRegistrationInput(email, password, name);
      if (!validationResult.isSuccess) {
        _setLoading(false);
        return validationResult;
      }

      // Register with Firebase
      final firebaseUser = await _firebaseService.registerWithEmailPassword(
        email, 
        password, 
        name
      );
      
      if (firebaseUser != null) {
        await _setCurrentUser(firebaseUser);
        _setLoading(false);
        return AuthResult.success('Registration successful');
      } else {
        _setLoading(false);
        return AuthResult.failure('Registration failed');
      }
    } catch (e) {
      _setLoading(false);
      return AuthResult.failure(e.toString());
    }
  }

  // Sign in as guest (offline mode)
  Future<AuthResult> signInAsGuest(String name) async {
    _setLoading(true);
    
    try {
      if (name.trim().isEmpty) {
        _setLoading(false);
        return AuthResult.failure('Name cannot be empty');
      }

      // Create a guest user
      final guestUser = User(
        id: 'guest_${DateTime.now().millisecondsSinceEpoch}',
        name: name.trim(),
        email: 'guest@localhost',
        lastSeen: DateTime.now(),
        isOnline: true,
      );

      await _setCurrentUser(guestUser);
      _setLoading(false);
      return AuthResult.success('Signed in as guest');
    } catch (e) {
      _setLoading(false);
      return AuthResult.failure(e.toString());
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // Sign out from Firebase if authenticated online
      if (_firebaseService.currentFirebaseUser != null) {
        await _firebaseService.signOut();
      }
      
      // Clear local data
      await _clearCurrentUser();
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }

  // Update user profile
  Future<AuthResult> updateUserProfile({
    String? name,
    String? profilePicture,
  }) async {
    if (_currentUser == null) {
      return AuthResult.failure('No user signed in');
    }

    try {
      final updatedUser = User(
        id: _currentUser!.id,
        name: name ?? _currentUser!.name,
        email: _currentUser!.email,
        profilePicture: profilePicture ?? _currentUser!.profilePicture,
        isOnline: _currentUser!.isOnline,
        lastSeen: _currentUser!.lastSeen,
        bluetoothAddress: _currentUser!.bluetoothAddress,
      );

      await _setCurrentUser(updatedUser);
      return AuthResult.success('Profile updated successfully');
    } catch (e) {
      return AuthResult.failure(e.toString());
    }
  }

  // Update Bluetooth address
  Future<void> updateBluetoothAddress(String bluetoothAddress) async {
    if (_currentUser == null) return;

    try {
      final updatedUser = User(
        id: _currentUser!.id,
        name: _currentUser!.name,
        email: _currentUser!.email,
        profilePicture: _currentUser!.profilePicture,
        isOnline: _currentUser!.isOnline,
        lastSeen: _currentUser!.lastSeen,
        bluetoothAddress: bluetoothAddress,
      );

      await _setCurrentUser(updatedUser);
      
      // Update in Firebase if online
      if (_firebaseService.hasInternetConnection) {
        await _firebaseService.updateUserBluetoothAddress(_currentUser!.id, bluetoothAddress);
      }
    } catch (e) {
      debugPrint('Error updating Bluetooth address: $e');
    }
  }

  // Set online status
  Future<void> setOnlineStatus(bool isOnline) async {
    if (_currentUser == null) return;

    try {
      final updatedUser = User(
        id: _currentUser!.id,
        name: _currentUser!.name,
        email: _currentUser!.email,
        profilePicture: _currentUser!.profilePicture,
        isOnline: isOnline,
        lastSeen: DateTime.now(),
        bluetoothAddress: _currentUser!.bluetoothAddress,
      );

      await _setCurrentUser(updatedUser);
      
      // Update in Firebase if online
      if (_firebaseService.hasInternetConnection) {
        await _firebaseService.updateUserOnlineStatus(_currentUser!.id, isOnline);
      }
    } catch (e) {
      debugPrint('Error setting online status: $e');
    }
  }

  // Private helper methods
  Future<void> _setCurrentUser(User user) async {
    _currentUser = user;
    _isAuthenticated = true;
    
    // Save to local storage
    if (_userBox != null) {
      await _userBox!.clear();
      await _userBox!.add(user);
    }
    
    notifyListeners();
  }

  Future<void> _clearCurrentUser() async {
    _currentUser = null;
    _isAuthenticated = false;
    
    // Clear local storage
    if (_userBox != null) {
      await _userBox!.clear();
    }
    if (_authBox != null) {
      await _authBox!.clear();
    }
    
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  AuthResult _validateRegistrationInput(String email, String password, String name) {
    // Validate name
    if (name.trim().isEmpty) {
      return AuthResult.failure('Name cannot be empty');
    }
    if (name.trim().length < 2) {
      return AuthResult.failure('Name must be at least 2 characters long');
    }

    // Validate email
    if (email.trim().isEmpty) {
      return AuthResult.failure('Email cannot be empty');
    }
    if (!_isValidEmail(email)) {
      return AuthResult.failure('Please enter a valid email address');
    }

    // Validate password
    if (password.isEmpty) {
      return AuthResult.failure('Password cannot be empty');
    }
    if (password.length < 6) {
      return AuthResult.failure('Password must be at least 6 characters long');
    }

    return AuthResult.success('Validation passed');
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email);
  }

  // Check if user is guest
  bool get isGuestUser => _currentUser?.email == 'guest@localhost';

  @override
  void dispose() {
    _userBox?.close();
    _authBox?.close();
    super.dispose();
  }
}

// Auth result class
class AuthResult {
  final bool isSuccess;
  final String message;

  AuthResult.success(this.message) : isSuccess = true;
  AuthResult.failure(this.message) : isSuccess = false;
}