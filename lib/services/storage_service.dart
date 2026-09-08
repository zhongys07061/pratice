import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/question_bank.dart';
import '../models/question.dart';

/// 本地存储服务（单例）
/// 负责保存：答题统计、错题本、顺序练习进度、导入的题库。
class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  static const _kAnswered = 'answered';            // 累计答题数
  static const _kCorrect = 'correct';              // 累计正确数
  static const _kWrongIds = 'wrong_ids';           // 错题 id 列表
  static const _kOrderProgress = 'order_progress'; // 顺序练习进度（下次要练的题索引）
  static const _kImported = 'imported_questions';  // 导入题库（JSON 字符串）
  static const _kDeletedBuiltin = 'deleted_builtin_ids'; // 被删除的内置题 id
  static const _kEdited = 'edited_questions';      // 被编辑的内置题（JSON map: id -> question）

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  int get answered => _prefs?.getInt(_kAnswered) ?? 0;
  int get correct => _prefs?.getInt(_kCorrect) ?? 0;
  int get wrongCount => wrongIds.length;

  List<int> get wrongIds {
    final raw = _prefs?.getStringList(_kWrongIds) ?? const [];
    return raw.map((e) => int.tryParse(e) ?? -1).where((e) => e >= 0).toList();
  }

  /// 记录一次作答。
  /// [questionId] 题目 id，[isCorrect] 是否答对。
  Future<void> recordAnswer(int questionId, bool isCorrect) async {
    final p = _prefs;
    if (p == null) return;

    await p.setInt(_kAnswered, answered + 1);
    if (isCorrect) {
      await p.setInt(_kCorrect, correct + 1);
      // 答对：若此题在错题本中，则移除
      final ids = wrongIds;
      if (ids.contains(questionId)) {
        ids.remove(questionId);
        await p.setStringList(_kWrongIds, ids.map((e) => e.toString()).toList());
      }
    } else {
      // 答错：加入错题本（去重）
      final ids = wrongIds;
      if (!ids.contains(questionId)) {
        ids.add(questionId);
        await p.setStringList(_kWrongIds, ids.map((e) => e.toString()).toList());
      }
    }
  }

  /// 重置统计、错题本与顺序练习进度
  Future<void> reset() async {
    final p = _prefs;
    if (p == null) return;
    await p.remove(_kAnswered);
    await p.remove(_kCorrect);
    await p.remove(_kWrongIds);
    await p.remove(_kOrderProgress);
  }

  /// 顺序练习进度（下次要练的题索引，0 表示从头开始）
  int get orderProgress => _prefs?.getInt(_kOrderProgress) ?? 0;

  Future<void> setOrderProgress(int value) async {
    await _prefs?.setInt(_kOrderProgress, value);
  }

  /// 导入的题库
  List<Question> get importedQuestions {
    final raw = _prefs?.getString(_kImported);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => Question.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addImportedQuestions(List<Question> questions) async {
    final all = importedQuestions;
    all.addAll(questions);
    final encoded = jsonEncode(all.map((e) => e.toJson()).toList());
    await _prefs?.setString(_kImported, encoded);
  }

  Future<void> clearImported() async {
    await _prefs?.remove(_kImported);
  }

  /// 被删除（隐藏）的内置题 id 集合
  Set<int> get deletedBuiltinIds {
    final raw = _prefs?.getStringList(_kDeletedBuiltin) ?? const [];
    return raw.map((e) => int.tryParse(e) ?? -1).where((e) => e >= 0).toSet();
  }

  /// 删除内置题（逻辑删除，记录 id）
  Future<void> deleteBuiltin(List<int> ids) async {
    final all = deletedBuiltinIds..addAll(ids);
    await _prefs?.setStringList(
        _kDeletedBuiltin, all.map((e) => e.toString()).toList());
  }

  /// 恢复内置题
  Future<void> restoreBuiltin(List<int> ids) async {
    final all = deletedBuiltinIds..removeAll(ids);
    await _prefs?.setStringList(
        _kDeletedBuiltin, all.map((e) => e.toString()).toList());
  }

  /// 删除导入题（按 id）
  Future<void> removeImportedQuestions(List<int> ids) async {
    final all = importedQuestions.where((q) => !ids.contains(q.id)).toList();
    final encoded = jsonEncode(all.map((e) => e.toJson()).toList());
    await _prefs?.setString(_kImported, encoded);
  }

  /// 添加单道题（追加到导入题库）
  Future<void> addQuestion(Question question) async {
    await addImportedQuestions([question]);
  }

  /// 被编辑过的内置题（id -> 覆盖后的题目）
  Map<int, Question> get editedQuestions {
    final raw = _prefs?.getString(_kEdited);
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) =>
          MapEntry(int.parse(k), Question.fromJson(v as Map<String, dynamic>)));
    } catch (_) {
      return {};
    }
  }

  /// 保存对一道题的编辑：内置题写入覆盖记录，导入题直接更新列表。
  Future<void> updateQuestion(Question question) async {
    if (question.id >= 100000) {
      final all = importedQuestions;
      final idx = all.indexWhere((e) => e.id == question.id);
      if (idx >= 0) {
        all[idx] = question;
        await _prefs?.setString(
            _kImported, jsonEncode(all.map((e) => e.toJson()).toList()));
      }
      return;
    }
    final edits = editedQuestions;
    edits[question.id] = question;
    await _prefs?.setString(
        _kEdited,
        jsonEncode(
            edits.map((k, v) => MapEntry(k.toString(), v.toJson()))));
  }

  /// 撤销对某道内置题的编辑，恢复原始内容。
  Future<void> resetEditedQuestion(int id) async {
    final edits = editedQuestions..remove(id);
    await _prefs?.setString(
        _kEdited,
        jsonEncode(
            edits.map((k, v) => MapEntry(k.toString(), v.toJson()))));
  }

  /// 当前有效题库 = 内置题库（过滤已删除并应用编辑覆盖） + 导入题库
  List<Question> effectiveBank() {
    final deleted = deletedBuiltinIds;
    final edits = editedQuestions;
    return [
      ...buildQuestionBank()
          .where((q) => !deleted.contains(q.id))
          .map((q) => edits[q.id] ?? q),
      ...importedQuestions,
    ];
  }
}
