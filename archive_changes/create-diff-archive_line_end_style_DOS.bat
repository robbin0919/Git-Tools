@echo off
rem 確保使用 UTF-8 編碼並等待編碼生效
rem chcp 65001 >nul
rem 添加短暫延遲確保編碼生效
rem ping -n 1 127.0.0.1 >nul
setlocal enabledelayedexpansion

rem ===================================================
rem Git 變更檔案打包工具 (create-diff-archive.bat)
rem ===================================================
rem 功能: 將兩個分支間的差異檔案打包成壓縮檔
rem 作者: Robbie Lee 
rem 日期: 2025-04-26
rem
rem 使用方法:
rem   create-diff-archive.bat [輸出檔名] [源分支] [目標分支]
rem   或
rem   create-diff-archive.bat -F [輸出檔名] -S [源分支] -T [目標分支]
rem
rem 參數: 
rem   [輸出檔名]   - 壓縮檔檔案名稱，副檔名依壓縮指定決定 (預設: APP_SIT.zip)
rem   [源分支]     - 比較的基準分支 (預設: master)
rem   [目標分支]   - 比較的目標分支 (預設: SIT)
rem
rem 範例:
rem   create-diff-archive.bat                         - 使用預設設定
rem   create-diff-archive.bat changes.zip             - 自訂輸出檔名 
rem   create-diff-archive.bat -F changes.zip          - 使用具名參數指定輸出檔名
rem   create-diff-archive.bat -S main -T dev          - 自訂源分支和目標分支
rem   create-diff-archive.bat -F changes.zip -S main -T dev - 自訂所有參數
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
set OUTPUT_ARCHIVE=APP_SIT
set SOURCE_BRANCH=master
set TARGET_BRANCH=SIT

rem 處理命令行參數 - 支援具名參數格式
:parse_args
if "%~1"=="" goto :args_done
if /i "%~1"=="-F" (
    set OUTPUT_ARCHIVE=%~2
    shift & shift
    goto :parse_args
)
if /i "%~1"=="-S" (
    set SOURCE_BRANCH=%~2
    shift & shift
    goto :parse_args
)
if /i "%~1"=="-T" (
    set TARGET_BRANCH=%~2
    shift & shift
    goto :parse_args
)

rem 舊參數格式的兼容性處理
if not "%~1"=="" set OUTPUT_ARCHIVE=%~1
if not "%~2"=="" set SOURCE_BRANCH=%~2
if not "%~3"=="" set TARGET_BRANCH=%~3
goto :args_done

:args_done
rem 提取副檔名
set FILE_EXT=%OUTPUT_ARCHIVE:~-4%
if not "%FILE_EXT%"==".zip" if not "%FILE_EXT%"==".ZIP" set OUTPUT_ARCHIVE=%OUTPUT_ARCHIVE%.zip

rem 使用 echo 顯示訊息以簡化輸出
echo 輸出檔案: %OUTPUT_ARCHIVE%
echo 源分支: %SOURCE_BRANCH%
echo 目標分支: %TARGET_BRANCH%

rem 使用系統臨時目錄
set TEMP_DIR=%TEMP%\git_archive_%RANDOM%

rem 創建臨時目錄
mkdir "%TEMP_DIR%" 2>nul
echo 創建臨時目錄: %TEMP_DIR%

rem 禁用 Git 路徑轉義，以便正確處理中文檔案名
git config --local core.quotepath false
rem 在獲取檔案清單前檢查源分支和目標分支是否存在
echo 檢查分支是否存在...

rem 檢查源分支是否存在
git rev-parse --verify %SOURCE_BRANCH% >nul 2>&1
if %errorlevel% neq 0 (
    echo 錯誤^: 源分支 %SOURCE_BRANCH% 不存在!
    goto cleanup
)

