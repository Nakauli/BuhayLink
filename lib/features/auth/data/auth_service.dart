import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Login (Email & Password)
  Future<User?> signIn({required String email, required String password}) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email, 
        password: password
      );
      return result.user;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // Register (Username, Email, Password)
  Future<User?> signUp({
    required String email, 
    required String password, 
    required String username
  }) async {
    try {
      // 1. Create Authentication
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );
      User? user = result.user;

      // 2. Save User Details to Database (Firestore)
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': email,
          'username': username,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      return user;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}