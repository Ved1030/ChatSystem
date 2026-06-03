import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';

class AuthRepository {
  final AuthService _authService = AuthService();

  User? get currentUser => _authService.currentUser;

  Stream<User?> get authState => _authService.authState;

  Future<UserCredential> register({
    required String email,
    required String password,
  }) =>
      _authService.register(email: email, password: password);

  Future<UserCredential> login({
    required String email,
    required String password,
  }) =>
      _authService.login(email: email, password: password);

  Future<UserCredential> signInWithGoogle() =>
      _authService.signInWithGoogle();

  Future<void> logout() => _authService.logout();
}