rem 檢查目標分支是否存在
git rev-parse --verify %TARGET_BRANCH% >nul 2>&1
if %errorlevel% neq 0 (
    echo 錯誤^: 目標分支 %TARGET_BRANCH% 不存在!
    goto cleanup
)
rem 獲取檔案清單到臨時檔案 (UTF-8 編碼)
echo 正在取得變更檔案清單...
git diff-tree -r --name-only --diff-filter=ACMRT %SOURCE_BRANCH% %TARGET_BRANCH% > "%TEMP_DIR%\filelist_utf8.txt"

rem 將 UTF-8 編碼的檔案清單轉換為 BIG5 編碼
echo 正在轉換檔案清單編碼 ^(UTF^-8 ^→ BIG5^)...
powershell -Command "$content = Get-Content -Path '%TEMP_DIR%\filelist_utf8.txt' -Encoding UTF8; [System.IO.File]::WriteAllLines('%TEMP_DIR%\filelist.txt', $content, [System.Text.Encoding]::GetEncoding(950))"

rem 檢查檔案清單是否為空
for %%I in ("%TEMP_DIR%\filelist.txt") do if %%~zI==0 (
    echo 沒有發現檔案變更，結束處理。
    goto cleanup
)

rem 獲取總檔案數量
echo 計算檔案總數...
for /f %%A in ('type "%TEMP_DIR%\filelist.txt" ^| find /c /v ""') do set total_files=%%A
echo 共發現 %total_files% 個變更檔案

rem 初始化檔案計數器
set file_count=0

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

rem 逐行讀取檔案清單並處理
for /F "usebackq tokens=*" %%f in ("%TEMP_DIR%\filelist.txt") do (
    rem 增加計數器
    set /a file_count+=1
    
    rem 設置目標檔案路徑
    set "target_file=!TEMP_DIR!\%%f"
    
    rem 創建目標檔案的父目錄
    set "target_dir=!target_file:~0,-1!"
    for %%i in ("!target_dir!") do set "parent_dir=%%~dpi"
    if not exist "!parent_dir!" mkdir "!parent_dir!" 2>nul
    
    rem 從目標分支提取檔案內容
    git cat-file -p %TARGET_BRANCH%:"%%f" > "!target_file!" 2>nul
    if !errorlevel! neq 0 (
        echo ^(!file_count!^/%total_files%^) 警告^: 無法提取檔案 %%f
    ) else (
        echo ^(!file_count!^/%total_files%^) 提取^: %%f
    )
)

rem filepath: d:\LAB\Git-Tools\archive_changes\create-diff-archive_line_end_style_DOS.bat
rem 轉換所有文本檔案的換行符 (Unix LF -> DOS CRLF)
echo 正在轉換文字檔案換行符 ^(Unix -^> DOS^)...

