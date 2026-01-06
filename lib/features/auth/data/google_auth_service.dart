import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // <--- NEW IMPORT

class GoogleAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  // 1. Add Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign In Function
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // 1. Trigger the Google Authentication flow (Opens the popup)
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // If the user cancels the login, return null
      if (googleUser == null) return null;

      // 2. Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // 3. Create a new credential for Firebase
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Sign in to Firebase with the Google Credential
      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      // ---------------------------------------------------------
      // 5. NEW STEP: Check & Create Firestore Profile
      // ---------------------------------------------------------
      // If login was successful, make sure they have a database entry
      if (userCredential.user != null) {
        await _ensureFirestoreProfileExists(userCredential.user!);
      }

      return userCredential;
    } catch (e) {
      print("Error signing in with Google: $e");
      return null;
    }
  }

  // --- NEW HELPER METHOD ---
  // Checks if the user exists in the 'users' collection.
  // If not, it creates a default profile using their Google info.
  Future<void> _ensureFirestoreProfileExists(User user) async {
    try {
      final userDocRef = _firestore.collection('users').doc(user.uid);
      final docSnapshot = await userDocRef.get();

      // Only create if it doesn't exist yet (First time login)
      if (!docSnapshot.exists) {
        // Get name/photo from Google or use fallbacks
        String fullName = user.displayName ?? "User";
        String email = user.email ?? "";
        String photo = user.photoURL ?? "";

        // Create the document (Matches your AuthRepository structure)
        await userDocRef.set({
          'uid': user.uid,
          'email': email,
          'name': fullName,
          // Create a simple username from email (john.doe@gmail -> john.doe)
          'username': email.split('@')[0],
          'photoUrl': photo, // Use their Google Photo!
          'bio': "I'm new here!",
          'location': "Philippines",
          'createdAt': FieldValue.serverTimestamp(),

          // IMPORTANT: Initialize counters so the app doesn't crash on math
          'savedCount': 0,
          'appliedCount': 0,
          'hiredCompleted': 0,

          // Default role
          'role': 'user',
        });
      }
    } catch (e) {
      print("Error ensuring Firestore profile: $e");
      // We don't throw here to avoid blocking the login,
      // but the app might behave oddly if this fails.
    }
  }

  // Sign Out Function (Unchanged)
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
