#!/bin/bash
# Git Blob 大小計算工具 (精簡版)
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
FILE_SIZE=$(stat -c %s "$FILE_PATH" 2>/dev/null || stat -f %z "$FILE_PATH")
CURRENT_DATETIME=$(date "+%Y-%m-%d %H:%M:%S")

# 建立臨時目錄
TEMP_DIR=$(mktemp -d)

# 建立 Git Blob header (含 null 字元)
printf "blob ${FILE_SIZE}\0" > "$TEMP_DIR/header.bin"

# 計算 header 大小
HEADER_SIZE=$(stat -c %s "$TEMP_DIR/header.bin" 2>/dev/null || stat -f %z "$TEMP_DIR/header.bin")

# 合併 header 與檔案內容
cat "$TEMP_DIR/header.bin" "$FILE_PATH" > "$TEMP_DIR/full_blob.bin"

# 計算合併後的大小
TOTAL_SIZE=$(stat -c %s "$TEMP_DIR/full_blob.bin" 2>/dev/null || stat -f %z "$TEMP_DIR/full_blob.bin")

# 顯示計算結果
echo "=== Git Blob 大小計算結果 (計算時間: $CURRENT_DATETIME) ==="
echo
echo "檔案名稱: $FILE_NAME"
echo "檔案大小: $FILE_SIZE 字節"
echo "Blob Header: 'blob ${FILE_SIZE}\0'"
echo "Header 大小: $HEADER_SIZE 字節"
echo "完整 Blob 大小: $TOTAL_SIZE 字節"
echo "建立者: $(whoami)"
echo

# 清理臨時檔案
rm -rf "$TEMP_DIR"

exit 0