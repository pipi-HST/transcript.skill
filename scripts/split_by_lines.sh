#!/bin/bash
# 用法: ./split_by_lines.sh 输入文件 输出目录 "START-END|Topic Title" ...
# 纯切分，±2 行自然重叠。主题名写入 .meta 文件。

set -e

INPUT="$1"
OUTDIR="$2"
shift 2

if [ ! -f "$INPUT" ]; then
    echo "ERROR: 输入文件不存在: $INPUT" >&2
    exit 1
fi

TOTAL_LINES=$(wc -l < "$INPUT" | tr -d ' ')
if [ "$TOTAL_LINES" -eq 0 ]; then
    echo "ERROR: 输入文件为空" >&2
    exit 1
fi

mkdir -p "$OUTDIR"
idx=1
error_count=0

for arg in "$@"; do
    range=$(echo "$arg" | cut -d'|' -f1 | tr -d ' ')
    title=$(echo "$arg" | cut -d'|' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    start=$(echo "$range" | cut -d- -f1)
    end=$(echo "$range" | cut -d- -f2)

    if [ -z "$start" ] || [ -z "$end" ]; then
        echo "WARNING: 无效行号范围 '$range'，跳过" >&2
        continue
    fi

    if [ "$start" -gt "$TOTAL_LINES" ]; then
        echo "WARNING: 起始行 $start 超出总行数 $TOTAL_LINES" >&2
        continue
    fi
    if [ "$end" -gt "$TOTAL_LINES" ]; then
        end=$TOTAL_LINES
    fi

    # ±2 行自然重叠
    ctx_start=$((start > 2 ? start - 2 : 1))
    ctx_end=$((end + 2))
    if [ "$ctx_end" -gt "$TOTAL_LINES" ]; then
        ctx_end=$TOTAL_LINES
    fi

    outfile="${OUTDIR}/segment_$(printf '%02d' $idx).txt"

    # 纯文本切分，无注释头
    sed -n "${ctx_start},${ctx_end}p" "$INPUT" > "$outfile"

    chars=$(wc -m < "$outfile" | tr -d ' ')
    if [ "$chars" -eq 0 ]; then
        echo "ERROR: 片段 $idx 输出为空" >&2
        rm -f "$outfile"
        error_count=$((error_count + 1))
        idx=$((idx + 1))
        continue
    fi

    # 主题名写入 .meta 文件
    echo "$title" > "${OUTDIR}/segment_$(printf '%02d' $idx).meta"

    line_count=$(wc -l < "$outfile" | tr -d ' ')
    echo "segment $idx (${line_count} lines, ctx ${ctx_start}-${ctx_end}): ${chars} chars | ${title}"

    idx=$((idx + 1))
done

actual=$((idx - 1))
echo "total: ${actual} segments (${error_count} errors) → ${OUTDIR}/"

if [ "$error_count" -gt 0 ]; then
    echo "WARNING: ${error_count} segments failed" >&2
fi

exit $error_count
