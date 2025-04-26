@echo off
setlocal enabledelayedexpansion

rem 設定變數
set OUTPUT_ZIP=APP_SIT.zip
set SOURCE_BRANCH=master
set TARGET_BRANCH=SIT
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
echo 正在從 HEAD 提取檔案...
for /F "tokens=*" %%f in (filelist.txt) do (
    rem 確保目錄存在
    for %%d in ("!TEMP_DIR!\%%~pf") do if not exist "%%~d" mkdir "%%~d"
    
    rem 從 HEAD 提取檔案內容
    git show HEAD:"%%f" > "!TEMP_DIR!\%%f"
    if !errorlevel! neq 0 echo 警告: 無法提取檔案 %%f
)

rem 刪除現有的 zip 檔案(如果存在)
if exist %OUTPUT_ZIP% del %OUTPUT_ZIP%

rem 使用 PowerShell 創建 ZIP 檔案
echo 正在創建 ZIP 檔案 %OUTPUT_ZIP%...
powershell -Command "Compress-Archive -Path '%TEMP_DIR%\*' -DestinationPath '%OUTPUT_ZIP%'"

echo 完成! 已創建 %OUTPUT_ZIP%

:cleanup
rem 清理臨時檔案和目錄
echo 清理臨時檔案...
del filelist.txt
rmdir /S /Q %TEMP_DIR%

endlocal