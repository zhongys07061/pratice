import 'package:flutter/material.dart';

import '../models/question.dart';
import '../services/storage_service.dart';

/// 答题页：选择题 + 判断题，即时反馈、动画过渡。
class QuizPage extends StatefulWidget {
  final List<Question> questions;
  final String title;

  /// 顺序练习的起始索引（>=0 时表示顺序练习，需要保存进度）
  final int progressBase;

  const QuizPage({
    super.key,
    required this.questions,
    required this.title,
    this.progressBase = -1,
  });

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  int _index = 0;
  int? _selected;
  int _score = 0;
  int _correct = 0;
  bool _finished = false;

  Question get _current => widget.questions[_index];
  bool get _answered => _selected != null;

  void _choose(int optionIndex) {
    if (_answered) return;
    final correct = optionIndex == _current.answer;
    setState(() {
      _selected = optionIndex;
      if (correct) {
        _score++;
        _correct++;
      }
    });
    StorageService.instance.recordAnswer(_current.id, correct);
  }

  void _next() {
    if (_index < widget.questions.length - 1) {
      // 顺序练习：保存进度（下次从下一题开始）
      if (widget.progressBase >= 0) {
        StorageService.instance.setOrderProgress(widget.progressBase + _index + 1);
      }
      setState(() {
        _index++;
        _selected = null;
      });
    } else {
      // 完成一轮：顺序练习进度归零
      if (widget.progressBase >= 0) {
        StorageService.instance.setOrderProgress(0);
      }
      setState(() => _finished = true);
    }
  }

  void _restart() {
    setState(() {
      _index = 0;
      _selected = null;
      _score = 0;
      _correct = 0;
      _finished = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _finished ? _buildResult() : _buildQuiz(),
    );
  }

  // ─────────── 答题视图 ───────────
  Widget _buildQuiz() {
    final theme = Theme.of(context);
    final total = widget.questions.length;
    final progress = (_index + 1) / total;

    return Column(
      children: [
        _buildHeader(theme, total, progress),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTypeBadge(theme),
                const SizedBox(height: 12),
                Text(
                  _current.stem,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w600, height: 1.45),
                ),
                const SizedBox(height: 24),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _current.isChoice
                      ? _buildChoiceOptions(theme)
                      : _buildJudgeOptions(theme),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  child: (_answered && _current.explanation != null)
                      ? Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: _buildExplanation(theme),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _answered ? _next : null,
                child: Text(
                  _index == total - 1 ? '完成' : '下一题',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(ThemeData theme, int total, double progress) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('第 ${_index + 1} / $total 题',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              Row(
                children: [
                  _Chip(icon: Icons.check_circle, color: Colors.green, text: '$_correct'),
                  const SizedBox(width: 8),
                  _Chip(icon: Icons.star, color: Colors.amber, text: '$_score 分'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 300),
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeBadge(ThemeData theme) {
    final isChoice = _current.isChoice;
    final color = isChoice ? Colors.blue : Colors.teal;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          isChoice ? '选择题' : '判断题',
          style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildChoiceOptions(ThemeData theme) {
    return Column(
      key: ValueKey('choice-${_current.id}-$_index'),
      children: List.generate(_current.options.length, (i) {
        return _buildOption(
          theme,
          index: i,
          label: String.fromCharCode(65 + i),
          text: _current.options[i],
        );
      }),
    );
  }

  Widget _buildJudgeOptions(ThemeData theme) {
    return Row(
      key: ValueKey('judge-${_current.id}-$_index'),
      children: [
        Expanded(child: _buildOption(theme, index: 0, label: '✓', text: '对')),
        const SizedBox(width: 12),
        Expanded(child: _buildOption(theme, index: 1, label: '✗', text: '错')),
      ],
    );
  }

  Widget _buildOption(
    ThemeData theme, {
    required int index,
    required String label,
    required String text,
  }) {
    final isCorrect = index == _current.answer;
    final isPicked = index == _selected;

    Color bg = theme.colorScheme.surface;
    Color border = theme.colorScheme.outlineVariant;
    Color fg = theme.colorScheme.onSurface;
    Color badgeBg = theme.colorScheme.primaryContainer;
    Color badgeFg = theme.colorScheme.onPrimaryContainer;
    Widget? trailing;

    if (_answered) {
      if (isCorrect) {
        bg = Colors.green.withValues(alpha: 0.14);
        border = Colors.green;
        fg = Colors.green.shade800;
        badgeBg = Colors.green;
        badgeFg = Colors.white;
        trailing = const Icon(Icons.check_circle, color: Colors.green, size: 22);
      } else if (isPicked) {
        bg = Colors.red.withValues(alpha: 0.12);
        border = Colors.red;
        fg = Colors.red.shade800;
        badgeBg = Colors.red;
        badgeFg = Colors.white;
        trailing = const Icon(Icons.cancel, color: Colors.red, size: 22);
      } else {
        bg = theme.colorScheme.surface;
        border = theme.colorScheme.outlineVariant;
        fg = theme.colorScheme.onSurface.withValues(alpha: 0.45);
      }
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1.5),
        boxShadow: (_answered && (isCorrect || isPicked))
            ? [
                BoxShadow(
                  color: border.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _answered ? null : () => _choose(index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: badgeBg,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: badgeFg,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 16,
                      color: fg,
                      fontWeight: (_answered && (isCorrect || isPicked))
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExplanation(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline, color: Colors.amber, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text('解析：${_current.explanation}', style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  // ─────────── 结果视图 ───────────
  Widget _buildResult() {
    final theme = Theme.of(context);
    final total = widget.questions.length;
    final accuracy = total == 0 ? 0.0 : _score / total;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: accuracy),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOut,
              builder: (context, value, _) {
                final color = value >= 0.8
                    ? Colors.amber
                    : value >= 0.6
                        ? Colors.green
                        : theme.colorScheme.primary;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 140,
                      height: 140,
                      child: CircularProgressIndicator(
                        value: value,
                        strokeWidth: 10,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        color: color,
                      ),
                    ),
                    Text(
                      '${(value * 100).toStringAsFixed(0)}%',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            Text('练习完成',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('答对 $_correct / $total 题',
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('得分 $_score',
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                icon: const Icon(Icons.replay),
                label: const Text('再来一次'),
                onPressed: _restart,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('返回首页'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _Chip({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 3),
          Text(text,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
