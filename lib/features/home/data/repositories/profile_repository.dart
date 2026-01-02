import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class ProfileRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String? getCurrentUserId() => _auth.currentUser?.uid;

  // 1. UPLOAD IMAGE TO FIREBASE STORAGE
  Future<String> uploadProfileImage(File imageFile) async {
    String? uid = getCurrentUserId();
    if (uid == null) throw Exception("No user logged in");

    // Create a reference: users/USER_ID/profile.jpg
    Reference ref = _storage.ref().child('users/$uid/profile.jpg');

    // Upload the file
    UploadTask uploadTask = ref.putFile(imageFile);
    TaskSnapshot snapshot = await uploadTask;

    // Get the public URL to save in Firestore
    return await snapshot.ref.getDownloadURL();
  }

  // 2. GET AUTOMATIC LOCATION (GPS)
  Future<String> getCurrentLocation() async {
    // Check permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception("Location permission denied");
      }
    }

    // Get current position
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    // Convert coordinates to address (Reverse Geocoding)
    List<Placemark> placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );

    if (placemarks.isNotEmpty) {
      Placemark place = placemarks[0];
      return "${place.locality}, ${place.country}"; // e.g., "Davao, Philippines"
    }
    return "Unknown Location";
  }

  // 3. UPDATE PROFILE DATA
  // Update this specific function inside your ProfileRepository class
  Future<void> updateProfile({
    String? name, // <-- ADD THIS
    String? about,
    String? location,
    List<String>? skills,
    String? photoUrl,
  }) async {
    String? uid = getCurrentUserId();
    if (uid == null) throw Exception("No user logged in");

    Map<String, dynamic> dataToUpdate = {};
    if (name != null) dataToUpdate['name'] = name; // <-- ADD THIS
    if (about != null) dataToUpdate['about'] = about;
    if (location != null) dataToUpdate['location'] = location;
    if (skills != null) dataToUpdate['skills'] = skills;
    if (photoUrl != null) dataToUpdate['photoUrl'] = photoUrl;

    if (dataToUpdate.isNotEmpty) {
      await _firestore.collection('users').doc(uid).update(dataToUpdate);

      // OPTIONAL: Also update the Auth profile name for consistency
      if (name != null) {
        await _auth.currentUser?.updateDisplayName(name);
      }
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
