@echo off
rem �T�O�ϥ� UTF-8 �s�X�õ��ݽs�X�ͮ�
rem chcp 65001 >nul
rem �K�[�u�ȩ���T�O�s�X�ͮ�
rem ping -n 1 127.0.0.1 >nul
setlocal enabledelayedexpansion

rem ===================================================
rem Git �ܧ��ɮץ��]�u�� (create-diff-archive.bat)
rem ===================================================
rem �\��: �N��Ӥ��䶡���t���ɮץ��]�����Y��
rem �@��: Robbie Lee 
rem ���: 2025-04-26
rem
rem �ϥΤ�k:
rem   create-diff-archive.bat [��X�ɦW] [������] [�ؼФ���]
rem   ��
rem   create-diff-archive.bat -F [��X�ɦW] -S [������] -T [�ؼФ���]
rem
rem �Ѽ�: 
rem   [��X�ɦW]   - ���Y���ɮצW�١A���ɦW�����Y���w�M�w (�w�]: APP_SIT.zip)
rem   [������]     - �������Ǥ��� (�w�]: master)
rem   [�ؼФ���]   - ������ؼФ��� (�w�]: SIT)
rem
rem �d��:
rem   create-diff-archive.bat                         - �ϥιw�]�]�w
rem   create-diff-archive.bat changes.zip             - �ۭq��X�ɦW 
rem   create-diff-archive.bat -F changes.zip          - �ϥΨ�W�Ѽƫ��w��X�ɦW
rem   create-diff-archive.bat -S main -T dev          - �ۭq������M�ؼФ���
rem   create-diff-archive.bat -F changes.zip -S main -T dev - �ۭq�Ҧ��Ѽ�
rem ===================================================

rem �ˬd�O�_�������ШD
if "%~1"=="--help" goto :showhelp
if "%~1"=="/?" goto :showhelp

rem �ˬd�O�_�b Git �s�x�w������
git rev-parse --is-inside-work-tree >nul 2>&1
if %errorlevel% neq 0 (
    echo ���~: �Цb Git �s�x�w�ڥؿ������榹�妸��!
    exit /b 1
)

rem �]�w�w�]�ܼ�
set OUTPUT_ARCHIVE=APP_SIT
set SOURCE_BRANCH=master
set TARGET_BRANCH=SIT

rem �B�z�R�O��Ѽ� - �䴩��W�ѼƮ榡
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

rem �°ѼƮ榡���ݮe�ʳB�z
if not "%~1"=="" set OUTPUT_ARCHIVE=%~1
if not "%~2"=="" set SOURCE_BRANCH=%~2
if not "%~3"=="" set TARGET_BRANCH=%~3
goto :args_done

:args_done
rem �������ɦW
set FILE_EXT=%OUTPUT_ARCHIVE:~-4%
if not "%FILE_EXT%"==".zip" if not "%FILE_EXT%"==".ZIP" set OUTPUT_ARCHIVE=%OUTPUT_ARCHIVE%.zip

rem �ϥ� echo ��ܰT���H²�ƿ�X
echo ��X�ɮ�: %OUTPUT_ARCHIVE%
echo ������: %SOURCE_BRANCH%
echo �ؼФ���: %TARGET_BRANCH%

