import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart';

import '../models/question.dart';

/// 题库导入解析器：提取 txt/docx/pdf 文本并解析成题目。
class ImportParser {
  /// 按文件扩展名提取纯文本
  static String extractText(String fileName, Uint8List bytes) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'docx':
        return _extractDocx(bytes);
      case 'pdf':
        return _extractPdf(bytes);
      case 'txt':
      case 'text':
      default:
        return utf8.decode(bytes, allowMalformed: true);
    }
  }

  static String _extractDocx(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final file = archive.findFile('word/document.xml');
      if (file == null) return '';
      final doc = XmlDocument.parse(utf8.decode(file.content));
      final lines = doc.findAllElements('w:p').map((p) {
        return p.findAllElements('w:t').map((t) => t.innerText).join();
      }).toList();
      return lines.join('\n');
    } catch (_) {
      return '';
    }
  }

  static String _extractPdf(Uint8List bytes) {
    try {
      final document = PdfDocument(inputBytes: bytes);
      final text = PdfTextExtractor(document).extractText();
      document.dispose();
      return text;
    } catch (_) {
      return '';
    }
  }

  /// 解析文本为题目列表。依次尝试：结构化格式、常见题库格式、聊天记录格式。
  static List<Question> parse(String text, int startId) {
    final structured = _parseStructured(text, startId);
    if (structured.isNotEmpty) return structured;
    final common = _parseCommon(text, startId);
    if (common.isNotEmpty) return common;
    return _parseChat(text, startId);
  }

  /// 结构化格式：每行一题，用 ||| 分隔
  ///   选择题：题干|||A|||B|||C|||D|||答案(A/B/C/D)
  ///   判断题：题干|||对（或 错）
  static List<Question> _parseStructured(String text, int startId) {
    final questions = <Question>[];
    int id = startId;
    for (final raw in text.split(RegExp(r'\r?\n'))) {
      final s = raw.trim();
      if (s.isEmpty) continue;
      final parts = s.split('|||');
      if (parts.length == 2) {
        final stem = parts[0].trim();
        final ans = parts[1].trim();
        if (ans == '对' || ans == '√') {
          questions.add(Question.judge(id++, stem, true));
        } else if (ans == '错' || ans == '×') {
          questions.add(Question.judge(id++, stem, false));
        }
      } else if (parts.length == 6) {
        final stem = parts[0].trim();
        final opts = [
          parts[1].trim(),
          parts[2].trim(),
          parts[3].trim(),
          parts[4].trim(),
        ];
        final idx = 'ABCD'.indexOf(parts[5].trim().toUpperCase());
        if (idx >= 0 && opts.every((o) => o.isNotEmpty)) {
          questions.add(Question.choice(id++, stem, opts, idx));
        }
      }
    }
    return questions;
  }

  /// 常见题库格式：题干含答案（括号/下划线）+ A/B/C/D 选项；或（√/×）判断题
  static List<Question> _parseCommon(String text, int startId) {
    final questions = <Question>[];
    final lines = text.split(RegExp(r'\r?\n'));
    const full = {'Ａ': 'A', 'Ｂ': 'B', 'Ｃ': 'C', 'Ｄ': 'D'};

    final qnRe = RegExp(r'^\s*(\d+)\s*[、．.]\s*(.*)$');
    final optRe = RegExp(r'^\s*([A-Da-dＡ-Ｄ])\s*[、．.．)]\s*(.*)$');
    final optSplit = RegExp(r'(?=[A-Da-dＡ-Ｄ]\s*[、．.．)])');
    final ansBracket = RegExp(r'[（(]\s*([A-Da-dＡ-Ｄ])\s*[)）]');
    final ansUnder = RegExp(r'_+\s*([A-Da-dＡ-Ｄ])\s*_+');
    final judgeRe = RegExp(r'[（(]\s*([√×])\s*[)）]\s*(.+)');
    final ansLine = RegExp(r'(?:正确|参考)?答案\s*[:：]?\s*([A-Da-dＡ-Ｄ])');

    String toHalf(String ch) => full[ch.toUpperCase()] ?? ch.toUpperCase();

    String extractAns(String stem) {
      String? ans;
      for (final m in ansBracket.allMatches(stem)) {
        ans = toHalf(m.group(1)!);
      }
      for (final m in ansUnder.allMatches(stem)) {
        ans = toHalf(m.group(1)!);
      }
      return ans ?? '';
    }

    int id = startId;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      // 判断题
      final jm = judgeRe.firstMatch(line);
      if (jm != null) {
        final stem = jm.group(2)!.trim();
        if (stem.isNotEmpty) {
          questions.add(Question.judge(id++, stem, jm.group(1) == '√'));
        }
        continue;
      }

      // 选择题：题号行
      final qm = qnRe.firstMatch(line);
      if (qm == null) continue;

      var stem = qm.group(2)!;
      final optLines = <String>[];

      int j = i + 1;
      String? lineAns;
      while (j < lines.length) {
        final nl = lines[j].trim();
        if (nl.isEmpty) {
          j++;
          continue;
        }
        if (qnRe.hasMatch(nl) || judgeRe.hasMatch(nl)) break;
        final am = ansLine.firstMatch(nl);
        if (am != null) {
          lineAns = toHalf(am.group(1)!);
          j++;
          break;
        }
        final om = optRe.firstMatch(nl);
        if (om != null) {
          optLines.add(nl);
        } else {
          if (optLines.isNotEmpty) {
            optLines[optLines.length - 1] += nl;
          } else {
            stem += nl;
          }
        }
        j++;
      }
      i = j - 1;

      final ans =
          extractAns(stem).isNotEmpty ? extractAns(stem) : (lineAns ?? '');
      var cleanStem = stem
          .replaceAll(ansBracket, '（ ）')
          .replaceAll(ansUnder, '____')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      final merged = <String, String>{};
      final optText = optLines.join();
      for (final seg in optText.split(optSplit)) {
        final s = seg.trim();
        if (s.isEmpty) continue;
        final m = optRe.firstMatch(s);
        if (m == null) continue;
        final k = toHalf(m.group(1)!);
        merged[k] = ((merged[k] ?? '') + m.group(2)!.trim()).trim();
      }
      final opts = ['A', 'B', 'C', 'D'].map((k) => merged[k] ?? '').toList();

      final ansIdx = 'ABCD'.indexOf(ans);
      if (ansIdx >= 0 && opts.every((o) => o.isNotEmpty)) {
        questions.add(Question.choice(id++, cleanStem, opts, ansIdx));
      }
    }

    return questions;
  }

  /// 聊天记录格式：题干（可能无编号） + 选项 + 「答案：X」；或判断题 + 「答案：对/错/√/×」。
  /// 自动忽略常见的发送者前缀（如「小明：」）。
  static List<Question> _parseChat(String text, int startId) {
    final questions = <Question>[];
    final lines = text.split(RegExp(r'\r?\n'));
    const full = {'Ａ': 'A', 'Ｂ': 'B', 'Ｃ': 'C', 'Ｄ': 'D'};

    String toHalf(String ch) => full[ch.toUpperCase()] ?? ch.toUpperCase();

    final optRe = RegExp(r'^\s*([A-Da-dＡ-Ｄ])\s*[、．.．)\s:：]+(.*)$');
    final ansRe = RegExp(r'(?:正确|参考)?答案\s*[:：]?\s*([A-Da-dＡ-Ｄ√×对错])');
    final stemRe = RegExp(r'^\s*\d+\s*[、．.]|[\?？]|[（(]\s*[)）]');

    // 去掉发送者前缀（如「小明：」），但保留「答案：」等关键词行。
    String stripSender(String line) {
      final m = RegExp(r'^\s*([^：:\s]{1,20})[：:]\s*(.*)$').firstMatch(line);
      if (m == null) return line;
      final head = m.group(1)!;
      if (RegExp(r'答案|题目|正确|错误|选择|判断|单选|多选|选项|解析').hasMatch(head)) {
        return line;
      }
      return m.group(2)!;
    }

    bool looksLikeStem(String s) => stemRe.hasMatch(s);

    int id = startId;
    int i = 0;
    while (i < lines.length) {
      final line = stripSender(lines[i]).trim();
      i++;
      if (line.isEmpty) continue;
      if (optRe.hasMatch(line)) continue; // 孤立的选项行
      if (ansRe.hasMatch(line)) continue; // 孤立的答案行

      var stem = line;
      final opts = <String>[];
      String? ans;

      int j = i;
      while (j < lines.length) {
        final raw = stripSender(lines[j]).trim();
        if (raw.isEmpty) {
          j++;
          continue;
        }
        final am = ansRe.firstMatch(raw);
        if (am != null) {
          ans = toHalf(am.group(1)!);
          j++;
          break;
        }
        final om = optRe.firstMatch(raw);
        if (om != null) {
          opts.add(om.group(2)!.trim());
          j++;
          continue;
        }
        if (looksLikeStem(raw)) break; // 新题干
        if (opts.isNotEmpty) {
          opts[opts.length - 1] += raw;
        } else {
          stem += raw;
        }
        j++;
      }
      i = j;

      if (ans == null) continue;

      final ansUp = toHalf(ans);
      final isTrue = ansUp == 'A' || ansUp == '对' || ansUp == '√';
      final isFalse = ansUp == 'B' || ansUp == '错' || ansUp == '×';

      if (opts.length == 2 &&
          opts[0] == '对' &&
          opts[1] == '错' &&
          (isTrue || isFalse)) {
        questions.add(Question.judge(id++, stem, isTrue));
      } else if (opts.isNotEmpty) {
        final idx = 'ABCD'.indexOf(ansUp);
        if (idx >= 0 && idx < opts.length) {
          questions.add(Question.choice(id++, stem, opts, idx));
        }
      } else if (isTrue || isFalse) {
        questions.add(Question.judge(id++, stem, isTrue));
      }
    }

    return questions;
  }
}
