import 'package:flutter/material.dart';

class PrimaryButton extends StatelessWidget{
  final String text;
  final VoidCallback onPressed;

  const PrimaryButton({super.key, required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context){

  return ElevatedButton(onPressed: onPressed, child: Text(text));
  }
}