import 'package:flutter/material.dart';

class TextInputField extends StatelessWidget { //
  final TextEditingController controller;
  final String label;

  const TextInputField({super.key, required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}