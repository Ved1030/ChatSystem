import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../repositories/auth_repository.dart';
import '../repositories/user_repository.dart';
import '../services/notification_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepository = AuthRepository();
  final UserRepository _userRepository = UserRepository();

  UserModel? _user;
  bool _isLoading = true;
  String? _error;
  bool _isInitialized = false;
  bool _isLoadingUser = false;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  String? get error => _error;

  AuthProvider() {
    _init();
    _authRepository.authState.listen(_onAuthStateChanged);
  }

  void _init() {
    final firebaseUser = _authRepository.currentUser;
    if (firebaseUser != null) {
      _isLoadingUser = true;
      _loadUser(firebaseUser);
    } else {
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> _loadUser(User firebaseUser) async {
    if (_isInitialized) return;
    try {
      final userModel = await _userRepository.getUser(firebaseUser.uid);
      if (userModel == null) {
        final fcmToken = NotificationService().currentToken;
        _user = UserModel(
          uid: firebaseUser.uid,
          name: firebaseUser.displayName ?? '',
          username: (firebaseUser.email ?? '').split('@').first,
          email: firebaseUser.email ?? '',
          photoUrl: firebaseUser.photoURL,
          isOnline: true,
          fcmToken: fcmToken,
        );
        await _userRepository.createUser(_user!);
      } else {
        _user = userModel;
        await _userRepository.updateOnlineStatus(firebaseUser.uid, true);
        _updateFcmToken(firebaseUser.uid);
      }
    } catch (e) {
      _user = null;
      _error = e.toString();
    }
    _isLoading = false;
    _isLoadingUser = false;
    _isInitialized = true;
    _setupFcmTokenListener();
    notifyListeners();
  }

  void _setupFcmTokenListener() {
    NotificationService().onTokenChanged = (String newToken) {
      if (_user != null) {
        _userRepository.updateUser(_user!.uid, {'fcmToken': newToken});
      }
    };
  }

  Future<void> _updateFcmToken(String uid) async {
    final token = NotificationService().currentToken;
    if (token != null) {
      await _userRepository.updateUser(uid, {'fcmToken': token});
    }
  }

  void _onAuthStateChanged(User? firebaseUser) async {
    if (_isInitialized) return;
    if (firebaseUser != null && _user == null && !_isLoadingUser) {
      _isLoadingUser = true;
      await _loadUser(firebaseUser);
    } else if (firebaseUser == null) {
      _user = null;
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> register({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final usernameTaken = await _userRepository.usernameExists(username);
      if (usernameTaken) {
        _error = 'Username is already taken';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final credential = await _authRepository.register(
        email: email,
        password: password,
      );

      final fcmToken = NotificationService().currentToken;
      _user = UserModel(
        uid: credential.user!.uid,
        name: name,
        username: username,
        email: email,
        createdAt: DateTime.now(),
        isOnline: true,
        fcmToken: fcmToken,
      );
      await _userRepository.createUser(_user!);
      _isLoading = false;
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      _error = e.message ?? 'Registration failed';
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> login({required String email, required String password}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final credential = await _authRepository.login(
        email: email,
        password: password,
      );

      _user = await _userRepository.getUser(credential.user!.uid);
      if (_user != null) {
        await _userRepository.updateOnlineStatus(_user!.uid, true);
        _updateFcmToken(_user!.uid);
      }
      _isLoading = false;
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      _error = e.message ?? 'Login failed';
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final credential = await _authRepository.signInWithGoogle();
      final firebaseUser = credential.user!;

      _user = await _userRepository.getUser(firebaseUser.uid);

      if (_user == null) {
        _user = UserModel(
          uid: firebaseUser.uid,
          name: firebaseUser.displayName ?? '',
          username: (firebaseUser.email ?? '').split('@').first,
          email: firebaseUser.email ?? '',
          photoUrl: firebaseUser.photoURL,
          isOnline: true,
        );
        await _userRepository.createUser(_user!);
      } else {
        await _userRepository.updateOnlineStatus(_user!.uid, true);
        _updateFcmToken(_user!.uid);
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    if (_user != null) {
      await _userRepository.updateOnlineStatus(_user!.uid, false);
    }
    await _authRepository.logout();
    _user = null;
    notifyListeners();
  }

  Future<void> updateProfile({
    String? name,
    String? username,
    String? photoUrl,
  }) async {
    if (_user == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (username != null) {
        final taken = await _userRepository.usernameExists(username);
        if (taken && username != _user!.username) {
          _error = 'Username is already taken';
          _isLoading = false;
          notifyListeners();
          return;
        }
        data['username'] = username;
      }
      if (photoUrl != null) data['photoUrl'] = photoUrl;

      if (data.isNotEmpty) {
        await _userRepository.updateUser(_user!.uid, data);
        _user = await _userRepository.getUser(_user!.uid);
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> updateOnlineStatus(bool isOnline) async {
    if (_user != null) {
      await _userRepository.updateOnlineStatus(_user!.uid, isOnline);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}
