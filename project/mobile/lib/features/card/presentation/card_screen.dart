import "dart:async";

import "package:barcode_widget/barcode_widget.dart";
import "package:flutter/material.dart";
import "package:qr_flutter/qr_flutter.dart";

import "../../auth/data/auth_repository.dart";
import "../../auth/presentation/login_screen.dart";
import "../../history/data/transaction_repository.dart";
import "../../history/presentation/history_screen.dart";
import "../data/card_repository.dart";

class CardScreen extends StatefulWidget {
  final String token;

  const CardScreen({super.key, required this.token});

  @override
  State<CardScreen> createState() => _CardScreenState();
}

class _CardScreenState extends State<CardScreen> {
  final _cardRepository = CardRepository();
  final _authRepository = AuthRepository();
  final _transactionRepository = TransactionRepository();

  bool _loading = true;
  bool _showBarcode = false;
  Map<String, dynamic>? _card;
  String? _error;
  Timer? _refreshTimer;

  static const _autoRefreshInterval = Duration(seconds: 30);

  static const double _cashbackMin = 3.0;
  static const double _cashbackMax = 12.0;

  @override
  void initState() {
    super.initState();
    _loadCard();
    _refreshTimer = Timer.periodic(_autoRefreshInterval, (_) => _loadCard());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCard() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final card = await _cardRepository.getMyCard(widget.token);
      if (!mounted) return;
      setState(() {
        _card = card;
      });
    } catch (_) {
      try {
        final created = await _cardRepository.createCard(widget.token);
        if (!mounted) return;
        setState(() {
          _card = created;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _error = "Не вдалося завантажити картку";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _openHistory() async {
    if (_card == null) return;
    final cardId = _card!["id"]?.toString();
    if (cardId == null) return;

    try {
      final rows = await _transactionRepository.getTransactions(
        token: widget.token,
        cardId: cardId,
      );
      final data = rows.map((e) => (e as Map).cast<String, dynamic>()).toList();

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => HistoryScreen(transactions: data),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Не вдалося завантажити історію")),
      );
    }
  }

  Future<void> _logout() async {
    await _authRepository.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  String _levelLabel(String? level) {
    switch (level) {
      case "silver":
        return "Срібний";
      case "gold":
        return "Золотий";
      default:
        return "Стандарт";
    }
  }

  IconData _levelIcon(String? level) {
    switch (level) {
      case "silver":
        return Icons.star_half;
      case "gold":
        return Icons.star;
      default:
        return Icons.verified_user_outlined;
    }
  }

  Color _levelColor(String? level) {
    switch (level) {
      case "silver":
        return const Color(0xFF9E9E9E);
      case "gold":
        return const Color(0xFFFFD700);
      default:
        return const Color(0xFF005BBB);
    }
  }

  Color _cashbackColor(double rate) {
    if (rate >= 10) return const Color(0xFFFFD700);
    if (rate >= 7) return const Color(0xFF4CAF50);
    return const Color(0xFF005BBB);
  }

  @override
  Widget build(BuildContext context) {
    final card = _card;
    final cardNumber = card?["card_number"]?.toString() ?? "";
    final cashbackRate = double.tryParse(card?["cashback_rate"]?.toString() ?? "") ?? _cashbackMin;
    final txCount = int.tryParse(card?["transactions_count"]?.toString() ?? "") ?? 0;
    final balance = double.tryParse(card?["balance"]?.toString() ?? "") ?? 0.0;
    final cashbackProgress = ((cashbackRate - _cashbackMin) / (_cashbackMax - _cashbackMin)).clamp(0.0, 1.0);
    final isMaxRate = cashbackRate >= _cashbackMax;

    return Scaffold(
      appBar: AppBar(
        title: Text(cardNumber.isNotEmpty ? "Картка $cardNumber" : "Картка"),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadCard,
            icon: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.refresh),
            tooltip: "Оновити",
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : card == null
                  ? const Center(child: Text("Картка не знайдена"))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!_showBarcode) ...[
                            // ── Row: рівень + баланс ──
                            Row(
                              children: [
                                Expanded(
                                  child: _InfoTile(
                                    icon: _levelIcon(card["level"]?.toString()),
                                    iconColor: _levelColor(card["level"]?.toString()),
                                    label: "Рівень",
                                    value: _levelLabel(card["level"]?.toString()),
                                    borderColor: _levelColor(card["level"]?.toString()),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _InfoTile(
                                    icon: Icons.monetization_on_outlined,
                                    iconColor: const Color(0xFFE6A800),
                                    label: "Бонусів",
                                    value: balance.toStringAsFixed(2),
                                    borderColor: const Color(0xFFFFD700),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // ── Cashback rate card ──
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    _cashbackColor(cashbackRate).withOpacity(0.15),
                                    _cashbackColor(cashbackRate).withOpacity(0.05),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _cashbackColor(cashbackRate),
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.percent,
                                            color: _cashbackColor(cashbackRate),
                                            size: 20,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            "Кешбек",
                                            style: TextStyle(
                                              color: _cashbackColor(cashbackRate),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _cashbackColor(cashbackRate),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          "${cashbackRate.toStringAsFixed(0)}%",
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  // Progress bar 3% → 12%
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                      value: cashbackProgress,
                                      minHeight: 10,
                                      backgroundColor: Colors.grey.shade200,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        _cashbackColor(cashbackRate),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "${_cashbackMin.toStringAsFixed(0)}%",
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                      Text(
                                        isMaxRate
                                            ? "Максимальний рівень! 🎉"
                                            : "$txCount рахунків закрито · наступний: ${(cashbackRate + 1).toStringAsFixed(0)}%",
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isMaxRate
                                              ? const Color(0xFFFFD700)
                                              : Colors.grey,
                                          fontWeight: isMaxRate ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                      Text(
                                        "${_cashbackMax.toStringAsFixed(0)}%",
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),

                            // ── 50% spend info ──
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, size: 18, color: Colors.blue.shade400),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      "Списати бонусами можна до 50% від суми рахунку",
                                      style: TextStyle(fontSize: 12, color: Colors.black87),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // ── QR-код ──
                          Center(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF005BBB),
                                    Color(0xFFFFD700),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF005BBB).withOpacity(0.4),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.all(12),
                                child: QrImageView(
                                  data: (card["qr_code_data"] ?? "").toString(),
                                  size: MediaQuery.of(context).size.width - 96,
                                  eyeStyle: const QrEyeStyle(
                                    eyeShape: QrEyeShape.square,
                                    color: Color(0xFF005BBB),
                                  ),
                                  dataModuleStyle: const QrDataModuleStyle(
                                    dataModuleShape: QrDataModuleShape.square,
                                    color: Color(0xFF003F8A),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ── Штрих-код або кнопки ──
                          if (_showBarcode) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: BarcodeWidget(
                                    barcode: Barcode.code128(),
                                    data: (card["card_number"] ?? "").toString(),
                                    height: 80,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: () => setState(() => _showBarcode = false),
                                  icon: const Icon(Icons.close, size: 28),
                                  color: Colors.grey[700],
                                ),
                              ],
                            ),
                          ] else ...[
                            ElevatedButton.icon(
                              onPressed: () => setState(() => _showBarcode = true),
                              icon: const Icon(Icons.barcode_reader),
                              label: const Text("Показати штрих-код"),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: _openHistory,
                              icon: const Icon(Icons.history),
                              label: const Text("Історія транзакцій"),
                            ),
                          ],
                        ],
                      ),
                    ),
    );
  }
}

/// Compact info tile used for level and balance.
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color borderColor;

  const _InfoTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: borderColor.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: iconColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}