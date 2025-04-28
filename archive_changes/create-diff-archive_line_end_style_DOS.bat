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

rem ===== 改進的同步功能 =====
echo.
echo ===================================
echo      與遠端Repository同步中...      
echo ===================================
echo.

rem 儲存目前分支名稱，稍後會返回此分支
for /f "tokens=*" %%b in ('git rev-parse --abbrev-ref HEAD') do set ORIGINAL_BRANCH=%%b
echo 當前工作分支: %ORIGINAL_BRANCH%

rem 檢查工作區是否乾淨
git diff --quiet
set GIT_CLEAN_WORKSPACE=%errorlevel%
if %GIT_CLEAN_WORKSPACE% neq 0 (
    echo 警告: 本機工作區有未提交的變更，將在同步後還原。
    git stash push -m "自動暫存於 %date% %time%" >nul 2>&1
)

rem 先獲取所有遠端分支資訊
echo 正在獲取遠端分支資訊...
git remote update origin --prune
set GIT_REMOTE_ERROR=%errorlevel%
if %GIT_REMOTE_ERROR% neq 0 (
    echo 警告: 無法連接遠端倉庫 (錯誤碼: %GIT_REMOTE_ERROR%)
    echo 可能原因: 網路問題、VPN未連接或遠端伺服器暫時無法訪問
    
    rem 檢查是否至少有本地分支可用
    git rev-parse --verify %SOURCE_BRANCH% >nul 2>&1
    set LOCAL_SOURCE_EXISTS=%errorlevel%
    git rev-parse --verify %TARGET_BRANCH% >nul 2>&1
    set LOCAL_TARGET_EXISTS=%errorlevel%
    
    if %LOCAL_SOURCE_EXISTS% neq 0 (
        echo 嚴重錯誤: 源分支 %SOURCE_BRANCH% 不存在於本地，且無法從遠端獲取。
        echo 操作無法繼續，請檢查分支名稱是否正確或恢復網絡連接後重試。
        goto cleanup
    )
    
    if %LOCAL_TARGET_EXISTS% neq 0 (
        echo 嚴重錯誤: 目標分支 %TARGET_BRANCH% 不存在於本地，且無法從遠端獲取。
        echo 操作無法繼續，請檢查分支名稱是否正確或恢復網絡連接後重試。
        goto cleanup
    )
    
    echo 將繼續使用本地版本進行比較，如需最新版本請確保網絡連接後再次執行。
    
    rem 跳過同步直接進行比較
    goto skip_sync
) else (
    echo 成功獲取遠端分支資訊。
    
    rem 檢查並同步源分支
    echo.
    echo 正在檢查源分支 %SOURCE_BRANCH%...
    
    rem 先檢查本地分支是否存在
    git rev-parse --verify %SOURCE_BRANCH% >nul 2>&1
    set LOCAL_SOURCE_EXISTS=%errorlevel%
    
    rem 檢查遠端分支是否存在
    git rev-parse --verify origin/%SOURCE_BRANCH% >nul 2>&1
    set REMOTE_SOURCE_EXISTS=%errorlevel%
    
    if %LOCAL_SOURCE_EXISTS% neq 0 (
        if %REMOTE_SOURCE_EXISTS% equ 0 (
            echo 源分支 %SOURCE_BRANCH% 不存在於本地但存在於遠端，正在創建...
            git checkout -b %SOURCE_BRANCH% origin/%SOURCE_BRANCH%
            if %errorlevel% equ 0 (
                echo 成功創建並切換至源分支 %SOURCE_BRANCH%
            ) else (
                echo 警告: 無法創建源分支 %SOURCE_BRANCH%，將繼續使用遠端版本進行比較。
            )
        ) else (
            echo 警告: 源分支 %SOURCE_BRANCH% 不存在於本地也不存在於遠端。
        )
    ) else (
        echo 源分支 %SOURCE_BRANCH% 存在於本地，正在同步...
        git checkout %SOURCE_BRANCH% >nul 2>&1
        git pull origin %SOURCE_BRANCH% --ff-only
        if %errorlevel% neq 0 (
            echo 警告: 無法使用快速前進合併方式更新 %SOURCE_BRANCH%，嘗試正常合併...
            git pull origin %SOURCE_BRANCH%
        )
    )
    
    rem 檢查並同步目標分支
    echo.
    echo 正在檢查目標分支 %TARGET_BRANCH%...
    
    rem 先檢查本地分支是否存在
    git rev-parse --verify %TARGET_BRANCH% >nul 2>&1
    set LOCAL_TARGET_EXISTS=%errorlevel%
    
    rem 檢查遠端分支是否存在
    git rev-parse --verify origin/%TARGET_BRANCH% >nul 2>&1
    set REMOTE_TARGET_EXISTS=%errorlevel%
    
    if %LOCAL_TARGET_EXISTS% neq 0 (
        if %REMOTE_TARGET_EXISTS% equ 0 (
            echo 目標分支 %TARGET_BRANCH% 不存在於本地但存在於遠端，正在創建...
            git checkout -b %TARGET_BRANCH% origin/%TARGET_BRANCH%
            if %errorlevel% equ 0 (
                echo 成功創建並切換至目標分支 %TARGET_BRANCH%
            ) else (
                echo 警告: 無法創建目標分支 %TARGET_BRANCH%，將繼續使用遠端版本進行比較。
            )
        ) else (
            echo 警告: 目標分支 %TARGET_BRANCH% 不存在於本地也不存在於遠端。
        )
    ) else (
        echo 目標分支 %TARGET_BRANCH% 存在於本地，正在同步...
        git checkout %TARGET_BRANCH% >nul 2>&1
        git pull origin %TARGET_BRANCH% --ff-only
        if %errorlevel% neq 0 (
            echo 警告: 無法使用快速前進合併方式更新 %TARGET_BRANCH%，嘗試正常合併...
            git pull origin %TARGET_BRANCH%
        )
    )
    
    rem 返回原本的分支
    echo.
    echo 返回原始工作分支: %ORIGINAL_BRANCH%
    git checkout %ORIGINAL_BRANCH% >nul 2>&1
    
    rem 如果原本有暫存變更，還原之
    if %GIT_CLEAN_WORKSPACE% neq 0 (
        git stash pop >nul 2>&1
        if %errorlevel% neq 0 (
            echo 警告: 還原暫存的變更失敗。暫存內容仍保留在 stash 中。
        ) else (
            echo 已還原暫存的工作區變更。
        )
    )
)

