import "package:flutter/material.dart";

import "features/auth/data/auth_repository.dart";
import "features/auth/presentation/login_screen.dart";
import "features/card/presentation/card_screen.dart";
import "shared/theme.dart";

class BonusApp extends StatelessWidget {
  const BonusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Bonus Cards",
      theme: appTheme,
      home: const _StartupGate(),
    );
  }
}

class _StartupGate extends StatefulWidget {
  const _StartupGate();

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  final _authRepository = AuthRepository();
  late final Future<String?> _tokenFuture;

  @override
  void initState() {
    super.initState();
    _tokenFuture = _authRepository.getToken();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _tokenFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final token = snapshot.data;
        if (token == null || token.isEmpty) {
          return const LoginScreen();
        }
        return CardScreen(token: token);
      },
    );
  }
}
