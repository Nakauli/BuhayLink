import 'package:firebase_auth/firebase_auth.dart';
import '../auth_service.dart';

class AuthRepository {
  // 1. Initialize the correct class name "AuthService"
  final AuthService _service = AuthService();

  // 2. Login: Pass parameters with names (email: ..., password: ...)
  Future<User?> signIn(String email, String password) async {
    return await _service.signIn(email: email, password: password);
  }

  // 3. Register: Add this so your App can actually sign up!
  Future<User?> signUp(String email, String password, String username) async {
    return await _service.signUp(
      email: email, 
      password: password, 
      username: username
    );
  }

  // 4. Sign Out
  Future<void> signOut() async {
    await _service.signOut();
  }
}