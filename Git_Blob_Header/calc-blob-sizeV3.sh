#!/bin/bash
# Git Blob 大小計算工具 (Windows Git Bash 兼容版)
# 日期: 2025-05-18

# 檢查命令行參數
if [ $# -ne 1 ]; then
    echo "用法: $0 <檔案路徑>"
    exit 1
fi

FILE_PATH="$1"

# 檢查檔案是否存在
if [ ! -f "$FILE_PATH" ]; then
    echo "錯誤: 檔案 '$FILE_PATH' 不存在"
    exit 2
fi

# 獲取檔案資訊
FILE_NAME=$(basename "$FILE_PATH")
# 使用wc代替stat，更好的MinGW兼容性
FILE_SIZE=$(wc -c < "$FILE_PATH" | tr -d ' ')
CURRENT_DATETIME=$(date "+%Y-%m-%d %H:%M:%S")
CURRENT_USER=$(whoami)

# 建立臨時目錄
TEMP_DIR=$(mktemp -d -p "${TMPDIR:-/tmp}" "git-blob-XXXXXX")

# 建立 Git Blob header (含 null 字元)
printf "blob ${FILE_SIZE}\0" > "$TEMP_DIR/header.bin"

# 計算 header 大小
HEADER_SIZE=$(wc -c < "$TEMP_DIR/header.bin" | tr -d ' ')

# 合併 header 與檔案內容
cat "$TEMP_DIR/header.bin" "$FILE_PATH" > "$TEMP_DIR/full_blob.bin"

# 計算合併後的大小
TOTAL_SIZE=$(wc -c < "$TEMP_DIR/full_blob.bin" | tr -d ' ')

# 顯示計算結果
echo
echo "=== Git Blob 大小計算結果 (計算時間: $CURRENT_DATETIME) ==="
echo
echo "檔案名稱: $FILE_NAME"
echo "檔案大小: $FILE_SIZE bytes"
echo "Blob Header: 'blob ${FILE_SIZE}\0'"
echo "Header 大小: $HEADER_SIZE bytes"
echo "完整 Blob 大小: $TOTAL_SIZE bytes"
echo "建立者: $CURRENT_USER"
echo

# 顯示 Header 詳細資訊 (不使用hexdump)
echo "=== Header 詳細資訊 ==="
echo
echo -n "文字內容: "
# 使用od和tr替代hexdump顯示文字內容
od -An -tx1c "$TEMP_DIR/header.bin" | tr -d '\n' | sed 's/  \+/ /g' | sed 's/ $//' | sed 's/\\0/\\0/g' | sed 's/^[ \t]*//'
echo
echo -n "十六進位: "
# 使用xxd或od替代hexdump顯示十六進位
if command -v xxd &> /dev/null; then
    xxd -p "$TEMP_DIR/header.bin" | tr -d '\n' | sed 's/\(..\)/\1 /g' | sed 's/ $//'
else
    # 如果沒有xxd，使用od
    od -An -tx1 "$TEMP_DIR/header.bin" | tr -d '\n' | sed 's/  \+/ /g' | sed 's/ $//' | sed 's/^[ \t]*//'
fi
echo
echo
# 可選：計算 SHA-1 哈希
if command -v sha1sum &> /dev/null; then
    echo
    echo "=== SHA-1 哈希值 ==="
    echo
    SHA1=$(sha1sum "$TEMP_DIR/full_blob.bin" | cut -d ' ' -f 1)
    echo "Git Blob SHA-1: $SHA1"
fi

# 清理臨時檔案
rm -rf "$TEMP_DIR"

exit 0