import "package:flutter/material.dart";

class HistoryScreen extends StatelessWidget {
  final List<Map<String, dynamic>> transactions;

  const HistoryScreen({super.key, required this.transactions});

  String _typeLabel(String? type) {
    switch (type) {
      case "earn":
        return "Нарахування";
      case "spend":
        return "Списання";
      default:
        return "Невідомо";
    }
  }

  Color _typeColor(String? type) {
    switch (type) {
      case "earn":
        return Colors.green;
      case "spend":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _typeIcon(String? type) {
    switch (type) {
      case "earn":
        return Icons.add_circle_outline;
      case "spend":
        return Icons.remove_circle_outline;
      default:
        return Icons.swap_horiz;
    }
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return "";
    try {
      final dt = DateTime.parse(raw).toLocal();
      final day = dt.day.toString().padLeft(2, "0");
      final month = dt.month.toString().padLeft(2, "0");
      final year = dt.year;
      final hour = dt.hour.toString().padLeft(2, "0");
      final minute = dt.minute.toString().padLeft(2, "0");
      return "$day.$month.$year $hour:$minute";
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Історія транзакцій")),
      body: transactions.isEmpty
          ? const Center(child: Text("Транзакцій ще немає"))
          : ListView.builder(
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final tx = transactions[index];
                final type = tx["type"]?.toString();
                final amount = tx["amount"]?.toString() ?? "-";
                final balanceAfter = tx["balance_after"]?.toString() ?? "";
                final description = tx["description"]?.toString() ?? "";
                final createdAt = _formatDate(tx["created_at"]?.toString());

                return ListTile(
                  leading: Icon(_typeIcon(type), color: _typeColor(type)),
                  title: Text(
                    "${_typeLabel(type)}: $amount грн",
                    style: TextStyle(
                      color: _typeColor(type),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (description.isNotEmpty) Text(description),
                      Text(createdAt, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  trailing: Text(
                    "Баланс: $balanceAfter грн",
                    style: const TextStyle(fontSize: 12),
                  ),
                  isThreeLine: description.isNotEmpty,
                );
              },
            ),
    );
  }
}