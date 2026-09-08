import 'package:flutter/material.dart';

import '../models/question.dart';
import '../services/storage_service.dart';
import 'quiz_page.dart';

/// 错题本页：列出所有错题，支持单题重练或整组重练。
class WrongPage extends StatefulWidget {
  const WrongPage({super.key});

  @override
  State<WrongPage> createState() => _WrongPageState();
}

class _WrongPageState extends State<WrongPage> {
  final StorageService _storage = StorageService.instance;

  List<Question> get _bank => _storage.effectiveBank();

  List<Question> get _wrongQuestions {
    final ids = _storage.wrongIds.toSet();
    return _bank.where((q) => ids.contains(q.id)).toList();
  }

  Future<void> _start(List<Question> questions, String title) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizPage(questions: questions, title: title),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wrong = _wrongQuestions;

    return Scaffold(
      appBar: AppBar(title: const Text('错题本'), centerTitle: true),
      body: wrong.isEmpty
          ? const _EmptyWrong()
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: Text('重练全部（${wrong.length} 题）'),
                      onPressed: () => _start(wrong, '错题重练'),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: wrong.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final q = wrong[i];
                      return Card(
                        elevation: 0,
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          onTap: () => _start([q], '错题重练'),
                          leading: _TypeBadge(isChoice: q.isChoice),
                          title: Text(
                            q.stem,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '正确答案：${q.options[q.answer]}',
                            style: theme.textTheme.bodySmall,
                          ),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final bool isChoice;
  const _TypeBadge({required this.isChoice});

  @override
  Widget build(BuildContext context) {
    final color = isChoice ? Colors.blue : Colors.teal;
    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.15),
      child: Text(
        isChoice ? '选' : '判',
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _EmptyWrong extends StatelessWidget {
  const _EmptyWrong();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.verified_outlined,
              size: 72, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text('暂无错题', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            '答错的题目会自动收录到这里',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
