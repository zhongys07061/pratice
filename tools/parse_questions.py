# -*- coding: utf-8 -*-
"""解析《网络基础》选择题 PDF，输出 JSON（改进版）"""
import re
import json
import pypdf

PDF = r'C:\Users\18249\Desktop\新建文件夹 (2)\网络基础（选择题500题）.pdf'
OUT = r'C:\Users\18249\Desktop\questions_choice.json'

FULL = {'Ａ': 'A', 'Ｂ': 'B', 'Ｃ': 'C', 'Ｄ': 'D'}
QN_SEP = '[、．.．]'
OPT_SEP = '[、．.．)]'
QN_RE = re.compile(r'^\s*(\d+)\s*' + QN_SEP + r'\s*(.*)$')
OPT_RE = re.compile(r'^\s*([A-Da-dＡ-Ｄ])\s*' + OPT_SEP + r'\s*(.*)$')
# 选项标记：字母 + 分隔符(顿号/点/空格/右括号) —— 用于拆分同一行多个选项
OPT_SPLIT = re.compile(r'(?=[A-Da-dＡ-Ｄ]\s*' + OPT_SEP + r')')
# 答案：括号 / 下划线(任意数量) / 冒号问号+字母 / 空格+字母+句号
ANS_BRACKET = re.compile(r'[（(]\s*([A-Da-dＡ-Ｄ])\s*[)）]')
ANS_UNDER = re.compile(r'_+\s*([A-Da-dＡ-Ｄ])\s*_+')
ANS_TAIL1 = re.compile(r'[：:?？]\s*([A-Da-dＡ-Ｄ])\s*[。.．]?\s*$')
ANS_TAIL2 = re.compile(r'\s([A-Da-dＡ-Ｄ])\s*[。.．]\s*$')


def to_half(ch):
    return FULL.get(ch.upper(), ch.upper())


def is_noise(line):
    s = line.strip()
    if not s:
        return True
    if s.startswith('内部资料') or '请勿外传' in s:
        return True
    if s.startswith('网络基础') and '题' in s:
        return True
    if re.fullmatch(r'—\s*\d+\s*—', s):
        return True
    return False


def extract_answer(stem):
    ans = None
    for m in ANS_BRACKET.finditer(stem):
        ans = to_half(m.group(1))
    for m in ANS_UNDER.finditer(stem):
        ans = to_half(m.group(1))
    m = ANS_TAIL1.search(stem)
    if m:
        ans = to_half(m.group(1))
    m = ANS_TAIL2.search(stem)
    if m:
        ans = to_half(m.group(1))
    return ans


def clean_stem(stem):
    s = ANS_BRACKET.sub('（ ）', stem)
    s = ANS_UNDER.sub('____', s)
    s = ANS_TAIL1.sub('____', s)
    s = ANS_TAIL2.sub(' ____', s)
    s = re.sub(r'\s+', ' ', s).strip()
    return s


def parse(text):
    questions = []
    cur = None
    state = 'none'
    for raw in text.splitlines():
        line = raw.strip()
        if is_noise(line):
            continue
        m = QN_RE.match(line)
        if m:
            if cur is not None:
                questions.append(cur)
            cur = {'no': int(m.group(1)), 'stem': m.group(2), 'opt_lines': []}
            state = 'stem'
            continue
        m = OPT_RE.match(line)
        if m and cur is not None:
            cur['opt_lines'].append(line)
            state = 'options'
            continue
        if cur is None:
            continue
        if state == 'options':
            if cur['opt_lines']:
                cur['opt_lines'][-1] += line
            else:
                cur['stem'] += line
        else:
            cur['stem'] += line
    if cur is not None:
        questions.append(cur)
    return questions


def parse_option_text(opt_text):
    """从选项文本按 A-D 标记拆出四个选项"""
    merged = {}
    for seg in OPT_SPLIT.split(opt_text):
        seg = seg.strip()
        if not seg:
            continue
        m = OPT_RE.match(seg)
        if not m:
            continue
        k = to_half(m.group(1))
        v = m.group(2).strip()
        merged[k] = (merged.get(k, '') + v).strip()
    return [merged.get(k, '') for k in ['A', 'B', 'C', 'D']]


def finalize(qs):
    out = []
    for q in qs:
        raw_stem = q['stem']
        ans = extract_answer(raw_stem)
        stem = clean_stem(raw_stem)

        if q['opt_lines']:
            opts = parse_option_text(''.join(q['opt_lines']))
        else:
            # 选项与题干同行：在答案标记之后拆分
            tail = stem
            m = re.search(r'（\s*）', stem)
            if m:
                tail = stem[m.end():]
            else:
                m = re.search(r'_{2,}', stem)
                if m:
                    tail = stem[m.end():]
            opts = parse_option_text(tail)
            if not any(opts):
                opts = parse_option_text(stem)

        out.append({'no': q['no'], 'stem': stem, 'options': opts, 'answer': ans})
    return out


