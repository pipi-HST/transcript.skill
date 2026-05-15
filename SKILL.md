---
name: transcript
description: 将语音转文字长文本提纯为整理稿（流畅阅读，信息无遗漏）+ 可选速览稿（结构化要点速查）。适用会议录音、访谈、演讲等长文本。
when_to_use: 用户提到整理访谈记录、会议纪要、语音转文字、调研笔录、长文本清洗、提纯全文等场景时自动触发。也支持 /transcript 手动调用。
allowed-tools: Bash(python3 *) Bash(bash *) Bash(cat *) Bash(mkdir *) Bash(wc *) Bash(ls *) Bash(sed *) Read Write
---

# 访谈记录整理提纯

## 交互原则

- 每步完成后输出一行进度状态
- 扫描→切分→全量并行，中间无需用户确认
- 默认只出整理稿，用户可追加速览稿
- 输出到输入文件所在目录下的 `整理产出/` 子目录

---

## 产出

| 产出 | 文件 | 操作 | 适用场景 |
|------|------|------|---------|
| **整理稿** | `整理稿.md` | 去噪+段落精炼+章节标题，信息零遗漏 | **默认产出** |
| **速览稿** | `速览稿.md` | 结构化速查：表格+要点+金句 | 5分钟了解全貌，可选 |

---

## 第零步：产出确认

```bash
python3 scripts/text_stats.py <输入文件>
```

```
📋 X 字，默认产出：整理稿

还需要速览稿吗？（直接 OK 只出整理稿）
  · "速览" — 追加结构化要点速查
```

**等待用户确认后继续。**

---

## 第一步：文件规范化

如果文件缺少换行（< 5 行且 > 1000 字）：

```bash
python3 -c "
import re
text = open('INPUT', 'r', encoding='utf-8').read()
lines = text.split('\n')
if len(lines) < 5 and len(text) > 1000:
    text = re.sub(r'([。！？!?])(?=\S)', r'\1\n', text)
    text = re.sub(r'(\n){3,}', r'\n\n', text)
    open('INPUT.normalized', 'w', encoding='utf-8').write(text)
    print(f'NORMALIZED=INPUT.normalized')
else:
    print(f'NORMALIZED=INPUT')
"
```

---

## 第二步：扫描切分

**NEEDS_SPLIT=false → 跳过，单 Agent 处理全文。**

启动扫描 Agent（**必须指定 Haiku 模型**，速度快），读全文找话题转折点。

**扫描 Agent Prompt（锁定，只能替换文件路径）：**

```
读取全文，找到话题的自然转折点，切成独立话题段。

输出格式（一行一段）：
START-END | 话题标题

规则：
- 每个话题段 4000-8000 字为宜，不超过 8000
- 超 8000 在句边界再切，标题加"（上/下）"
- 切在话题转换的自然断口，不截句中
- 不设段数上限，不需总结去噪
```

**扫描 Agent 返回后，执行切分：**

```bash
mkdir -p <输出目录>/clean
bash scripts/split_by_lines.sh <规范化文件> <输出目录>/chunks \
  "1-85|主持人开场与市场复盘" \
  "86-210|AI前沿Token稀缺（上）" \
  ...
```

每段 ±2 行自然重叠。主题名写入 `.meta` 文件。

**验证每个片段有效：**

```bash
for f in <chunks目录>/segment_*.txt; do
  [ $(wc -l < "$f") -lt 2 ] && echo "BLOCKED: $f" && exit 1
done
echo "OK: N segments"
```

---

## 第三步：全量并行处理

**所有 Agent 一次性全部启动，不限批次。单产出，极简 Prompt。**

### Agent Prompt（锁定，替换 {path}, {dir}, NN, {title}）

```
读片段文件，输出一个整理稿。

【去噪】
删：自我打断/口吃/填充词(嗯啊呃)/ASR错字
保：术语/数据/比喻/金句/结论/问答结构
每句能正常朗读。拿不准就留。

【整理】
合并相邻重复论述，优化段落衔接。
以 "## {title}" 开头，用 Markdown 分段。
结构有层次但不改动叙事逻辑。

【示例1：独白】
原文：
"这个这个AI呢，我觉得吧就是说，它今年确实爆发了。
嗯然后呢，就是那个，AI今年确实是爆发式的增长。"

整理稿：
AI今年确实爆发式增长。

【示例2：问答】
原文：
"那老师你怎么看这个存储？
嗯，我觉得存储这个事儿啊，存储现在是非常紧缺的。
为什么呢？因为产能不够嘛。"

整理稿：
怎么看存储？存储现在非常紧缺——核心原因是产能不够。

【示例3：拿不准就留】
原文："Mesos大概两三个月就从4.6迭代出来了。"
Mesos可能是专名转写错误，但不确定→保留Mesos，不做猜测替换。

写入 {dir}/clean_NN.md。回复只返回 JSON。
```

### 编排

**NEEDS_SPLIT=false**：单 Agent 处理全文，{title} 用文件主题。

**NEEDS_SPLIT=true**：
1. 所有 Agent 一次性全部并行启动（不限批，不限并发数）
2. 全部完成后检查完整性：

```bash
EXPECTED=N
ACTUAL=$(ls {dir}/clean_*.md 2>/dev/null | wc -l)
# 若有缺失，只重跑缺失片段
```

---

## 第四步：拼接 + 可选速览

```bash
cat {dir}/clean_*.md > 整理稿.md
```

**速览 Agent（仅用户选了速览时启动）：**

```
读整理稿全文，写速览稿。

目标：让读者快速了解全貌。精炼程度与原文长度成正比——
长文提炼更浓缩，短文保留更多细节。
格式由你根据内容特点自行组织。
所有议题必须覆盖，数据和术语必须与整理稿一致。不要叙事。

写入 速览稿.md，回复 JSON。
```

---

## 第五步：完成报告

```
✅ 处理完成

| 项目 | 内容 |
|------|------|
| 输入文件 | /path/to/文件 |
| 原始文本 | X 字 |
| 段数 | N 段 |
| 整理稿 | Z 字 |
| 速览稿 | W 字（如选择） |
| 耗时 | ~X 分钟 |

📂 /输出目录/整理稿.md /速览稿.md
```

---

## 短文本快速通道

`NEEDS_SPLIT=false`：跳过扫描切分，单 Agent 全文处理。

## 支持文件

- `scripts/text_stats.py` — 规模判定
- `scripts/split_by_lines.sh` — 切片工具