:skip_sync
echo.
echo ===================================
echo        同步完成，開始比對檔案       
echo ===================================
echo.
rem ===== 新增同步功能結束 =====

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
        echo ^(!file_count!^/%total_files%^) 提取^: [%TARGET_BRANCH%] %%f
    )
)

rem filepath: d:\LAB\Git-Tools\archive_changes\create-diff-archive_line_end_style_DOS.bat
rem 轉換所有文本檔案的換行符 (Unix LF -> DOS CRLF)
echo 正在轉換文字檔案換行符 ^(Unix -^> DOS^)...

rem 在工作目錄建立更精確的 PowerShell 腳本
echo $fileTypes = @('.vw','.tps','.trg','.tab','.seq','.prc','.spc','.bdy','.fnc','.idx','.txt','.xml','.html','.htm','.css','.js','.java','.aspx','.cshtml','.cs','.vb','.cpp','.h','.c','.php','.py','.bat','.cmd','.ps1','.json','.config','.yml','.yaml','.md','.sql','.map','.csproj','.vbproj','.settings','.myapp','.sln') > "convert_eol.ps1"
echo $count = 0 >> "convert_eol.ps1"
echo $errorCount = 0 >> "convert_eol.ps1"
echo $changedCount = 0 >> "convert_eol.ps1"
echo $files = Get-ChildItem -Path '%TEMP_DIR%' -Recurse -File ^| Where-Object { $fileTypes -contains $_.Extension.ToLower() } >> "convert_eol.ps1"
echo Write-Host "找到" $files.Count "個可能的文字檔案需要檢查" >> "convert_eol.ps1"
echo foreach($file in $files) { >> "convert_eol.ps1"
echo   try { >> "convert_eol.ps1"
echo     $count++ >> "convert_eol.ps1"
echo     # 讀取檔案二進制內容 >> "convert_eol.ps1"
echo     $bytes = [System.IO.File]::ReadAllBytes($file.FullName) >> "convert_eol.ps1"
echo     # 檢查是否需要轉換 >> "convert_eol.ps1"
echo     $needConversion = $false >> "convert_eol.ps1"
echo     for($i = 0; $i -lt $bytes.Length - 1; $i++) { >> "convert_eol.ps1"
echo       if($bytes[$i] -eq 10 -and ($i -eq 0 -or $bytes[$i-1] -ne 13)) { >> "convert_eol.ps1"
echo         $needConversion = $true >> "convert_eol.ps1"
echo         break >> "convert_eol.ps1"
echo       } >> "convert_eol.ps1"
echo     } >> "convert_eol.ps1"
echo     if($needConversion) { >> "convert_eol.ps1"
echo       # 建立新的位元組陣列進行轉換 >> "convert_eol.ps1"
echo       $newBytes = New-Object System.Collections.ArrayList >> "convert_eol.ps1"
echo       for($i = 0; $i -lt $bytes.Length; $i++) { >> "convert_eol.ps1"
echo         if($bytes[$i] -eq 10 -and ($i -eq 0 -or $bytes[$i-1] -ne 13)) { >> "convert_eol.ps1"
echo           [void]$newBytes.Add(13) # 先加入 CR >> "convert_eol.ps1"
echo         } >> "convert_eol.ps1"
echo         [void]$newBytes.Add($bytes[$i]) >> "convert_eol.ps1"
echo       } >> "convert_eol.ps1"
echo       # 直接寫入二進制資料，保留原有特性 >> "convert_eol.ps1"
echo       [System.IO.File]::WriteAllBytes($file.FullName, $newBytes.ToArray()) >> "convert_eol.ps1"
echo       $changedCount++ >> "convert_eol.ps1"
echo       if($changedCount %% 10 -eq 0) { >> "convert_eol.ps1"
echo         Write-Host "已轉換 $changedCount 個檔案..." >> "convert_eol.ps1"
echo       } >> "convert_eol.ps1"
echo     } else { >> "convert_eol.ps1"
echo       Write-Host "檔案 $($file.FullName) 已經是 CRLF 格式，不需轉換" -ForegroundColor Green >> "convert_eol.ps1"
echo     } >> "convert_eol.ps1"
echo   } catch { >> "convert_eol.ps1"
echo     $errorCount++ >> "convert_eol.ps1"
echo     Write-Host "處理檔案 $($file.Name) 時發生錯誤: $_" -ForegroundColor Red >> "convert_eol.ps1"
echo   } >> "convert_eol.ps1"
echo } >> "convert_eol.ps1"
echo Write-Host "檢查完成！共檢查了 $count 個檔案，轉換了 $changedCount 個檔案的換行符。(錯誤: $errorCount 個)" >> "convert_eol.ps1"

rem 執行 PowerShell 腳本
powershell -ExecutionPolicy Bypass -File "convert_eol.ps1"

rem 刪除臨時腳本
del "convert_eol.ps1" >nul 2>&1

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