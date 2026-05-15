# Transcript Skill 执行层面改进 — 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复 transcript skill 的四个执行层面问题：变量占位符不统一、扫描结果无校验、Agent 输出格式不一致、终稿无质量抽查。

**Architecture:** 所有改动集中在 SKILL.md 一个文件，不创建新脚本，不修改 scripts/ 下现有脚本。校验和质检通过内联 Agent prompt 实现，不引入额外依赖。

**Tech Stack:** Markdown 文档修改

---

### 文件结构

| 文件 | 操作 | 职责 |
|------|------|------|
| `SKILL.md` | 修改 | 四个改进全部在此文件 |

---

### Task 1: 变量替换标准化 — 新增清单 + 全文统一标记

**文件:**
- 修改: `SKILL.md`（全文）

- [ ] **Step 1: 在「产出」表格后插入变量替换清单**

在 `## 产出` 表格和 `---` 分隔线之后、`## 第零步` 之前，插入：

```markdown
## 变量替换清单

执行前逐项检查以下标记是否已替换为实际值：

| 标记 | 含义 | 出现步骤 |
|------|------|---------|
| `{INPUT_FILE}` | 规范化后的文件绝对路径 | 第一步/第二步/第四步 |
| `{CHUNKS_DIR}` | 片段输出目录 | 第二步/第三步 |
| `{OUTPUT_DIR}` | 整理产出根目录 | 第二步/第四步 |
| `{SEGMENT_FILE}` | 单个片段文件绝对路径 | 第三步 |
| `{SEGMENT_NUM}` | 片段编号（01-99） | 第三步 |
| `{TITLE}` | 话题标题 | 第三步 |
| `{EXPECTED_COUNT}` | 期望段数 | 第三步验证 |
| `{TOPIC_LIST}` | 扫描 Agent 返回的完整话题列表 | 第二步校验 |

```

- [ ] **Step 2: 修改第一步 — 规范化脚本中的路径**

将：
```
text = open('INPUT', 'r', encoding='utf-8').read()
```
改为：
```
text = open('{INPUT_FILE}', 'r', encoding='utf-8').read()
```

将：
```
open('INPUT.normalized', 'w', encoding='utf-8').write(text)
print(f'NORMALIZED=INPUT.normalized')
```
改为：
```
open('{INPUT_FILE}.normalized', 'w', encoding='utf-8').write(text)
print(f'NORMALIZED={INPUT_FILE}.normalized')
```

将：
```
print(f'NORMALIZED=INPUT')
```
改为：
```
print(f'NORMALIZED={INPUT_FILE}')
```

- [ ] **Step 3: 修改第二步 — 扫描 Agent prompt 文件路径**

将：
```
只用 Read 读一遍文件。凭语感找话题的自然转折点，直接输出切分。
```
改为：
```
只用 Read 读一遍文件 {INPUT_FILE}。凭语感找话题的自然转折点，直接输出切分。
```

- [ ] **Step 4: 修改第二步 — 切分命令中的路径**

将：
```
mkdir -p <输出目录>/clean
bash scripts/split_by_lines.sh <规范化文件> <输出目录>/chunks \
```
改为：
```
mkdir -p {OUTPUT_DIR}/chunks
bash scripts/split_by_lines.sh {INPUT_FILE} {CHUNKS_DIR} \
```

- [ ] **Step 5: 修改第二步 — 验证命令中的路径**

将：
```
for f in <chunks目录>/segment_*.txt; do
  [ $(wc -l < "$f") -lt 2 ] && echo "BLOCKED: $f" && exit 1
done
```
改为：
```
for f in {CHUNKS_DIR}/segment_*.txt; do
  [ $(wc -l < "$f") -lt 2 ] && echo "BLOCKED: $f" && exit 1
done
```

- [ ] **Step 6: 修改第三步 — 整理 Agent prompt 中的变量**

将 prompt 块中的：
```
读片段文件，输出一个整理稿。
```
改为：
```
读片段文件 {SEGMENT_FILE}，输出一个整理稿。
```

将：
```
以 "## {title}" 开头
```
改为：
```
以 "## {TITLE}" 开头
```

将：
```
写入 {dir}/clean_NN.md。回复只返回 JSON。
```
改为：
```
写入 {CHUNKS_DIR}/clean_{SEGMENT_NUM}.md。
```

- [ ] **Step 7: 修改第三步 — NEEDS_SPLIT=false 分支**

