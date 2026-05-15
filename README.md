# transcript

将语音转文字长文本提纯为流畅讲稿。智能并行处理，3.8 万字 → ~7 分钟。

基于标准 `SKILL.md` 格式，兼容 46 个 AI Coding Agent，零改动通用。

## 能干什么

输入任何语音转文字的原始文本——会议录音、访谈、播客、演讲、调研笔录——

输出两版：

| 产出 | 文件 | 说明 |
|------|------|------|
| **整理稿** | `整理稿.md` | 去噪 + 段落精炼 + 章节标题，信息零遗漏 |
| **速览稿** | `速览稿.md` | 结构化要点速查，按比例自适应深度 |

## 怎么做到的

```
输入文件
  → text_stats.py（规模判定）
  → 扫描 Agent（通读全文找话题边界）
  → 按话题切段
  → N 个 Agent 全量并行处理
  → 拼接输出
```

核心设计：
- **扫描即切分**：一个 Agent 读全文找话题转折点，不需要脚本预分析
- **全量并行**：所有片段同时处理，总耗时 = 最慢那个，不是 sum(批次)
- **保守偏差**：拿不准的术语/数据/比喻原样保留，宁可多留不误删
- **两个脚本**：总共 133 行 Python + Shell。其余全靠 Agent 的文本理解能力

## 安装

所有平台共用同一份 `SKILL.md` + `scripts/`，只需复制到对应目录。

### Claude Code

```bash
mkdir -p ~/.claude/skills/transcript.skill
cp -r . ~/.claude/skills/transcript.skill/
```

### Gemini CLI

```bash
mkdir -p ~/.gemini/skills/transcript.skill
cp -r . ~/.gemini/skills/transcript.skill/
```

### Cursor

```bash
mkdir -p ~/.cursor/skills/transcript.skill
cp -r . ~/.cursor/skills/transcript.skill/
```

### Codex

```bash
mkdir -p ~/.codex/skills/transcript.skill
cp -r . ~/.codex/skills/transcript.skill/
```

### OpenCode

```bash
mkdir -p ~/.config/opencode/skills/transcript.skill
cp -r . ~/.config/opencode/skills/transcript.skill/
```

## 使用

在对话中传入文件路径：

```
/transcript ~/Downloads/会议录音转文字.txt
```

或自然语言触发：

> 帮我整理这份访谈记录

默认产出整理稿。可追加速览稿（回复"速览"）。

## 产出示例

原文字数 37,763，处理后：

- **整理稿** 17,809 字 —— 9 个章节，去噪精炼，流畅阅读
- **速览稿** 7,264 字 —— 结构化要点，5 分钟全貌

## 注意事项

- 需 Python 3（用于 `text_stats.py`）
- 短文本（< 8,000 字）自动走快速通道，单 Agent 直接处理
- 长文本按话题自动切段，段数无上限，并发数也不设上限

## License

MIT
