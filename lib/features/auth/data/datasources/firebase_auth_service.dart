import 'package:firebase_auth/firebase_auth.dart';

class FirebaseAuthService {
  final _auth = FirebaseAuth.instance;

  Future<User?> signIn(String email, String password) async {
    final result = await _auth.signInWithEmailAndPassword(email: email, password: password);
    return result.user;
  }

  Future<void> signOut() async => _auth.signOut();
}