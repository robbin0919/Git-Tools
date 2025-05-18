@echo off
setlocal enabledelayedexpansion

REM === 獲取當前日期時間 ===
for /f "tokens=2 delims==" %%a in ('wmic OS Get LocalDateTime /value') do set dt=%%a
set YEAR=%dt:~0,4%
set MONTH=%dt:~4,2%
set DAY=%dt:~6,2%
set HOUR=%dt:~8,2%
set MINUTE=%dt:~10,2%
set SECOND=%dt:~12,2%
set CURRENT_DATETIME=%YEAR%-%MONTH%-%DAY% %HOUR%:%MINUTE%:%SECOND%

REM === 檢查參數 ===
if "%~1"=="" (
    echo 錯誤: 缺少檔案路徑參數！
    echo 用法: CalcFileSize.bat [檔案路徑]
    echo 範例: CalcFileSize.bat C:\path\to\image.png
    exit /b 1
)

REM === 檢查檔案是否存在 ===
if not exist "%~1" (
    echo 錯誤: 檔案 "%~1" 不存在！
    exit /b 2
)

REM === 計算檔案資訊 ===
for %%A in ("%~1") do (
    set FILE_PATH=%%~fA
    set FILE_NAME=%%~nxA
    set FILE_SIZE=%%~zA
    set FILE_DATE=%%~tA
)

REM === 建立臨時目錄 ===
set TEMP_DIR=%TEMP%\file_size_calc_%RANDOM%
mkdir "%TEMP_DIR%" 2>nul

REM === 使用 PowerShell 生成正確的 blob header 包含真實空字元 ===
echo $header = "blob %FILE_SIZE%" + [char]0; > "%TEMP_DIR%\create_header.ps1"
echo [System.IO.File]::WriteAllBytes("%TEMP_DIR%\blob_header.bin", [System.Text.Encoding]::UTF8.GetBytes($header)); >> "%TEMP_DIR%\create_header.ps1"
powershell -ExecutionPolicy Bypass -File "%TEMP_DIR%\create_header.ps1" > nul

REM === 計算 header 檔案大小 ===
for %%A in ("%TEMP_DIR%\blob_header.bin") do set HEADER_SIZE=%%~zA

REM === 合併 header 與檔案 ===
copy /b "%TEMP_DIR%\blob_header.bin"+"%FILE_PATH%" "%TEMP_DIR%\full_blob.bin" > nul

REM === 計算合併檔案大小 ===
for %%A in ("%TEMP_DIR%\full_blob.bin") do set TOTAL_SIZE=%%~zA

REM === 顯示檔案信息 ===
echo.
echo === 檔案資訊 (計算時間: %CURRENT_DATETIME%) ===
echo.
echo 檔案名稱: %FILE_NAME%
echo 檔案路徑: %FILE_PATH%
echo 檔案大小: %FILE_SIZE% 字節
echo 修改時間: %FILE_DATE%
echo.

REM === 顯示 Git Blob 資訊 ===
echo === Git Blob 大小計算結果 ===
echo.
echo Blob Header: 'blob %FILE_SIZE%\0'
echo Header 大小: %HEADER_SIZE% 字節
echo 完整 Blob 大小: %TOTAL_SIZE% 字節
echo 建立者: %USERNAME%
echo.

REM === 確認大小計算正確性 ===
set /a EXPECTED_SIZE=%FILE_SIZE% + %HEADER_SIZE%
if %TOTAL_SIZE% EQU %EXPECTED_SIZE% (
    echo 驗證結果: 成功 - 檔案大小計算正確
) else (
    echo 驗證結果: 失敗 - 大小不一致！
    echo   預期總大小: %EXPECTED_SIZE% 字節
    echo   實際總大小: %TOTAL_SIZE% 字節
)

REM === 顯示 Header 詳細資訊 (從 PowerShell 獲取) ===
echo.
echo === Header 詳細資訊 ===
echo.
echo $headerBytes = [System.IO.File]::ReadAllBytes("%TEMP_DIR%\blob_header.bin"); > "%TEMP_DIR%\read_header.ps1"
echo $headerContent = ""; >> "%TEMP_DIR%\read_header.ps1"
echo foreach($b in $headerBytes) { if($b -eq 0) { $headerContent += "\0" } else { $headerContent += [char]$b } } >> "%TEMP_DIR%\read_header.ps1"
echo $hexContent = [BitConverter]::ToString($headerBytes).Replace("-", " "); >> "%TEMP_DIR%\read_header.ps1"
echo "文字內容: " + $headerContent; >> "%TEMP_DIR%\read_header.ps1"
echo "十六進位: " + $hexContent; >> "%TEMP_DIR%\read_header.ps1"
powershell -ExecutionPolicy Bypass -File "%TEMP_DIR%\read_header.ps1"

REM === 清理臨時檔案 ===
rd /s /q "%TEMP_DIR%" 2>nul

exit /b 0