rem �ϥΨt���{�ɥؿ�
set TEMP_DIR=%TEMP%\git_archive_%RANDOM%

rem �Ы��{�ɥؿ�
mkdir "%TEMP_DIR%" 2>nul
echo �Ы��{�ɥؿ�: %TEMP_DIR%

rem �T�� Git ���|��q�A�H�K���T�B�z�����ɮצW
git config --local core.quotepath false
rem �b����ɮײM��e�ˬd������M�ؼФ���O�_�s�b
echo �ˬd����O�_�s�b...

rem �ˬd������O�_�s�b
git rev-parse --verify %SOURCE_BRANCH% >nul 2>&1
if %errorlevel% neq 0 (
    echo ���~^: ������ %SOURCE_BRANCH% ���s�b!
    goto cleanup
)

rem �ˬd�ؼФ���O�_�s�b
git rev-parse --verify %TARGET_BRANCH% >nul 2>&1
if %errorlevel% neq 0 (
    echo ���~^: �ؼФ��� %TARGET_BRANCH% ���s�b!
    goto cleanup
)
rem ����ɮײM����{���ɮ� (UTF-8 �s�X)
echo ���b���o�ܧ��ɮײM��...
git diff-tree -r --name-only --diff-filter=ACMRT %SOURCE_BRANCH% %TARGET_BRANCH% > "%TEMP_DIR%\filelist_utf8.txt"

rem �N UTF-8 �s�X���ɮײM���ഫ�� BIG5 �s�X
echo ���b�ഫ�ɮײM��s�X ^(UTF^-8 ^�� BIG5^)...
powershell -Command "$content = Get-Content -Path '%TEMP_DIR%\filelist_utf8.txt' -Encoding UTF8; [System.IO.File]::WriteAllLines('%TEMP_DIR%\filelist.txt', $content, [System.Text.Encoding]::GetEncoding(950))"

rem �ˬd�ɮײM��O�_����
for %%I in ("%TEMP_DIR%\filelist.txt") do if %%~zI==0 (
    echo �S���o�{�ɮ��ܧ�A�����B�z�C
    goto cleanup
)

rem ����`�ɮ׼ƶq
echo �p���ɮ��`��...
for /f %%A in ('type "%TEMP_DIR%\filelist.txt" ^| find /c /v ""') do set total_files=%%A
echo �@�o�{ %total_files% ���ܧ��ɮ�

rem ��l���ɮ׭p�ƾ�
set file_count=0

rem �����ɮר��{�ɥؿ�
echo ���b�q %TARGET_BRANCH% ���䴣���ɮ�...

rem �O�s��e����W��
for /f "tokens=*" %%b in ('git rev-parse --abbrev-ref HEAD') do set CURRENT_BRANCH=%%b
echo ��e����: %CURRENT_BRANCH%

rem �ˬd�u�@�ϬO�_���b�]�u�Ω󴣥ܡ^
git diff --quiet
if %errorlevel% neq 0 (
    echo ĵ�i: �u�@�Ϧ������檺�ܧ�A���o���|�v�T�ɮ״����C
)

rem �v��Ū���ɮײM��óB�z
for /F "usebackq tokens=*" %%f in ("%TEMP_DIR%\filelist.txt") do (
    rem �W�[�p�ƾ�
    set /a file_count+=1
    
    rem �]�m�ؼ��ɮ׸��|
    set "target_file=!TEMP_DIR!\%%f"
    
    rem �Ыإؼ��ɮת����ؿ�
    set "target_dir=!target_file:~0,-1!"
    for %%i in ("!target_dir!") do set "parent_dir=%%~dpi"
    if not exist "!parent_dir!" mkdir "!parent_dir!" 2>nul
    
    rem �q�ؼФ��䴣���ɮפ��e
    git cat-file -p %TARGET_BRANCH%:"%%f" > "!target_file!" 2>nul
    if !errorlevel! neq 0 (
        echo ^(!file_count!^/%total_files%^) ĵ�i^: �L�k�����ɮ� %%f
    ) else (
        echo ^(!file_count!^/%total_files%^) ����^: %%f
    )
)

rem filepath: d:\LAB\Git-Tools\archive_changes\create-diff-archive_line_end_style_DOS.bat
rem �ഫ�Ҧ��奻�ɮת������ (Unix LF -> DOS CRLF)
echo ���b�ഫ��r�ɮ״���� ^(Unix -^> DOS^)...

rem �إ�²�ƪ��� PowerShell �}��
echo $fileTypes = @('.txt','.xml','.html','.htm','.css','.js','.java','.cs','.cpp','.h','.c','.php','.py','.bat','.cmd','.ps1','.json','.config','.yml','.yaml','.md','.sql') > "%TEMP_DIR%\convert.ps1"
echo $count = 0 >> "%TEMP_DIR%\convert.ps1"
echo $errorCount = 0 >> "%TEMP_DIR%\convert.ps1"
echo $changedCount = 0 >> "%TEMP_DIR%\convert.ps1"
echo $files = Get-ChildItem -Path '%TEMP_DIR%' -Recurse -File ^| Where-Object { $fileTypes -contains $_.Extension.ToLower() } >> "%TEMP_DIR%\convert.ps1"
echo Write-Host "���" $files.Count "�ӥi�઺��r�ɮ׻ݭn�ˬd" >> "%TEMP_DIR%\convert.ps1"
echo foreach($file in $files) { >> "%TEMP_DIR%\convert.ps1"
echo   try { >> "%TEMP_DIR%\convert.ps1"
echo     $count++ >> "%TEMP_DIR%\convert.ps1"
echo     $content = [System.IO.File]::ReadAllText($file.FullName) >> "%TEMP_DIR%\convert.ps1"
echo     if ($content -match "[^\r]\n") { >> "%TEMP_DIR%\convert.ps1"
echo       $newContent = $content -replace "([^\r])\n", "`$1`r`n" >> "%TEMP_DIR%\convert.ps1"
echo       [System.IO.File]::WriteAllText($file.FullName, $newContent) >> "%TEMP_DIR%\convert.ps1"
echo       $changedCount++ >> "%TEMP_DIR%\convert.ps1"
echo       if ($changedCount %% 10 -eq 0) { >> "%TEMP_DIR%\convert.ps1"
echo         Write-Host "�w�ഫ $changedCount ���ɮ�..." >> "%TEMP_DIR%\convert.ps1"
echo       } >> "%TEMP_DIR%\convert.ps1"
echo     } else { >> "%TEMP_DIR%\convert.ps1"
echo       Write-Host "�ɮ� $($file.Name) �w�g�O CRLF �榡�A�����ഫ" -ForegroundColor Green >> "%TEMP_DIR%\convert.ps1"
echo     } >> "%TEMP_DIR%\convert.ps1"
echo   } catch { >> "%TEMP_DIR%\convert.ps1"
echo     $errorCount++ >> "%TEMP_DIR%\convert.ps1"
echo   } >> "%TEMP_DIR%\convert.ps1"
echo } >> "%TEMP_DIR%\convert.ps1"
echo Write-Host "�ˬd�����I�@�ˬd�F $count ���ɮסA�ഫ�F $changedCount ���ɮת�����šC(���~: $errorCount ��)" >> "%TEMP_DIR%\convert.ps1"

rem ���� PowerShell �}��
powershell -ExecutionPolicy Bypass -Command "& '%TEMP_DIR%\convert.ps1'"

rem �R���{�ɸ}��
del "%TEMP_DIR%\convert.ps1" >nul 2>&1

rem �R���{���� zip �ɮ�(�p�G�s�b)
if exist "%OUTPUT_ARCHIVE%" del "%OUTPUT_ARCHIVE%"

rem �ϥ� PowerShell �Ы� ZIP �ɮ�
echo ���b�Ы� ZIP �ɮ� %OUTPUT_ARCHIVE%...
powershell -Command "Compress-Archive -Path '%TEMP_DIR%\*' -DestinationPath '%OUTPUT_ARCHIVE%' -Force"

echo ����! �w�Ы� %OUTPUT_ARCHIVE%

rem �b�M�z�e�ͦ��`�����i
echo.
echo ===================================
echo            �����`�����i            
echo ===================================
echo.
rem ��� Repository ��T
for /f "tokens=*" %%r in ('git config --get remote.origin.url') do set repo_url=%%r
for /f "tokens=*" %%n in ('git rev-parse --show-toplevel') do set repo_root=%%n
rem ���}�������W�١A�קK�ϥ� || �B���
git symbolic-ref --short HEAD >"%TEMP_DIR%\branch.tmp" 2>nul
if %errorlevel% neq 0 (
    git rev-parse HEAD >"%TEMP_DIR%\branch.tmp"
)
set /p current_branch=<"%TEMP_DIR%\branch.tmp"
for /f "tokens=*" %%c in ('git rev-parse HEAD') do set current_commit=%%c


echo Repository ��T:
echo   ���a���|: !repo_root!
echo   ���� URL: !repo_url!
echo   ��e����: !current_branch!
echo   ��e����: !current_commit:~0,8!

rem �s�W�P�B��T�϶�
echo.
echo �P�B��T:
set "last_fetch_time=����"
set "last_pull_time=����"
set "has_pull_time=false"

rem �ˬd�̫�@�� fetch �ɶ�
if exist ".git\FETCH_HEAD" (
    for /f "tokens=*" %%t in ('powershell -Command "Get-Item '.git\FETCH_HEAD' | Select-Object -ExpandProperty LastWriteTime"') do (
        set "last_fetch_time=%%t"
    )
)

rem �ˬd�̫�@�� pull �ɶ� 
if exist ".git\ORIG_HEAD" (
    for /f "tokens=*" %%p in ('powershell -Command "Get-Item '.git\ORIG_HEAD' | Select-Object -ExpandProperty LastWriteTime"') do (
        set "last_pull_time=%%p"
        set "has_pull_time=true"
    )
)

echo   �̫� Fetch �ɶ�: !last_fetch_time!
echo   �̫� Pull �ɶ�: !last_pull_time!

rem �p�����ܮɶ��t
powershell -Command "$fetchTime = (Get-Item '.git\FETCH_HEAD' -ErrorAction SilentlyContinue).LastWriteTime; if($fetchTime) { $diff = (Get-Date) - $fetchTime; Write-Host '   Fetch �Z��: ' $diff.Days '��' $diff.Hours '�p��' $diff.Minutes '�����e' }"

if "!has_pull_time!"=="true" (
    powershell -Command "$pullTime = (Get-Item '.git\ORIG_HEAD' -ErrorAction SilentlyContinue).LastWriteTime; if($pullTime) { $diff = (Get-Date) - $pullTime; Write-Host '   Pull �Z��: ' $diff.Days '��' $diff.Hours '�p��' $diff.Minutes '�����e' }"
) else (
    echo   Pull �Z��: �L�k�T�w
)

echo.
echo ���]��T:
echo   ������: %SOURCE_BRANCH%
echo   �ؼФ���: %TARGET_BRANCH%
echo   �ɮ��`��: %total_files%
echo   ���\����: !file_count!
if exist "%OUTPUT_ARCHIVE%" (
    rem ����ɮק�����|
    for %%I in ("%OUTPUT_ARCHIVE%") do (
        set zip_size=%%~zI
        set zip_full_path=%%~fI
        set zip_date=%%~tI
    )
    set /a zip_size_kb=!zip_size!/1024
    echo   ��X�ɮ�: %OUTPUT_ARCHIVE% ^(!zip_size_kb! KB^)
    echo   ������|: !zip_full_path!
    echo   �ɮ׮ɶ�: !zip_date!
    echo   �ɮ�����: ZIP ���Y�� ^(�]�t !file_count! ���ɮ�^)
    echo.
    echo   �� ���Y�ɤw�إߧ����A�i�����ϥΡC
    echo   �� �p�ݬd�ݤ��e�A�i�z�L�ɮ��`�ީθ����Y�u��}���ɮסC
) else (
    echo   ��X�ɮ�: ���إ�
    echo   ��]: �i��O�b�B�z�L�{���o�Ϳ��~�ΨϥΪ̤��_�ާ@�C
)

echo �ާ@�����ɶ�: %date% %time%
echo ===================================
echo.
echo �}�o��T:
echo   �D�n�}�o: Robbie Lee
echo   �̫�ק�ɶ�: 2025-04-26
echo.
echo   �ԲӨϥλ���:
echo   create-diff-archive.bat --help
echo   ��
echo   create-diff-archive.bat /?
echo.