rem 建立簡化版的 PowerShell 腳本
echo $fileTypes = @('.txt','.xml','.html','.htm','.css','.js','.java','.cs','.cpp','.h','.c','.php','.py','.bat','.cmd','.ps1','.json','.config','.yml','.yaml','.md','.sql') > "%TEMP_DIR%\convert.ps1"
echo $count = 0 >> "%TEMP_DIR%\convert.ps1"
echo $errorCount = 0 >> "%TEMP_DIR%\convert.ps1"
echo $changedCount = 0 >> "%TEMP_DIR%\convert.ps1"
echo $files = Get-ChildItem -Path '%TEMP_DIR%' -Recurse -File ^| Where-Object { $fileTypes -contains $_.Extension.ToLower() } >> "%TEMP_DIR%\convert.ps1"
echo Write-Host "找到" $files.Count "個可能的文字檔案需要檢查" >> "%TEMP_DIR%\convert.ps1"
echo foreach($file in $files) { >> "%TEMP_DIR%\convert.ps1"
echo   try { >> "%TEMP_DIR%\convert.ps1"
echo     $count++ >> "%TEMP_DIR%\convert.ps1"
echo     $content = [System.IO.File]::ReadAllText($file.FullName) >> "%TEMP_DIR%\convert.ps1"
echo     if ($content -match "[^\r]\n") { >> "%TEMP_DIR%\convert.ps1"
echo       $newContent = $content -replace "([^\r])\n", "`$1`r`n" >> "%TEMP_DIR%\convert.ps1"
echo       [System.IO.File]::WriteAllText($file.FullName, $newContent) >> "%TEMP_DIR%\convert.ps1"
echo       $changedCount++ >> "%TEMP_DIR%\convert.ps1"
echo       if ($changedCount %% 10 -eq 0) { >> "%TEMP_DIR%\convert.ps1"
echo         Write-Host "已轉換 $changedCount 個檔案..." >> "%TEMP_DIR%\convert.ps1"
echo       } >> "%TEMP_DIR%\convert.ps1"
echo     } else { >> "%TEMP_DIR%\convert.ps1"
echo       Write-Host "檔案 $($file.Name) 已經是 CRLF 格式，不需轉換" -ForegroundColor Green >> "%TEMP_DIR%\convert.ps1"
echo     } >> "%TEMP_DIR%\convert.ps1"
echo   } catch { >> "%TEMP_DIR%\convert.ps1"
echo     $errorCount++ >> "%TEMP_DIR%\convert.ps1"
echo   } >> "%TEMP_DIR%\convert.ps1"
echo } >> "%TEMP_DIR%\convert.ps1"
echo Write-Host "檢查完成！共檢查了 $count 個檔案，轉換了 $changedCount 個檔案的換行符。(錯誤: $errorCount 個)" >> "%TEMP_DIR%\convert.ps1"

rem 執行 PowerShell 腳本
powershell -ExecutionPolicy Bypass -Command "& '%TEMP_DIR%\convert.ps1'"

rem 刪除臨時腳本
del "%TEMP_DIR%\convert.ps1" >nul 2>&1

rem 刪除現有的 zip 檔案(如果存在)
if exist "%OUTPUT_ARCHIVE%" del "%OUTPUT_ARCHIVE%"

rem 使用 PowerShell 創建 ZIP 檔案
echo 正在創建 ZIP 檔案 %OUTPUT_ARCHIVE%...
powershell -Command "Compress-Archive -Path '%TEMP_DIR%\*' -DestinationPath '%OUTPUT_ARCHIVE%' -Force"

echo 完成! 已創建 %OUTPUT_ARCHIVE%

rem 在清理前生成總結報告
echo.
echo ===================================
echo            執行總結報告            
echo ===================================
echo.
rem 獲取 Repository 資訊
for /f "tokens=*" %%r in ('git config --get remote.origin.url') do set repo_url=%%r
for /f "tokens=*" %%n in ('git rev-parse --show-toplevel') do set repo_root=%%n
rem 分開獲取分支名稱，避免使用 || 運算符
git symbolic-ref --short HEAD >"%TEMP_DIR%\branch.tmp" 2>nul
if %errorlevel% neq 0 (
    git rev-parse HEAD >"%TEMP_DIR%\branch.tmp"
)
set /p current_branch=<"%TEMP_DIR%\branch.tmp"
for /f "tokens=*" %%c in ('git rev-parse HEAD') do set current_commit=%%c


echo Repository 資訊:
echo   本地路徑: !repo_root!
echo   遠端 URL: !repo_url!
echo   當前分支: !current_branch!
echo   當前提交: !current_commit:~0,8!

rem 新增同步資訊區塊
echo.
echo 同步資訊:
set "last_fetch_time=未知"
set "last_pull_time=未知"
set "has_pull_time=false"

rem 檢查最後一次 fetch 時間
if exist ".git\FETCH_HEAD" (
    for /f "tokens=*" %%t in ('powershell -Command "Get-Item '.git\FETCH_HEAD' | Select-Object -ExpandProperty LastWriteTime"') do (
        set "last_fetch_time=%%t"
    )
)

rem 檢查最後一次 pull 時間 
if exist ".git\ORIG_HEAD" (
    for /f "tokens=*" %%p in ('powershell -Command "Get-Item '.git\ORIG_HEAD' | Select-Object -ExpandProperty LastWriteTime"') do (
        set "last_pull_time=%%p"
        set "has_pull_time=true"
    )
)

