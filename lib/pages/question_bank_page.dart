import 'package:flutter/material.dart';

import '../data/question_bank.dart';
import '../models/question.dart';
import '../services/storage_service.dart';

/// 题库管理页：查看、增删题目，支持批量操作。
class QuestionBankPage extends StatefulWidget {
  const QuestionBankPage({super.key});

  @override
  State<QuestionBankPage> createState() => _QuestionBankPageState();
}

class _QuestionBankPageState extends State<QuestionBankPage> {
  final StorageService _storage = StorageService.instance;
  late List<Question> _bank;
  bool _selectionMode = false;
  final Set<int> _selected = {};
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    _bank = _storage.effectiveBank();
  }

  void _reload() {
    setState(() {
      _bank = _storage.effectiveBank();
    });
  }

  bool _isImported(Question q) => q.id >= 100000;

  List<Question> get _filtered {
    final kw = _keyword.trim();
    if (kw.isEmpty) return _bank;
    return _bank.where((q) => q.stem.contains(kw)).toList();
  }

  int get _deletedCount => _storage.deletedBuiltinIds.length;

  Future<void> _showTrash() async {
    final deleted = _storage.deletedBuiltinIds;
    final deletedQuestions =
        buildQuestionBank().where((q) => deleted.contains(q.id)).toList();
    if (deletedQuestions.isEmpty) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _TrashSheet(questions: deletedQuestions),
    );
    _reload();
  }

  Future<void> _delete(List<int> ids) async {
    if (ids.isEmpty) return;
    final builtin = ids.where((id) => id < 100000).toList();
    final imported = ids.where((id) => id >= 100000).toList();
    if (builtin.isNotEmpty) await _storage.deleteBuiltin(builtin);
    if (imported.isNotEmpty) await _storage.removeImportedQuestions(imported);
    _selected.removeAll(ids);
    _reload();
  }

  Future<void> _confirmDelete(List<int> ids) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除题目'),
        content: Text('确定删除选中的 ${ids.length} 道题吗？内置题可恢复，导入题将彻底删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _delete(ids);
      if (_selectionMode) setState(() {});
      _show('已删除 ${ids.length} 道题');
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      _selected.clear();
    });
  }

  void _show(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _editQuestion(Question q) async {
    final edited = await showDialog<Question>(
      context: context,
      builder: (ctx) => _EditQuestionDialog(question: q),
    );
    if (edited != null) {
      await _storage.updateQuestion(edited);
      _reload();
      _show('已保存修改');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final choiceCount = _bank.where((q) => q.isChoice).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectionMode ? '已选 ${_selected.length} 题' : '题库管理'),
        actions: [
          if (_selectionMode)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _toggleSelectionMode,
            )
          else ...[
            if (_deletedCount > 0)
              IconButton(
                icon: const Icon(Icons.restore),
                tooltip: '恢复已删除（$_deletedCount）',
                onPressed: _showTrash,
              ),
            IconButton(
              icon: const Icon(Icons.checklist),
              tooltip: '批量管理',
              onPressed: _toggleSelectionMode,
            ),
          ],
        ],
      ),
      bottomNavigationBar: _selectionMode
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.select_all),
                        label: const Text('全选'),
                        onPressed: () {
                          setState(() {
                            if (_selected.length == _bank.length) {
                              _selected.clear();
                            } else {
                              _selected.addAll(_bank.map((q) => q.id));
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.delete),
                        label: const Text('删除'),
                        style: FilledButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: _selected.isEmpty
                            ? null
                            : () => _confirmDelete(_selected.toList()),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            child: Row(
              children: [
                _tag('共 ${_bank.length} 题', theme.colorScheme.primary),
                const SizedBox(width: 8),
                _tag('选择 $choiceCount', Colors.blue),
                const SizedBox(width: 8),
                _tag('判断 ${_bank.length - choiceCount}', Colors.teal),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: TextField(
              onChanged: (v) => setState(() => _keyword = v),
              decoration: InputDecoration(
                hintText: '搜索题干关键词',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: _keyword.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _keyword = ''),
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Text(_keyword.isNotEmpty ? '未找到匹配题目' : '题库为空'),
                  )
                : ListView.separated(
                    itemCount: _filtered.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, indent: 16),
                    itemBuilder: (context, i) {
                      final q = _filtered[i];
                      return _buildItem(theme, q);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _buildItem(ThemeData theme, Question q) {
    final color = q.isChoice ? Colors.blue : Colors.teal;
    final selected = _selected.contains(q.id);

    return ListTile(
      selected: selected,
      onTap: _selectionMode
          ? () => setState(() {
                if (selected) {
                  _selected.remove(q.id);
                } else {
                  _selected.add(q.id);
                }
              })
          : () => _editQuestion(q),
      onLongPress: _selectionMode ? null : () => _confirmDelete([q.id]),
      leading: _selectionMode
          ? Checkbox(
              value: selected,
              onChanged: (_) => setState(() {
                if (selected) {
                  _selected.remove(q.id);
                } else {
                  _selected.add(q.id);
                }
              }),
            )
          : CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              child: Text(
                q.isChoice ? '选' : '判',
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ),
      title: Text(
        q.stem,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        q.isChoice
            ? '选择题 · 答案 ${q.options[q.answer]}'
            : '判断题 · 答案 ${q.options[q.answer]}',
        style: theme.textTheme.bodySmall,
      ),
      trailing: _selectionMode
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.grey),
                  tooltip: '编辑',
                  onPressed: () => _editQuestion(q),
                ),
                if (_isImported(q))
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.grey),
                    onPressed: () => _confirmDelete([q.id]),
                  ),
              ],
            ),
    );
  }

}

