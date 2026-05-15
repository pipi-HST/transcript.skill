#!/usr/bin/env python3
"""输出文本统计：总字数、行数、是否需要切分

用法: python3 text_stats.py <文件路径>
输出: KEY=VALUE 格式
"""

import sys
import os


def analyze(filepath):
    if not os.path.exists(filepath):
        print(f"ERROR=文件不存在: {filepath}", file=sys.stderr)
        sys.exit(1)

    try:
        with open(filepath, "r", encoding="utf-8") as f:
            text = f.read()
    except UnicodeDecodeError:
        print(f"ERROR=文件编码错误，无法以 UTF-8 读取: {filepath}", file=sys.stderr)
        sys.exit(1)
    except PermissionError:
        print(f"ERROR=文件权限不足: {filepath}", file=sys.stderr)
        sys.exit(1)

    if not text.strip():
        print("ERROR=文件为空或仅含空白字符", file=sys.stderr)
        sys.exit(1)

    chars = len(text)
    lines = text.count("\n") + 1
    needs_split = "true" if chars >= 8000 else "false"

    print(f"CHARS={chars}")
    print(f"LINES={lines}")
    print(f"NEEDS_SPLIT={needs_split}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("用法: python3 text_stats.py <文件路径>", file=sys.stderr)
        sys.exit(1)
    analyze(sys.argv[1])
