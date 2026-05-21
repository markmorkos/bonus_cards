import "package:flutter/material.dart";

import "../data/auth_repository.dart";

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _loading = false;
  final _repo = AuthRepository();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    setState(() => _loading = true);
    try {
      await _repo.register(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        fullName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Реєстрація успішна")),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Помилка реєстрації")),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Реєстрація")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _emailController, decoration: const InputDecoration(labelText: "Email")),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: "Пароль"),
              obscureText: true,
            ),
            TextField(controller: _fullNameController, decoration: const InputDecoration(labelText: "Повне ім'я")),
            TextField(controller: _phoneController, decoration: const InputDecoration(labelText: "Телефон")),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loading ? null : _register,
              child: Text(_loading ? "Зачекайте..." : "Зареєструватися"),
            ),
          ],
        ),
      ),
    );
  }
}