/// 编辑题目对话框：可修改题干、选项与正确答案。
class _EditQuestionDialog extends StatefulWidget {
  final Question question;
  const _EditQuestionDialog({required this.question});

  @override
  State<_EditQuestionDialog> createState() => _EditQuestionDialogState();
}

class _EditQuestionDialogState extends State<_EditQuestionDialog> {
  late final TextEditingController _stemCtrl;
  late final List<TextEditingController> _optCtrls;
  late int _answer;

  bool get _isChoice => widget.question.isChoice;

  @override
  void initState() {
    super.initState();
    _stemCtrl = TextEditingController(text: widget.question.stem);
    _optCtrls = List.generate(
      widget.question.options.length,
      (i) => TextEditingController(text: widget.question.options[i]),
    );
    _answer = widget.question.answer;
  }

  @override
  void dispose() {
    _stemCtrl.dispose();
    for (final c in _optCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  void _save() {
    final stem = _stemCtrl.text.trim();
    if (stem.isEmpty) {
      _snack('题干不能为空');
      return;
    }
    final opts = _optCtrls.map((c) => c.text.trim()).toList();
    if (_isChoice && opts.any((o) => o.isEmpty)) {
      _snack('选项不能为空');
      return;
    }
    if (_isChoice) {
      Navigator.of(context)
          .pop(Question.choice(widget.question.id, stem, opts, _answer));
    } else {
      Navigator.of(context)
          .pop(Question.judge(widget.question.id, stem, _answer == 0));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isChoice ? '编辑选择题' : '编辑判断题'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _stemCtrl,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(
                labelText: '题干',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (_isChoice) ...[
              for (int i = 0; i < _optCtrls.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: _optCtrls[i],
                    decoration: InputDecoration(
                      labelText: '选项 ${'ABCD'[i]}',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              _answerWrap(_optCtrls.length),
            ] else
              _answerWrap(2),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _save, child: const Text('保存')),
      ],
    );
  }

  Widget _answerWrap(int count) {
    final labels = _isChoice
        ? List.generate(count, (i) => 'ABCD'[i])
        : const ['对', '错'];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 10),
          child: Text('正确答案：'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Wrap(
            spacing: 8,
            children: [
              for (int i = 0; i < labels.length; i++)
                ChoiceChip(
                  label: Text(labels[i]),
                  selected: _answer == i,
                  onSelected: (_) => setState(() => _answer = i),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 回收站：展示被删除的内置题，支持单个/全部恢复。
class _TrashSheet extends StatefulWidget {
  final List<Question> questions;
  const _TrashSheet({required this.questions});

  @override
  State<_TrashSheet> createState() => _TrashSheetState();
}

class _TrashSheetState extends State<_TrashSheet> {
  final StorageService _storage = StorageService.instance;

  Future<void> _restore(List<int> ids) async {
    await _storage.restoreBuiltin(ids);
    if (!mounted) return;
    if (_storage.deletedBuiltinIds.isEmpty) {
      Navigator.of(context).pop();
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deleted = _storage.deletedBuiltinIds;
    final questions =
        widget.questions.where((q) => deleted.contains(q.id)).toList();

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
            child: Row(
              children: [
                Text('已删除的题目（${questions.length}）',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                if (questions.isNotEmpty)
                  TextButton(
                    onPressed: () =>
                        _restore(questions.map((q) => q.id).toList()),
                    child: const Text('全部恢复'),
                  ),
              ],
            ),
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: questions.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 20),
              itemBuilder: (context, i) {
                final q = questions[i];
                return ListTile(
                  dense: true,
                  title: Text(
                    q.stem,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    q.isChoice ? '选择题' : '判断题',
                    style: theme.textTheme.bodySmall,
                  ),
                  trailing: TextButton(
                    onPressed: () => _restore([q.id]),
                    child: const Text('恢复'),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
