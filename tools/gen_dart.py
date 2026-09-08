# -*- coding: utf-8 -*-
"""将选择题 + 判断题 JSON 生成 Dart 题库文件"""
import json

CHOICE = r'C:\Users\18249\Desktop\questions_choice.json'
JUDGE = r'C:\Users\18249\Desktop\questions_judge.json'
OUT = r'C:\Users\18249\Desktop\quiz_app\lib\data\question_bank.dart'

ANS = {'A': 0, 'B': 1, 'C': 2, 'D': 3}


def dart_str(s):
    s = s.replace('\\', '\\\\').replace('"', '\\"')
    s = ' '.join(s.split())  # 合并空白，去掉换行
    return s


def main():
    choices = json.load(open(CHOICE, encoding='utf-8'))
    judges = json.load(open(JUDGE, encoding='utf-8'))

    lines = []
    lines.append("import '../models/question.dart';")
    lines.append('')
    lines.append('/// 内置题库：《网络基础》选择题 + 判断题（自动生成）')
    lines.append('List<Question> buildQuestionBank() {')
    lines.append('  return [')

    idx = 1
    for q in choices:
        stem = dart_str(q['stem'])
        opts = [dart_str(o) for o in q['options']]
        ans = ANS.get(q['answer'], 0)
        lines.append(
            f'    Question.choice({idx}, "{stem}", {opts}, {ans}),'
        )
        idx += 1

    for q in judges:
        stem = dart_str(q['stem'])
        ans = 'true' if q['answer'] else 'false'
        lines.append(f'    Question.judge({idx}, "{stem}", {ans}),')
        idx += 1

    lines.append('  ];')
    lines.append('}')
    lines.append('')

    content = '\n'.join(lines)
    with open(OUT, 'w', encoding='utf-8') as f:
        f.write(content)

    print('选择题:', len(choices))
    print('判断题:', len(judges))
    print('总计:', idx - 1)
    print('已写入:', OUT)


if __name__ == '__main__':
    main()
