import '../datasources/firebase_auth_service.dart'; //

class AuthRepository {
  final _service = FirebaseAuthService();

  Future<void> signIn(String email, String pass) => _service.signIn(email, pass);
  Future<void> signOut() => _service.signOut();
}