import 'package:flutter/material.dart';
import '../../data/repositories/auth_repository.dart'; //

class AuthProvider extends ChangeNotifier {
  final _repo = AuthRepository();

  Future<String?> login(String email, String password) async {
    try {
      await _repo.signIn(email, password);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> logout() => _repo.signOut();
}