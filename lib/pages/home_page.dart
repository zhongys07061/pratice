import 'package:flutter/material.dart';

import '../models/question.dart';
import '../services/import_parser.dart';
import '../services/native_service.dart';
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

  /// 全部有效题目 = 内置题库（过滤已删除） + 导入题库
  List<Question> get _bank => _storage.effectiveBank();

  @override
  void initState() {
    super.initState();
    _initSharedFile();
  }

  Future<void> _initSharedFile() async {
    NativeService.instance.setSharedFileListener((file) async {
      final n = await _importSharedFile(file);
      if (!mounted) return;
      setState(() {});
      _showSnack(n > 0 ? '已从外部文档导入 $n 道题' : '未能从该文档解析出题目');
    });
    final file = await NativeService.instance.takeSharedFile();
    if (file == null) return;
    final n = await _importSharedFile(file);
    if (!mounted) return;
    setState(() {});
    _showSnack(n > 0 ? '已从外部文档导入 $n 道题' : '未能从该文档解析出题目');
  }

  Future<int> _importSharedFile(SharedFile file) async {
    final content = ImportParser.extractText(file.name, file.bytes);
    final questions = ImportParser.parse(content, _nextImportId());
    if (questions.isEmpty) return 0;
    await _storage.addImportedQuestions(questions);
    return questions.length;
  }

  int _nextImportId() {
    final imported = _storage.importedQuestions;
    if (imported.isEmpty) return 100000;
    return imported.map((q) => q.id).reduce((a, b) => a > b ? a : b) + 1;
  }

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
    final choicePool = bank.where((q) => q.isChoice).toList();
    final judgePool = bank.where((q) => !q.isChoice).toList();

    final result = await showDialog<(int, int)>(
      context: context,
      builder: (ctx) => _RandomConfigDialog(
        choiceTotal: choicePool.length,
        judgeTotal: judgePool.length,
      ),
    );
    if (result == null || !mounted) return;
    final (choiceCount, judgeCount) = result;
    if (choiceCount + judgeCount == 0) {
      _showSnack('请至少选择 1 道题');
      return;
    }

    final picked = <Question>[];
    if (choiceCount > 0) {
      final c = List.of(choicePool)..shuffle();
      picked.addAll(c.take(choiceCount));
    }
    if (judgeCount > 0) {
      final j = List.of(judgePool)..shuffle();
      picked.addAll(j.take(judgeCount));
    }
    picked.shuffle();
    _openQuiz(picked, '随机抽题');
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
                  subtitle: '自定义数量与题型比例，随机打乱顺序',
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
                      ? '扫描/批量导入 txt、docx、pdf'
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

/// 随机抽题配置对话框：分别设置选择题与判断题数量（任意比例混合）。
class _RandomConfigDialog extends StatefulWidget {
  final int choiceTotal;
  final int judgeTotal;
  const _RandomConfigDialog({
    required this.choiceTotal,
    required this.judgeTotal,
  });

  @override
  State<_RandomConfigDialog> createState() => _RandomConfigDialogState();
}

class _RandomConfigDialogState extends State<_RandomConfigDialog> {
  late int _choiceCount;
  late int _judgeCount;

  @override
  void initState() {
    super.initState();
    _choiceCount = widget.choiceTotal >= 15 ? 15 : widget.choiceTotal;
    _judgeCount = widget.judgeTotal >= 15 ? 15 : widget.judgeTotal;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = _choiceCount + _judgeCount;
    return AlertDialog(
      title: const Text('随机抽题'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('选择题（共 ${widget.choiceTotal} 道）',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            _countSlider(
              value: _choiceCount,
              max: widget.choiceTotal,
              color: Colors.blue,
              onChanged: (v) => setState(() => _choiceCount = v),
            ),
            const SizedBox(height: 16),
            Text('判断题（共 ${widget.judgeTotal} 道）',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            _countSlider(
              value: _judgeCount,
              max: widget.judgeTotal,
              color: Colors.teal,
              onChanged: (v) => setState(() => _judgeCount = v),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                '共 $total 道题',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: total == 0
              ? null
              : () => Navigator.of(context).pop((_choiceCount, _judgeCount)),
          child: const Text('开始'),
        ),
      ],
    );
  }

  Widget _countSlider({
    required int value,
    required int max,
    required Color color,
    required ValueChanged<int> onChanged,
  }) {
    final enabled = max > 0;
    return Row(
      children: [
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: enabled ? max.toDouble() : 1,
            divisions: enabled ? max : 1,
            label: '$value',
            activeColor: color,
            onChanged: enabled ? (v) => onChanged(v.round()) : null,
          ),
        ),
        SizedBox(
          width: 36,
          child: Text('$value', textAlign: TextAlign.center),
        ),
      ],
    );
  }
}
