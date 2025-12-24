import 'package:buhay_link/features/auth/data/models/user_model.dart';
import 'package:flutter/material.dart';
import '../../data/repositories/auth_repository.dart';


class AuthProvider extends ChangeNotifier {
  final _repo = AuthRepository();

  // --- 1. ADD THIS STATE VARIABLE ---
  UserModel? _user;
  

  // --- 2. ADD THIS GETTER (Fixes the Search Page error) ---
  UserModel? get user => _user;

  Future<String?> login(String email, String password) async {
    try {
      await _repo.signIn(email, password);
      
      // --- 3. CRITICAL: UPDATE THE USER STATE ---
      // You need to fetch the user details after logging in.
      // Assuming your repo has a method like 'getCurrentUser' or similar.
      // If not, you'll need to implement getting the user data here.
      // Example:
      // _user = await _repo.getCurrentUser(); 
      
      notifyListeners(); // <--- Tell the app the user has changed
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> logout() async {
    await _repo.signOut();
    _user = null; // <--- Clear the user on logout
    notifyListeners();
  }
  
  // Optional: A helper to manually set user (e.g., on app startup)
  void setUser(UserModel? user) {
    _user = user;
    notifyListeners();
  }
}