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

## 变量替换清单

执行前逐项检查以下标记是否已替换为实际值：

| 标记 | 含义 | 出现步骤 |
|------|------|---------|
| `{INPUT_FILE}` | 规范化后的文件绝对路径 | 第零步/第一步/第二步 |
| `{CHUNKS_DIR}` | 片段输出目录 | 第二步/第三步/第四步 |
| `{OUTPUT_DIR}` | 整理产出根目录 | 第二步/第四步/第五步 |
| `{SEGMENT_FILE}` | 单个片段文件绝对路径 | 第三步 |
| `{SEGMENT_NUM}` | 片段编号（01-99） | 第三步 |
| `{TITLE}` | 话题标题 | 第三步 |
| `{EXPECTED_COUNT}` | 期望段数 | 第三步验证 |
| `{TOPIC_LIST}` | 扫描 Agent 返回的完整话题列表 | 第二步校验 |

---

## 第零步：产出确认

```bash
python3 scripts/text_stats.py {INPUT_FILE}
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
text = open('{INPUT_FILE}', 'r', encoding='utf-8').read()
lines = text.split('\n')
if len(lines) < 5 and len(text) > 1000:
    text = re.sub(r'([。！？!?])(?=\S)', r'\1\n', text)
    text = re.sub(r'(\n){3,}', r'\n\n', text)
    open('{INPUT_FILE}.normalized', 'w', encoding='utf-8').write(text)
    print(f'NORMALIZED={INPUT_FILE}.normalized')
else:
    print(f'NORMALIZED={INPUT_FILE}')
"
```

---

## 第二步：扫描切分

**NEEDS_SPLIT=false → 跳过，单 Agent 处理全文。**

启动扫描 Agent（**必须指定 Haiku 模型**），读全文找话题转折点。

**扫描 Agent Prompt（锁定，只能替换文件路径）：**

```
只用 Read 读一遍文件 {INPUT_FILE}。凭语感找话题的自然转折点，直接输出切分。

规则：
- 每段不超过 8000 字，超长话题在句边界拆开，标题加"（上/下）"
- 切在话题转换的自然位置，不截句中
- 不要用工具数精确字数，语感判断即可
- 不设段数上限，不需总结去噪，不需验证

输出格式（一行一段）：
START-END | 话题标题
```

**扫描 Agent 返回后，先校验话题是否匹配文件内容，再切分：**

启动校验 Agent（Haiku 模型）：

```
Read {INPUT_FILE} 的第 1-10 行、中间 10 行、末尾 10 行，了解内容主题。
已知扫描 Agent 对全文的话题切分结果为：

{TOPIC_LIST}

判断：话题标题能否合理对应这个文件的内容主题？
- 能 → 输出 "PASS"
- 明显跑偏（标题与内容无关，如文件名含"非线性"但话题出现"项目背景""看板"等）→ 输出 "FAIL|理由"

只输出一行。不要解释 PASS。
```

返回 PASS → 继续切分。
返回 FAIL → 废弃结果，修改 prompt 重新扫描一次。两次都 FAIL → 停下来让用户介入。

**扫描 Agent 返回后，执行切分：**

```bash
mkdir -p {OUTPUT_DIR}/chunks
bash scripts/split_by_lines.sh {INPUT_FILE} {CHUNKS_DIR} \
  "1-85|主持人开场与市场复盘" \
  "86-210|AI前沿Token稀缺（上）" \
  ...
```

每段 ±2 行自然重叠。主题名写入 `.meta` 文件。

**验证每个片段有效：**

```bash
for f in {CHUNKS_DIR}/segment_*.txt; do
  [ $(wc -l < "$f") -lt 2 ] && echo "BLOCKED: $f" && exit 1
done
echo "OK: N segments"
```

---

## 第三步：全量并行处理

**所有 Agent 在一条消息中全部启动，禁止分批发。单产出，极简 Prompt。**

### Agent Prompt（锁定，替换 {SEGMENT_FILE}, {CHUNKS_DIR}, {SEGMENT_NUM}, {TITLE}）

```
读片段文件 {SEGMENT_FILE}，输出一个整理稿。

【去噪】
删：自我打断/口吃/填充词(嗯啊呃)/ASR错字
保：术语/数据/比喻/金句/结论/问答结构
每句能正常朗读。拿不准就留。

【整理】
合并相邻重复论述，优化段落衔接。
以 "## {TITLE}" 开头，用 Markdown 分段。
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

写入 {CHUNKS_DIR}/clean_{SEGMENT_NUM}.md。

【输出格式】
仅输出一行合法 JSON 对象。不要 markdown 包裹、不要解释文字、不要问候语。

正确：
{"file":"{CHUNKS_DIR}/clean_{SEGMENT_NUM}.md"}

错误示例（以下全部禁止）：
  - ```json\n{"file":"..."}\n```
  - 已整理完成，文件保存在...
  - ## 整理结果\n...
  - 好的，我来处理这个片段。\n\n```json...
```

### 编排

**NEEDS_SPLIT=false**：单 Agent 处理全文，{TITLE} 用文件主题。

**NEEDS_SPLIT=true**：
1. 所有 Agent 在一条消息中一次性全部并行启动，禁止分批发
2. 全部完成后检查完整性：

```bash
EXPECTED={EXPECTED_COUNT}
ACTUAL=$(ls {CHUNKS_DIR}/clean_*.md 2>/dev/null | wc -l)
# 若有缺失，只重跑缺失片段
```

```bash
# 文件有效性检查：清理空文件和过短输出
for f in {CHUNKS_DIR}/clean_*.md; do
  size=$(wc -c < "$f" | tr -d ' ')
  if [ "$size" -lt 100 ]; then
    echo "TOO_SMALL: $f ($size bytes)"
  fi
done
```

---

## 第四步：拼接 + 可选速览

```bash
cat {CHUNKS_DIR}/clean_*.md > {OUTPUT_DIR}/整理稿.md
```

**以下两个 Agent 在一条消息中同时并行启动：**

**【Agent A — 质检】**（Haiku 模型，采样检查）：

```
读 {OUTPUT_DIR}/整理稿.md 的头 50 行、中间 50 行、末尾 50 行。

仅检查以下 4 项，不修改原文：
1. 跨段重复：采样区和边界处是否有内容重复（边界合并遗漏）
2. ASR 错字残留：是否有语义不通的字符
3. 术语一致性：同一概念是否有不同写法
4. 无关内容：是否有明显不属于访谈的文本混入

按项输出 PASS 或 FAIL|位置+示例。不修复。
写入 {OUTPUT_DIR}/质检报告.md。
```

**【Agent B — 速览稿】**（与质检 Agent 并行）：

```
读 {OUTPUT_DIR}/整理稿.md 全文，写速览稿。

目标：让读者快速了解全貌。精炼程度与原文长度成正比——
长文提炼更浓缩，短文保留更多细节。
格式由你根据内容特点自行组织。
所有议题必须覆盖，数据和术语必须与整理稿一致。不要叙事。

写入 {OUTPUT_DIR}/速览稿.md，回复 JSON。
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
| 质检报告 | {OUTPUT_DIR}/质检报告.md（如有 FAIL 项） |
| 耗时 | ~X 分钟 |

📂 {OUTPUT_DIR}/整理稿.md {OUTPUT_DIR}/速览稿.md
```

---

## 短文本快速通道

`NEEDS_SPLIT=false`：跳过扫描切分，单 Agent 全文处理。

## 支持文件

- `scripts/text_stats.py` — 规模判定
- `scripts/split_by_lines.sh` — 切片工具
