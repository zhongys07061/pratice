/// 题目类型：选择题 / 判断题
enum QuestionType { choice, judge }

/// 一道题目
class Question {
  final int id;                 // 唯一编号（用于错题本关联，务必稳定唯一）
  final QuestionType type;      // 题型
  final String stem;            // 题干
  final List<String> options;   // 选项（判断题固定为 ['对', '错']）
  final int answer;             // 正确答案在 options 中的下标
  final String? explanation;    // 解析（可选）

  const Question({
    required this.id,
    required this.type,
    required this.stem,
    required this.options,
    required this.answer,
    this.explanation,
  });

  bool get isChoice => type == QuestionType.choice;

  /// 构造一道选择题
  factory Question.choice(
    int id,
    String stem,
    List<String> options,
    int answer, {
    String? explanation,
  }) {
    assert(answer >= 0 && answer < options.length, '答案下标越界');
    return Question(
      id: id,
      type: QuestionType.choice,
      stem: stem,
      options: options,
      answer: answer,
      explanation: explanation,
    );
  }

  /// 构造一道判断题（answer 传 true 表示“对”，false 表示“错”）
  factory Question.judge(
    int id,
    String stem,
    bool answer, {
    String? explanation,
  }) {
    return Question(
      id: id,
      type: QuestionType.judge,
      stem: stem,
      options: const ['对', '错'],
      answer: answer ? 0 : 1,
      explanation: explanation,
    );
  }

  /// 序列化（用于保存导入的题库）
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type == QuestionType.choice ? 'choice' : 'judge',
        'stem': stem,
        'options': options,
        'answer': answer,
        'explanation': explanation,
      };

  /// 反序列化
  factory Question.fromJson(Map<String, dynamic> json) => Question(
        id: json['id'] as int,
        type: json['type'] == 'choice' ? QuestionType.choice : QuestionType.judge,
        stem: json['stem'] as String,
        options: (json['options'] as List).map((e) => e.toString()).toList(),
        answer: json['answer'] as int,
        explanation: json['explanation'] as String?,
      );
}
