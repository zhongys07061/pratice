import 'package:flutter/material.dart';

import '../services/storage_service.dart';

/// 答题统计页
class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  final StorageService _storage = StorageService.instance;

  Future<void> _reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重置统计'),
        content: const Text('将清空答题统计与错题本，确定吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确定重置'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _storage.reset();
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final answered = _storage.answered;
    final correct = _storage.correct;
    final wrong = answered - correct;
    final accuracy = answered == 0 ? 0.0 : correct / answered;

    return Scaffold(
      appBar: AppBar(title: const Text('答题统计')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 正确率大卡片
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Text('总正确率',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 12),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: accuracy),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOut,
                  builder: (context, value, _) => Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: CircularProgressIndicator(
                          value: value,
                          strokeWidth: 9,
                          backgroundColor: Colors.white24,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${(value * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _rowCard('累计答题', '$answered 题', Icons.edit_note, const Color(0xFF4F46E5)),
          _rowCard('答对', '$correct 题', Icons.check_circle, Colors.green),
          _rowCard('答错', '$wrong 题', Icons.cancel, Colors.red),
          _rowCard('错题本', '${_storage.wrongCount} 题', Icons.assignment_late,
              const Color(0xFFF59E0B)),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            icon: const Icon(Icons.delete_outline),
            label: const Text('重置统计与错题本'),
            onPressed: answered == 0 && _storage.wrongCount == 0 ? null : _reset,
          ),
        ],
      ),
    );
  }

  Widget _rowCard(String label, String value, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EAF0)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
