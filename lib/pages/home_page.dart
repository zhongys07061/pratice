import 'package:flutter/material.dart';

import '../models/question.dart';
import '../services/storage_service.dart';
import 'import_page.dart';
import 'question_bank_page.dart';
import 'quiz_page.dart';
import 'stats_page.dart';
import 'wrong_page.dart';

/// 首页：统计概览 + 三种练习模式入口
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final StorageService _storage = StorageService.instance;

  final int _defaultRandomCount = 30; // 随机抽题默认数量

  /// 全部有效题目 = 内置题库（过滤已删除） + 导入题库
  List<Question> get _bank => _storage.effectiveBank();

  Future<void> _openQuiz(
    List<Question> questions,
    String title, {
    int progressBase = -1,
  }) async {
    if (questions.isEmpty) {
      _showSnack('没有可练习的题目');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizPage(
          questions: questions,
          title: title,
          progressBase: progressBase,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  int get _orderProgress {
    final p = _storage.orderProgress;
    return (p >= 0 && p < _bank.length) ? p : 0;
  }

  String _orderSubtitle() {
    final p = _orderProgress;
    if (p > 0) return '继续练习（第 ${p + 1} / ${_bank.length} 题）';
    return '按顺序练习全部 ${_bank.length} 道题';
  }

  void _startOrder() {
    final start = _orderProgress;
    _openQuiz(_bank.sublist(start), '顺序练习', progressBase: start);
  }

  void _resetOrder() {
    _storage.setOrderProgress(0);
    setState(() {});
    _showSnack('已从头开始');
  }

  Future<void> _openImport() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ImportPage()),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openBank() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const QuestionBankPage()),
    );
    if (mounted) setState(() {});
  }

  Future<void> _startRandom() async {
    final bank = _bank;
    if (bank.isEmpty) {
      _showSnack('没有可练习的题目');
      return;
    }
    final total = bank.length;
    final result = await showDialog<(int, String)>(
      context: context,
      builder: (ctx) => _RandomConfigDialog(
        total: total,
        initial: _defaultRandomCount < total ? _defaultRandomCount : total,
      ),
    );
    if (result == null || !mounted) return;
    final (count, type) = result;

    var pool = bank;
    if (type == 'choice') {
      pool = bank.where((q) => q.isChoice).toList();
    } else if (type == 'judge') {
      pool = bank.where((q) => !q.isChoice).toList();
    }
    if (pool.isEmpty) {
      _showSnack('没有该题型的题目');
      return;
    }
    final n = count < pool.length ? count : pool.length;
    final shuffled = List.of(pool)..shuffle();
    _openQuiz(shuffled.take(n).toList(), '随机抽题');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final answered = _storage.answered;
    final correct = _storage.correct;
    final wrongCount = _storage.wrongCount;
    final accuracy = answered == 0 ? 0.0 : correct / answered;

    return Scaffold(
      body: Stack(
        children: [
          // 顶部渐变背景
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 260,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              children: [
                // 标题
                Row(
                  children: [
                    const Icon(Icons.menu_book, color: Colors.white, size: 30),
                    const SizedBox(width: 10),
                    const Text(
                      '自测宝',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.bar_chart, color: Colors.white),
                      tooltip: '统计',
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const StatsPage()),
                        );
                        if (mounted) setState(() {});
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 统计概览卡片
                _buildStatsCard(theme, answered, correct, wrongCount, accuracy),
                const SizedBox(height: 24),

                Text('练习模式',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),

                _ModeCard(
                  icon: Icons.format_list_numbered,
                  color: const Color(0xFF4F46E5),
                  title: '顺序练习',
                  subtitle: _orderSubtitle(),
                  onTap: _startOrder,
                  trailing: _orderProgress > 0
                      ? IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.grey),
                          tooltip: '从头开始',
                          onPressed: _resetOrder,
                        )
                      : null,
                ),
                _ModeCard(
                  icon: Icons.shuffle,
                  color: const Color(0xFF7C3AED),
                  title: '随机抽题',
                  subtitle: '自定义数量，随机打乱顺序',
                  onTap: _startRandom,
                ),
                _ModeCard(
                  icon: Icons.assignment_late,
                  color: const Color(0xFFF59E0B),
                  title: '错题本',
                  subtitle: wrongCount == 0 ? '暂无错题，继续保持' : '重练 $wrongCount 道错题',
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const WrongPage()),
                    );
                    if (mounted) setState(() {});
                  },
                ),
                _ModeCard(
                  icon: Icons.upload_file,
                  color: const Color(0xFF10B981),
                  title: '导入题库',
                  subtitle: _storage.importedQuestions.isEmpty
                      ? '从 txt 文件导入题目'
                      : '已导入 ${_storage.importedQuestions.length} 道题',
                  onTap: _openImport,
                ),
                _ModeCard(
                  icon: Icons.folder_open,
                  color: const Color(0xFF6366F1),
                  title: '题库管理',
                  subtitle: '查看、增删题目，支持批量操作',
                  onTap: _openBank,
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.insights),
                  label: const Text('查看详细统计'),
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const StatsPage()),
                    );
                    if (mounted) setState(() {});
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(
    ThemeData theme,
    int answered,
    int correct,
    int wrongCount,
    double accuracy,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('总正确率',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    Text(
                      '${(accuracy * 100).toStringAsFixed(1)}%',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: accuracy),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOut,
                builder: (context, value, _) => SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(
                    value: value,
                    strokeWidth: 7,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatItem(label: '已刷', value: '$answered'),
              _StatItem(label: '答对', value: '$correct'),
              _StatItem(label: '错题', value: '$wrongCount'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  const _ModeCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EAF0)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [color, color.withValues(alpha: 0.7)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 3),
                      Text(subtitle,
                          style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                trailing ?? const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 随机抽题配置对话框：题型 + 数量
class _RandomConfigDialog extends StatefulWidget {
  final int total;
  final int initial;
  const _RandomConfigDialog({required this.total, required this.initial});

  @override
  State<_RandomConfigDialog> createState() => _RandomConfigDialogState();
}

class _RandomConfigDialogState extends State<_RandomConfigDialog> {
  late int _count = widget.initial;
  String _type = 'all'; // all / choice / judge

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('随机抽题'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'all', label: Text('全部')),
              ButtonSegment(value: 'choice', label: Text('选择题')),
              ButtonSegment(value: 'judge', label: Text('判断题')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 20),
          Text('从 ${widget.total} 道题中随机抽取'),
          const SizedBox(height: 8),
          Text(
            '$_count 道',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          Slider(
            value: _count.toDouble(),
            min: 1,
            max: widget.total.toDouble(),
            divisions: widget.total > 1 ? widget.total - 1 : null,
            label: '$_count',
            onChanged: (v) => setState(() => _count = v.round()),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => setState(() => _count = 1),
                child: const Text('最少'),
              ),
              TextButton(
                onPressed: () => setState(() => _count = widget.total),
                child: const Text('全部'),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop((_count, _type)),
          child: const Text('开始'),
        ),
      ],
    );
  }
}