goto cleanup

:showhelp
echo.
echo Git �ܧ��ɮץ��]�u��
echo =====================
echo.
echo �N��Ӥ��䶡���t���ɮץ��]�����Y�ɡA�ѨM�R�O��Ѽƪ��׭�����D�C
echo.
echo �y�k:
echo   create-diff-archive.bat [��X�ɦW] [������] [�ؼФ���]
echo   ��
echo   create-diff-archive.bat -F [��X�ɦW] -S [������] -T [�ؼФ���]
echo.
echo �Ѽ�:
echo   -F [��X�ɦW]   - ���Y���ɮצW�١A���ɦW�����Y���w�M�w (�w�]: APP_SIT.zip)
echo   -S [������]     - �������Ǥ��� (�w�]: master)
echo   -T [�ؼФ���]   - ������ؼФ��� (�w�]: SIT)
echo.
echo �d��:
echo   create-diff-archive.bat                         - �ϥιw�]�]�w
echo   create-diff-archive.bat changes.zip             - �ۭq��X�ɦW
echo   create-diff-archive.bat -F changes.zip          - �ϥΨ�W�Ѽƫ��w��X�ɦW
echo   create-diff-archive.bat -S main -T dev          - �ۭq������M�ؼФ���
echo   create-diff-archive.bat -F changes.zip -S main -T dev - �ۭq�Ҧ��Ѽ�
echo.
exit /b 0

:cleanup
rem �M�z�{���ɮשM�ؿ�
echo �M�z�{���ɮ�...
rmdir /S /Q "%TEMP_DIR%" 2>nul

endlocal