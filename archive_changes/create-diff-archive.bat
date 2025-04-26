@echo off
setlocal enabledelayedexpansion

rem ===================================================
rem Git 變更檔案打包工具 (create-diff-archive.bat)
rem ===================================================
rem 功能: 將兩個分支間的差異檔案打包成壓縮檔
rem 作者: Your Name
rem 日期: 2025-04-26
rem
rem 使用方法:
rem   create-diff-archive.bat [輸出檔名] [源分支] [目標分支]
rem
rem 參數:
rem   [輸出檔名]   - 壓縮檔檔案名稱，副檔名依壓縮指定決定 (預設: APP_SIT.zip)
rem   [源分支]     - 比較的基準分支 (預設: master)
rem   [目標分支]   - 比較的目標分支 (預設: SIT)
rem
rem 範例:
rem   create-diff-archive.bat                         - 使用預設設定
rem   create-diff-archive.bat changes.zip             - 自訂輸出檔名
rem   create-diff-archive.bat changes.zip main        - 自訂檔名和源分支
rem   create-diff-archive.bat changes.zip main dev    - 自訂所有參數
rem ===================================================

rem 檢查是否為說明請求
if "%~1"=="--help" goto :showhelp
if "%~1"=="/?" goto :showhelp

rem 檢查是否在 Git 存儲庫中執行
git rev-parse --is-inside-work-tree >nul 2>&1
if %errorlevel% neq 0 (
    echo 錯誤: 請在 Git 存儲庫根目錄中執行此批次檔!
    exit /b 1
)

rem 設定預設變數
set OUTPUT_ARCHIVE=APP_SIT.zip
set SOURCE_BRANCH=master
set TARGET_BRANCH=SIT

rem 處理命令行參數
if not "%~1"=="" set OUTPUT_ARCHIVE=%~1
if not "%~2"=="" set SOURCE_BRANCH=%~2
if not "%~3"=="" set TARGET_BRANCH=%~3

rem 提取副檔名
set FILE_EXT=%~x1
if "%FILE_EXT%"=="" set OUTPUT_ARCHIVE=%OUTPUT_ARCHIVE%.zip

echo 輸出檔案: %OUTPUT_ARCHIVE%
echo 源分支: %SOURCE_BRANCH%
echo 目標分支: %TARGET_BRANCH%

set TEMP_DIR=temp_archive_%RANDOM%

rem 創建臨時目錄
mkdir %TEMP_DIR%
echo 創建臨時目錄: %TEMP_DIR%

rem 獲取檔案清單到臨時檔案
echo 正在取得變更檔案清單...
git diff-tree -r --name-only --diff-filter=ACMRT %SOURCE_BRANCH% %TARGET_BRANCH% > filelist.txt

rem 檢查檔案清單是否為空
for %%I in (filelist.txt) do if %%~zI==0 (
    echo 沒有發現檔案變更，結束處理。
    goto cleanup
)

rem 提取檔案到臨時目錄
echo 正在從 %TARGET_BRANCH% 分支提取檔案...

rem 保存當前分支名稱
for /f "tokens=*" %%b in ('git rev-parse --abbrev-ref HEAD') do set CURRENT_BRANCH=%%b
echo 當前分支: %CURRENT_BRANCH%

rem 檢查工作區是否乾淨（只用於提示）
git diff --quiet
if %errorlevel% neq 0 (
    echo 警告: 工作區有未提交的變更，但這不會影響檔案提取。
)

rem 統一使用 git cat-file 命令提取檔案 (更適合二進制檔案)
for /F "tokens=*" %%f in (filelist.txt) do (
    rem 確保目錄存在
    for %%d in ("!TEMP_DIR!\%%~pf") do if not exist "%%~d" mkdir "%%~d"
    
    rem 從目標分支提取檔案內容 (使用二進制安全的方法)
    git cat-file -p %TARGET_BRANCH%:"%%f" > "!TEMP_DIR!\%%f"
    if !errorlevel! neq 0 echo 警告: 無法提取檔案 %%f
)

rem 刪除現有的 zip 檔案(如果存在)
if exist %OUTPUT_ARCHIVE% del %OUTPUT_ARCHIVE%

rem 使用 PowerShell 創建 ZIP 檔案
echo 正在創建 ZIP 檔案 %OUTPUT_ARCHIVE%...
powershell -Command "Compress-Archive -Path '%TEMP_DIR%\*' -DestinationPath '%OUTPUT_ARCHIVE%'"

echo 完成! 已創建 %OUTPUT_ARCHIVE%

goto cleanup

:showhelp
echo.
echo Git 變更檔案打包工具
echo =====================
echo.
echo 將兩個分支間的差異檔案打包成壓縮檔，解決命令行參數長度限制問題。
echo.
echo 語法: create-diff-archive.bat [輸出檔名] [源分支] [目標分支]
echo.
echo 參數:
echo   [輸出檔名]   - 壓縮檔檔案名稱，副檔名依壓縮指定決定 (預設: APP_SIT.zip)
echo   [源分支]     - 比較的基準分支 (預設: master)
echo   [目標分支]   - 比較的目標分支 (預設: SIT)
echo.
echo 範例:
echo   create-diff-archive.bat                         - 使用預設設定
echo   create-diff-archive.bat changes.zip             - 自訂輸出檔名
echo   create-diff-archive.bat changes.zip main        - 自訂檔名和源分支
echo   create-diff-archive.bat changes.zip main dev    - 自訂所有參數
echo.
exit /b 0

:cleanup
rem 清理臨時檔案和目錄
echo 清理臨時檔案...
del filelist.txt
rmdir /S /Q %TEMP_DIR%

endlocal