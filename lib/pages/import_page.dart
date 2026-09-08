import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/question.dart';
import '../services/import_parser.dart';
import '../services/storage_service.dart';

/// 题库导入页：文件导入（txt/docx/pdf）或粘贴文本（聊天记录等）。
class ImportPage extends StatefulWidget {
  const ImportPage({super.key});

  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  final StorageService _storage = StorageService.instance;

  String _mode = 'file'; // file / paste
  String? _fileName;
  List<Question>? _questions;
  final TextEditingController _pasteController = TextEditingController();

  Future<void> _pickFile() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['txt', 'text', 'csv', 'docx', 'pdf'],
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();
    final content = ImportParser.extractText(file.name, bytes);
    _applyResult(file.name, ImportParser.parse(content, _nextStartId()));
  }

  void _parsePaste() {
    final text = _pasteController.text;
    if (text.trim().isEmpty) {
      _show('请先粘贴题目文本');
      return;
    }
    _applyResult('粘贴文本', ImportParser.parse(text, _nextStartId()));
  }

  void _applyResult(String name, List<Question> questions) {
    setState(() {
      _fileName = name;
      _questions = questions;
    });
    if (questions.isEmpty) {
      _show('未能解析出题目，请检查内容格式');
    }
  }

  int _nextStartId() {
    final imported = _storage.importedQuestions;
    if (imported.isEmpty) return 100000;
    return imported.map((q) => q.id).reduce((a, b) => a > b ? a : b) + 1;
  }

  Future<void> _doImport() async {
    final qs = _questions;
    if (qs == null || qs.isEmpty) {
      _show('没有可导入的题目');
      return;
    }
    await _storage.addImportedQuestions(qs);
    if (mounted) {
      _show('成功导入 ${qs.length} 道题');
      Navigator.of(context).pop(true);
    }
  }

  void _show(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final qs = _questions;

    return Scaffold(
      appBar: AppBar(title: const Text('导入题库')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'file', label: Text('文件导入')),
              ButtonSegment(value: 'paste', label: Text('粘贴文本')),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          const SizedBox(height: 16),
          _formatHint(theme),
          const SizedBox(height: 16),
          if (_mode == 'file') ...[
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                icon: const Icon(Icons.upload_file),
                label: const Text('选择文件（txt / docx / pdf）'),
                onPressed: _pickFile,
              ),
            ),
          ] else ...[
            TextField(
              controller: _pasteController,
              maxLines: 10,
              decoration: const InputDecoration(
                hintText: '把题目文本粘贴到这里（支持聊天记录、文档复制的内容）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                icon: const Icon(Icons.content_paste),
                label: const Text('解析文本'),
                onPressed: _parsePaste,
              ),
            ),
          ],
          if (_fileName != null) ...[
            const SizedBox(height: 16),
            _resultCard(theme, qs!),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: qs.isEmpty ? null : _doImport,
                child: Text(qs.isEmpty ? '无有效题目' : '导入 ${qs.length} 道题'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _formatHint(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('支持文件：txt、docx、pdf，或直接粘贴文本',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 10),
          const Text('两种题目格式都能识别：', style: TextStyle(fontSize: 13)),
          const SizedBox(height: 6),
          const Text('① 分隔格式（每行一题，用 ||| 分隔）',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          const Text('   选择题：题干|||A|||B|||C|||D|||答案', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const Text('   判断题：题干|||对（或 错）', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 6),
          const Text('② 常见题库格式（自动识别题干、选项、答案）',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          const Text('   选择题：1、题干（A）  +  A、… B、… C、… D、…', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const Text('   判断题：（√）题干 或 （×）题干', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _resultCard(ThemeData theme, List<Question> qs) {
    final choice = qs.where((q) => q.isChoice).length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EAF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('来源：$_fileName',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              _countBadge('共 ${qs.length} 题', theme.colorScheme.primary),
              const SizedBox(width: 8),
              _countBadge('选择 $choice', Colors.blue),
              const SizedBox(width: 8),
              _countBadge('判断 ${qs.length - choice}', Colors.teal),
            ],
          ),
        ],
      ),
    );
  }

  Widget _countBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
    );
  }
}
