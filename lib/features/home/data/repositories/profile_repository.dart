import 'dart:io';
import 'dart:convert'; // Needed for JSON decoding
import 'package:http/http.dart' as http; // Needed for Cloudinary upload
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class ProfileRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // Note: We removed FirebaseStorage because we are using Cloudinary now!

  String? getCurrentUserId() => _auth.currentUser?.uid;

  // 1. UPLOAD IMAGE TO CLOUDINARY (No Credit Card Required)
  Future<String> uploadProfileImage(File imageFile) async {
    // --- CONFIGURATION ---
    // TODO: Replace this with your actual Cloud Name from the Dashboard
    String cloudName = "drhbxeggn";

    // This is the name you typed in the settings earlier
    String uploadPreset = "buhaylink_preset";
    // ---------------------

    // Prepare the upload to Cloudinary
    final url = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
    );
    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    // Send the request
    final response = await request.send();

    // Handle the response
    if (response.statusCode == 200) {
      final responseData = await response.stream.toBytes();
      final responseString = String.fromCharCodes(responseData);
      final jsonMap = jsonDecode(responseString);

      // Return the public link (URL) to your new photo
      return jsonMap['secure_url'];
    } else {
      // Print error to console so we can debug if it fails
      print("Cloudinary Upload Failed: ${response.statusCode}");
      throw Exception("Failed to upload image. Please check your internet.");
    }
  }

  // 2. GET AUTOMATIC LOCATION (GPS) - (Kept exactly the same)
  Future<String> getCurrentLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception("Location permission denied");
      }
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    List<Placemark> placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );

    if (placemarks.isNotEmpty) {
      Placemark place = placemarks[0];
      return "${place.locality}, ${place.country}";
    }
    return "Unknown Location";
  }

  // 3. UPDATE PROFILE DATA - (Kept exactly the same)
  Future<void> updateProfile({
    String? name,
    String? about,
    String? location,
    List<String>? skills,
    String? photoUrl,
  }) async {
    String? uid = getCurrentUserId();
    if (uid == null) throw Exception("No user logged in");

    Map<String, dynamic> dataToUpdate = {};
    if (name != null) dataToUpdate['name'] = name;
    if (about != null) dataToUpdate['about'] = about;
    if (location != null) dataToUpdate['location'] = location;
    if (skills != null) dataToUpdate['skills'] = skills;
    if (photoUrl != null) dataToUpdate['photoUrl'] = photoUrl;

    if (dataToUpdate.isNotEmpty) {
      await _firestore.collection('users').doc(uid).update(dataToUpdate);

      if (name != null) {
        await _auth.currentUser?.updateDisplayName(name);
      }
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> saveResume(Map<String, dynamic> resumeData) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'resume': resumeData,
      'hasResume': true, // Flag to easily check if they have one
    });
  }
}