echo   最後 Fetch 時間: !last_fetch_time!
echo   最後 Pull 時間: !last_pull_time!

rem 計算並顯示時間差
powershell -Command "$fetchTime = (Get-Item '.git\FETCH_HEAD' -ErrorAction SilentlyContinue).LastWriteTime; if($fetchTime) { $diff = (Get-Date) - $fetchTime; Write-Host '   Fetch 距今: ' $diff.Days '天' $diff.Hours '小時' $diff.Minutes '分鐘前' }"

if "!has_pull_time!"=="true" (
    powershell -Command "$pullTime = (Get-Item '.git\ORIG_HEAD' -ErrorAction SilentlyContinue).LastWriteTime; if($pullTime) { $diff = (Get-Date) - $pullTime; Write-Host '   Pull 距今: ' $diff.Days '天' $diff.Hours '小時' $diff.Minutes '分鐘前' }"
) else (
    echo   Pull 距今: 無法確定
)

echo.
echo 打包資訊:
echo   源分支: %SOURCE_BRANCH%
echo   目標分支: %TARGET_BRANCH%
echo   檔案總數: %total_files%
echo   成功提取: !file_count!
if exist "%OUTPUT_ARCHIVE%" (
    rem 獲取檔案完整路徑
    for %%I in ("%OUTPUT_ARCHIVE%") do (
        set zip_size=%%~zI
        set zip_full_path=%%~fI
        set zip_date=%%~tI
    )
    set /a zip_size_kb=!zip_size!/1024
    echo   輸出檔案: %OUTPUT_ARCHIVE% ^(!zip_size_kb! KB^)
    echo   完整路徑: !zip_full_path!
    echo   檔案時間: !zip_date!
    echo   檔案類型: ZIP 壓縮檔 ^(包含 !file_count! 個檔案^)
    echo.
    echo   ※ 壓縮檔已建立完成，可直接使用。
    echo   ※ 如需查看內容，可透過檔案總管或解壓縮工具開啟檔案。
) else (
    echo   輸出檔案: 未建立
    echo   原因: 可能是在處理過程中發生錯誤或使用者中斷操作。
)

echo 操作完成時間: %date% %time%
echo ===================================
echo.
echo 開發資訊:
echo   主要開發: Robbie Lee
echo   最後修改時間: 2025-04-26
echo.
echo   詳細使用說明:
echo   create-diff-archive.bat --help
echo   或
echo   create-diff-archive.bat /?
echo.

goto cleanup

:showhelp
echo.
echo Git 變更檔案打包工具
echo =====================
echo.
echo 將兩個分支間的差異檔案打包成壓縮檔，解決命令行參數長度限制問題。
echo.
echo 語法:
echo   create-diff-archive.bat [輸出檔名] [源分支] [目標分支]
echo   或
echo   create-diff-archive.bat -F [輸出檔名] -S [源分支] -T [目標分支]
echo.
echo 參數:
echo   -F [輸出檔名]   - 壓縮檔檔案名稱，副檔名依壓縮指定決定 (預設: APP_SIT.zip)
echo   -S [源分支]     - 比較的基準分支 (預設: master)
echo   -T [目標分支]   - 比較的目標分支 (預設: SIT)
echo.
echo 範例:
echo   create-diff-archive.bat                         - 使用預設設定
echo   create-diff-archive.bat changes.zip             - 自訂輸出檔名
echo   create-diff-archive.bat -F changes.zip          - 使用具名參數指定輸出檔名
echo   create-diff-archive.bat -S main -T dev          - 自訂源分支和目標分支
echo   create-diff-archive.bat -F changes.zip -S main -T dev - 自訂所有參數
echo.
exit /b 0

:cleanup
rem 清理臨時檔案和目錄
echo 清理臨時檔案...
rmdir /S /Q "%TEMP_DIR%" 2>nul

endlocal