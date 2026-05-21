import "package:flutter/material.dart";

class BonusCardWidget extends StatelessWidget {
  final Widget child;

  const BonusCardWidget({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: child,
      ),
    );
  }
}