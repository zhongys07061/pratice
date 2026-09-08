# -*- coding: utf-8 -*-
"""抽查核对：解析结果 vs 原始 PDF/doc"""
import re
import json
import random
import pypdf

CHOICE = r'C:\Users\18249\Desktop\questions_choice.json'
JUDGE = r'C:\Users\18249\Desktop\questions_judge.json'
PDF = r'C:\Users\18249\Desktop\新建文件夹 (2)\网络基础（选择题500题）.pdf'
DOC = r'C:\Users\18249\Desktop\新建文件夹 (2)\2-《网络基础》判断题复习资料.doc'

reader = pypdf.PdfReader(PDF)
pdf_full = '\n'.join(p.extract_text() for p in reader.pages)
pdf_lines = pdf_full.splitlines()

doc_txt = open(DOC, 'rb').read().decode('utf-16-le', 'ignore')
doc_lines = [l for l in doc_txt.split('\r') if l.strip()]

choices = json.load(open(CHOICE, encoding='utf-8'))
judges = json.load(open(JUDGE, encoding='utf-8'))

ANS = {0: 'A', 1: 'B', 2: 'C', 3: 'D'}


def locate_choice(stem):
    """在 PDF 原文里找题干关键词对应的行"""
    key = stem[:12]
    for i, l in enumerate(pdf_lines):
        if key in l:
            return i
    return None


def locate_judge(stem):
    key = stem[:10]
    for i, l in enumerate(doc_lines):
        if key in l:
            return i
    return None


random.seed(42)
print('########## 选择题抽查（25 题）##########')
for q in random.sample(choices, 25):
    ans = q['answer']
    i = locate_choice(q['stem'])
    ctx = ' | '.join(repr(pdf_lines[i + j]) for j in range(0, 2)) if i is not None else '?? 未定位'
    print(f"[{q['no']}] 答案={ans}")
    print(f"  题干: {q['stem'][:50]}")
    print(f"  选项: {q['options']}")
    print(f"  原文: {ctx[:150]}")
    print()

print()
print('########## 判断题抽查（15 题）##########')
for q in random.sample(judges, 15):
    i = locate_judge(q['stem'])
    ctx = repr(doc_lines[i]) if i is not None else '?? 未定位'
    print(f"答案={'对' if q['answer'] else '错'} | 题干: {q['stem'][:50]}")
    print(f"  原文: {ctx[:150]}")
    print()
