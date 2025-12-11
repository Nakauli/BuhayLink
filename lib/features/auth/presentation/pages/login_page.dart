import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../../../../core/presentation/widgets/primary_button.dart';
import '../../../../core/presentation/widgets/text_input_field.dart';
import '../../../../config/routes/app_routes.dart'; //

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final provider = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextInputField(controller: emailCtrl, label: "Email"),
            TextInputField(controller: passCtrl, label: "Password"),
            const SizedBox(height: 20),
            PrimaryButton(
              text: "Login",
              onPressed: () async {
                final error = await provider.login(emailCtrl.text, passCtrl.text);
                if (error == null) {
                  Navigator.pushReplacementNamed(context, AppRoutes.home);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}