# 手动修正：PDF 排版缺陷导致的 7 道题（关键词 -> 修正后的完整题目）
FIXES = {
    '所有的计算机均连接到一条通信传输线路': {
        'stem': '在计算机网络中，所有的计算机均连接到一条通信传输线路上，在线路两端连有防止信号反射的装置，这种连接结构被称为',
        'options': ['总线结构', '星型结构', '环型结构', '网状结构'],
        'answer': 'A'},
    'http 是一种': {
        'stem': 'http 是一种',
        'options': ['域名', '高级语言', '服务器名称', '超文本传输协议'],
        'answer': 'D'},
    '每次可传输信号的设备数目': {
        'stem': '在总线型拓扑结构网络中，每次可传输信号的设备数目为',
        'options': ['一个', '三个', '两个', '任意多个'],
        'answer': 'A'},
    '以提高传输距离': {
        'stem': '模拟信号采用模拟传输时采用下列哪种设备以提高传输距离',
        'options': ['中继器', '放大器', '调制解调器', '编码译码器'],
        'answer': 'B'},
    '数据在传输中产生差错': {
        'stem': '数据在传输中产生差错的重要原因',
        'options': ['热噪声', '冲击噪声', '串扰', '环境恶劣'],
        'answer': 'B'},
    '帧中继中的路由和交换': {
        'stem': '帧中继中的路由和交换是由层来实现的',
        'options': ['物理', '数据链路', '网络', 'B 和 C'],
        'answer': 'B'},
    '用集线器连接的一组工作站': {
        'stem': '组建局域网可以用集线器，也可以用交换机。用集线器连接的一组工作站',
        'options': ['同属一个冲突域，但不属于一个广播域', '同属一个冲突域，也属于一个广播域',
                    '不属于一个冲突域，但属于一个广播域', '不属于一个冲突域，也不属于一个广播域'],
        'answer': 'B'},
    '中心结点出现故障': {
        'stem': '中心结点出现故障造成全网瘫痪的网络是',
        'options': ['总线', '星型', '树型', '球型'],
        'answer': 'B'},
    '以太网卡的地址是': {
        'stem': '以太网卡的地址是位',
        'options': ['16', '32', '48', '64'],
        'answer': 'C'},
    '决定使用哪条路径': {
        'stem': '决定使用哪条路径通过子网，应属于下列 OSI 的',
        'options': ['物理层', '数据链路层', '网络层', '运输层'],
        'answer': 'C'},
    '是 TCP/IP 的应用层协议': {
        'stem': '在下列给出的协议中，是 TCP/IP 的应用层协议',
        'options': ['TCP', 'ARP', 'FTP', 'RARP'],
        'answer': 'C'},
    'UDP 协议工作': {
        'stem': '在 TCP/IP 协议簇中，UDP 协议工作在',
        'options': ['应用层', '传输层', '网络互联层', '网络接口层'],
        'answer': 'B'},
    '数据单元被称为帧': {
        'stem': '在哪一层中，数据单元被称为帧',
        'options': ['物理', '数据链路', '网络', '传输'],
        'answer': 'B'},
    '和传输媒体最接近的层': {
        'stem': '哪一层是和传输媒体最接近的层',
        'options': ['物理', '数据链路', '网络', '传输'],
        'answer': 'A'},
    '规定了接口的机械、电气': {
        'stem': 'OSI 的哪一层规定了接口的机械、电气、功能和规程特性',
        'options': ['物理', '数据链路', '网络', '传输'],
        'answer': 'A'},
}


def apply_fixes(qs):
    fixed = 0
    for q in qs:
        for key, val in FIXES.items():
            if key in q['stem']:
                q['stem'] = val['stem']
                q['options'] = val['options']
                q['answer'] = val['answer']
                fixed += 1
                break
    return fixed


def main():
    reader = pypdf.PdfReader(PDF)
    full = '\n'.join(p.extract_text() for p in reader.pages)
    qs = finalize(parse(full))
    fixed = apply_fixes(qs)

    with open(OUT, 'w', encoding='utf-8') as f:
        json.dump(qs, f, ensure_ascii=False, indent=1)

    print('总题数:', len(qs))
    print('手动修正:', fixed)
    miss_ans = [q for q in qs if q['answer'] is None]
    miss_opt = [q for q in qs if any(not o for o in q['options'])]
    print('答案缺失:', len(miss_ans))
    print('选项不完整:', len(miss_opt))
    print('--- 答案缺失 ---')
    for q in miss_ans:
        print(' idx', qs.index(q), 'no', q['no'], '|', q['stem'][:60])
    print('--- 选项不完整 ---')
    for q in miss_opt:
        print(' idx', qs.index(q), 'no', q['no'], '|', q['stem'][:45], '|', q['options'])


if __name__ == '__main__':
    main()
