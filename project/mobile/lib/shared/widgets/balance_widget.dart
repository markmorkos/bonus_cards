import "package:flutter/material.dart";

class BalanceWidget extends StatelessWidget {
  final String balance;

  const BalanceWidget({super.key, required this.balance});

  @override
  Widget build(BuildContext context) {
    return Text(
      "Баланс: $balance",
      style: Theme.of(context).textTheme.headlineSmall,
    );
  }
}