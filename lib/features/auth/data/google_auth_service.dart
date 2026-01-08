import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GoogleAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  // 1. Add Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign In Function
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // --- THE FIX IS HERE ---
      // Force the account picker to appear by signing out of the plugin first.
      // This clears the cached "last logged in" account.
      await _googleSignIn.signOut();
      // -----------------------

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
      // 5. Check & Create Firestore Profile (Kept as requested)
      // ---------------------------------------------------------
      if (userCredential.user != null) {
        await _ensureFirestoreProfileExists(userCredential.user!);
      }

      return userCredential;
    } catch (e) {
      print("Error signing in with Google: $e");
      return null;
    }
  }

  // --- HELPER METHOD (Kept existing) ---
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

        // Create the document
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

          // Initialize counters
          'savedCount': 0,
          'appliedCount': 0,
          'hiredCompleted': 0,

          // Default role
          'role': 'user',
        });
      }
    } catch (e) {
      print("Error ensuring Firestore profile: $e");
    }
  }

  // Sign Out Function (Unchanged)
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
