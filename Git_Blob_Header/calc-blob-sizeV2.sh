#!/bin/bash
# Git Blob 大小計算工具 (Bash 版本)
# 作者: robbin0919
# 日期: 2025-05-18

# 顯示幫助訊息的函數
show_help() {
    echo "用法: $0 <檔案路徑>"
    echo "例如: $0 ./HelloWorld.c"
    echo "功能: 計算檔案大小及 Git Blob 格式的完整大小"
}

# 檢查命令行參數
if [ $# -ne 1 ]; then
    echo "錯誤: 請提供檔案路徑作為參數"
    show_help
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
FILE_MODIFIED=$(stat -c %y "$FILE_PATH" 2>/dev/null || stat -f "%Sm" "$FILE_PATH")
CURRENT_USER=$(whoami)
CURRENT_DATETIME=$(date "+%Y-%m-%d %H:%M:%S")
UTC_DATETIME=$(date -u "+%Y-%m-%d %H:%M:%S")

# 建立臨時目錄
TEMP_DIR=$(mktemp -d)

# 建立 Git Blob header (含 null 字元)
BLOB_HEADER="blob ${FILE_SIZE}\0"
printf "$BLOB_HEADER" > "$TEMP_DIR/blob_header.bin"

# 計算 header 大小
HEADER_SIZE=$(stat -c %s "$TEMP_DIR/blob_header.bin" 2>/dev/null || stat -f %z "$TEMP_DIR/blob_header.bin")

# 合併 header 與檔案內容
cat "$TEMP_DIR/blob_header.bin" "$FILE_PATH" > "$TEMP_DIR/full_blob.bin"

# 計算合併後的大小
TOTAL_SIZE=$(stat -c %s "$TEMP_DIR/full_blob.bin" 2>/dev/null || stat -f %z "$TEMP_DIR/full_blob.bin")

# 顯示檔案資訊
echo
echo "=== 檔案資訊 (計算時間: $CURRENT_DATETIME) ==="
echo
echo "檔案名稱: $FILE_NAME"
echo "檔案路徑: $(realpath "$FILE_PATH")"
echo "檔案大小: $FILE_SIZE 字節"
echo "修改時間: $FILE_MODIFIED"
echo "本地時間: $CURRENT_DATETIME"
echo "UTC 時間: $UTC_DATETIME"
echo

# 顯示 Git Blob 資訊
echo "=== Git Blob 大小計算結果 ==="
echo
echo "Blob Header: 'blob ${FILE_SIZE}\0'"
echo "Header 大小: $HEADER_SIZE 字節"
echo "完整 Blob 大小: $TOTAL_SIZE 字節"
echo "建立者: $CURRENT_USER"
echo

# 確認計算正確性
EXPECTED_SIZE=$((FILE_SIZE + HEADER_SIZE))
if [ $TOTAL_SIZE -eq $EXPECTED_SIZE ]; then
    echo "驗證結果: 成功 - 檔案大小計算正確"
else
    echo "驗證結果: 失敗 - 大小不一致！"
    echo "  預期總大小: $EXPECTED_SIZE 字節"
    echo "  實際總大小: $TOTAL_SIZE 字節"
fi

# 顯示 Header 詳細資訊
echo
echo "=== Header 詳細資訊 ==="
echo
echo -n "文字內容: "
hexdump -v -e '1/1 "%_c"' "$TEMP_DIR/blob_header.bin" | sed 's/\x0/\\0/g'
echo
echo -n "十六進位: "
hexdump -v -e '1/1 "%02X "' "$TEMP_DIR/blob_header.bin"
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