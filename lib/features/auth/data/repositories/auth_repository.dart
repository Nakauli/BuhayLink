import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth_service.dart';

class AuthRepository {
  final AuthService _service = AuthService();
  // 1. Firestore instance to save the profile
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // 2. Added FirebaseAuth instance (Needed for Password Reset)
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ---------------------------------------------------------
  // EXISTING LOGIN (Unchanged)
  // ---------------------------------------------------------
  Future<User?> signIn(String email, String password) async {
    return await _service.signIn(email: email, password: password);
  }

  // ---------------------------------------------------------
  // EXISTING REGISTER (Unchanged)
  // ---------------------------------------------------------
  Future<User?> signUp(String email, String password, String username) async {
    // A. Create the Account via Service
    User? user = await _service.signUp(
      email: email,
      password: password,
      username: username,
    );

    // B. If Account creation successful, create the Profile Foundation
    if (user != null) {
      await _createInitialProfile(user, username, email);
    }

    return user;
  }

  // ---------------------------------------------------------
  // EXISTING SIGN OUT (Unchanged)
  // ---------------------------------------------------------
  Future<void> signOut() async {
    await _service.signOut();
  }

  // ---------------------------------------------------------
  // NEW FUNCTION: FORGOT PASSWORD
  // ---------------------------------------------------------
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      // Handle specific Firebase errors (like user not found)
      throw e.message ?? "An error occurred while sending reset email.";
    } catch (e) {
      throw e.toString();
    }
  }

  // ---------------------------------------------------------
  // HELPER: Create Firestore Profile (Unchanged)
  // ---------------------------------------------------------
  Future<void> _createInitialProfile(
    User user,
    String rawUsername,
    String email,
  ) async {
    try {
      // 1. Capitalize the name (mannypacman -> Mannypacman)
      String finalName = "User";
      if (rawUsername.isNotEmpty) {
        finalName =
            '${rawUsername[0].toUpperCase()}${rawUsername.substring(1)}';
      } else {
        // Fallback to email if username is empty
        String nameFromEmail = email.split('@')[0];
        finalName =
            '${nameFromEmail[0].toUpperCase()}${nameFromEmail.substring(1)}';
      }

      // 2. Create the Document in 'users' collection
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': email,
        'name': finalName, // Saved as Capitalized
        'username': rawUsername, // Original username
        'photoUrl': "", // Ready for later
        'bio': "I'm new here!", // Default Bio
        'location': "Philippines", // Default Location
        'createdAt': FieldValue.serverTimestamp(),

        // Initialize Counters so stats don't crash
        'savedCount': 0,
        'appliedCount': 0,
        'hiredCompleted': 0,

        // Add roles if needed
        'role': 'user',
      });

      // 3. Also update the Auth Display Name for consistency
      await user.updateDisplayName(finalName);
    } catch (e) {
      print("Error creating initial profile: $e");
      // We don't throw here to avoid stopping the login flow,
      // but the profile might be missing.
    }
  }
}