将：
```
单 Agent 处理全文，{title} 用文件主题。
```
改为：
```
单 Agent 处理全文，{TITLE} 用文件主题。
```

- [ ] **Step 8: 修改第三步 — 完整性检查命令**

将：
```
EXPECTED=N
ACTUAL=$(ls {dir}/clean_*.md 2>/dev/null | wc -l)
```
改为：
```
EXPECTED={EXPECTED_COUNT}
ACTUAL=$(ls {CHUNKS_DIR}/clean_*.md 2>/dev/null | wc -l)
```

- [ ] **Step 9: 修改第四步 — 拼接命令**

将：
```
cat {dir}/clean_*.md > 整理稿.md
```
改为：
```
cat {CHUNKS_DIR}/clean_*.md > {OUTPUT_DIR}/整理稿.md
```

- [ ] **Step 10: 验证**

确认 SKILL.md 中不再存在 `<输出目录>`、`<规范化文件>`、`<chunks目录>` 等尖括号占位符，全部替换为 `{VAR}` 格式。

---

### Task 2: 扫描结果 AI 校验

**文件:**
- 修改: `SKILL.md`（第二步）

- [ ] **Step 1: 在校验片段有效性之前插入校验 Agent 步骤**

在 `**扫描 Agent 返回后，执行切分：**` 之前插入：

```markdown
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
```

- [ ] **Step 2: 验证**

确认校验 Agent prompt 中的 `{INPUT_FILE}` 和 `{TOPIC_LIST}` 已在变量替换清单中。

---

### Task 3: 整理 Agent 输出格式加固

**文件:**
- 修改: `SKILL.md`（第三步）

- [ ] **Step 1: 替换整理 Agent prompt 末尾的格式约束**

将：
```
写入 {CHUNKS_DIR}/clean_{SEGMENT_NUM}.md。
回复只返回 JSON。
```

替换为：

```
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

- [ ] **Step 2: 在完整性检查后加入文件有效性验证**

在 `第三步` 的完整性检查 bash 块之后，追加：

```bash
# 文件有效性检查
for f in {CHUNKS_DIR}/clean_*.md; do
  size=$(wc -c < "$f" | tr -d ' ')
  if [ "$size" -lt 100 ]; then
    echo "TOO_SMALL: $f ($size bytes)"
  fi
done
```

- [ ] **Step 3: 验证**

确认 prompt 中正确示例使用 `{CHUNKS_DIR}` 和 `{SEGMENT_NUM}` 变量，与清单一致。

---

### Task 4: 终稿质量抽查

**文件:**
- 修改: `SKILL.md`（第四步）

- [ ] **Step 1: 在拼接命令之后、速览 Agent 之前插入质检 Agent**

在 `cat` 拼接命令之后，插入：

```markdown
**拼接完成后启动质检 Agent**（与速览 Agent 并行）：

```
读 {OUTPUT_DIR}/整理稿.md 全文。

仅检查以下 4 项，不修改原文：
1. 跨段重复：相邻段落是否有内容重复（边界合并遗漏）
2. ASR 错字残留：是否有语义不通的字符
3. 术语一致性：同一概念是否有不同写法（如 Mesos/Mesos 多处不一致）
4. 无关内容：是否有明显不属于访谈的文本混入

按项输出 PASS 或 FAIL|位置+示例。不修复。
写入 {OUTPUT_DIR}/质检报告.md。
```

- [ ] **Step 2: 修改第五步完成报告**

在完成报告表格中新增一行：

```markdown
| 质检报告 | {OUTPUT_DIR}/质检报告.md（如有 FAIL 项） |
```

- [ ] **Step 3: 验证**

确认质检 Agent 读取的是拼接后的 `整理稿.md`，不是分段 clean 文件。

---

### Task 5: 最终检查

- [ ] **Step 1: 全量自检**

读一遍完整的 SKILL.md，确认：
- 四个改进的段落之间没有逻辑冲突
- 变量替换清单覆盖了所有实际使用的标记
- 流程顺序正确：扫描→校验→切分→验证→并行整理→完整性检查→拼接→质检+速览
- 旧格式占位符（`<输出目录>`、`INPUT`、`{path}`、`{dir}`、`{title}` 等）已全部替换

- [ ] **Step 2: git diff 确认**

```bash
cd /Users/pipi/.claude/skills/transcript && git diff SKILL.md
```

人工确认改动范围符合预期。
