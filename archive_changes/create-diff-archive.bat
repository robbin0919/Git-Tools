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
rem �@��: Your Name
rem ���: 2025-04-26
rem
rem �ϥΤ�k:
rem   create-diff-archive.bat [��X�ɦW] [������] [�ؼФ���]
rem
rem �Ѽ�:
rem   [��X�ɦW]   - ���Y���ɮצW�١A���ɦW�����Y���w�M�w (�w�]: APP_SIT.zip)
rem   [������]     - �������Ǥ��� (�w�]: master)
rem   [�ؼФ���]   - ������ؼФ��� (�w�]: SIT)
rem
rem �d��:
rem   create-diff-archive.bat                         - �ϥιw�]�]�w
rem   create-diff-archive.bat changes.zip             - �ۭq��X�ɦW
rem   create-diff-archive.bat changes.zip main        - �ۭq�ɦW�M������
rem   create-diff-archive.bat changes.zip main dev    - �ۭq�Ҧ��Ѽ�
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

rem �B�z�R�O��Ѽ�
if not "%~1"=="" set OUTPUT_ARCHIVE=%~1
if not "%~2"=="" set SOURCE_BRANCH=%~2
if not "%~3"=="" set TARGET_BRANCH=%~3

rem �������ɦW
set FILE_EXT=%~x1
if "%FILE_EXT%"=="" set OUTPUT_ARCHIVE=%OUTPUT_ARCHIVE%.zip

rem �ϥ� PowerShell ��ܤ���T���H�קK�ýX
powershell -Command "Write-Host '��X�ɮ�: %OUTPUT_ARCHIVE%' -ForegroundColor Cyan"
powershell -Command "Write-Host '������: %SOURCE_BRANCH%' -ForegroundColor Cyan"
powershell -Command "Write-Host '�ؼФ���: %TARGET_BRANCH%' -ForegroundColor Cyan"

rem �ϥΨt���{�ɥؿ�
set TEMP_DIR=%TEMP%\git_archive_%RANDOM%

rem �Ы��{�ɥؿ�
mkdir "%TEMP_DIR%" 2>nul
powershell -Command "Write-Host '�Ы��{�ɥؿ�: %TEMP_DIR%' -ForegroundColor Green"

rem �T�� Git ���|��q�A�H�K���T�B�z�����ɮצW
git config --local core.quotepath false

rem ����ɮײM����{���ɮ� (UTF-8 �s�X)
powershell -Command "Write-Host '���b���o�ܧ��ɮײM��...' -ForegroundColor Yellow"
git diff-tree -r --name-only --diff-filter=ACMRT %SOURCE_BRANCH% %TARGET_BRANCH% > "%TEMP_DIR%\filelist_utf8.txt"

rem �N UTF-8 �s�X���ɮײM���ഫ�� BIG5 �s�X
powershell -Command "Write-Host '���b�ഫ�ɮײM��s�X (UTF-8 �� BIG5)...' -ForegroundColor Yellow"
powershell -Command "$content = Get-Content -Path '%TEMP_DIR%\filelist_utf8.txt' -Encoding UTF8; [System.IO.File]::WriteAllLines('%TEMP_DIR%\filelist.txt', $content, [System.Text.Encoding]::GetEncoding(950))"

rem �ˬd�ɮײM��O�_����
for %%I in ("%TEMP_DIR%\filelist.txt") do if %%~zI==0 (
    powershell -Command "Write-Host '�S���o�{�ɮ��ܧ�A�����B�z�C' -ForegroundColor Red"
    goto cleanup
)

rem ����`�ɮ׼ƶq
powershell -Command "Write-Host '�p���ɮ��`��...' -ForegroundColor Yellow"
for /f %%A in ('type "%TEMP_DIR%\filelist.txt" ^| find /c /v ""') do set total_files=%%A
powershell -Command "Write-Host ('�@�o�{ ' + %total_files% + ' ���ܧ��ɮ�') -ForegroundColor Yellow"

rem ��l���ɮ׭p�ƾ�
set file_count=0

rem �����ɮר��{�ɥؿ�
powershell -Command "Write-Host '���b�q %TARGET_BRANCH% ���䴣���ɮ�...' -ForegroundColor Yellow"

rem �O�s��e����W��
for /f "tokens=*" %%b in ('git rev-parse --abbrev-ref HEAD') do set CURRENT_BRANCH=%%b
powershell -Command "Write-Host ('��e����: ' + '%CURRENT_BRANCH%') -ForegroundColor Cyan"

rem �ˬd�u�@�ϬO�_���b�]�u�Ω󴣥ܡ^
git diff --quiet
if %errorlevel% neq 0 (
    powershell -Command "Write-Host 'ĵ�i: �u�@�Ϧ������檺�ܧ�A���o���|�v�T�ɮ״����C' -ForegroundColor Yellow"
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

rem �R���{���� zip �ɮ�(�p�G�s�b)
if exist "%OUTPUT_ARCHIVE%" del "%OUTPUT_ARCHIVE%"

rem �ϥ� PowerShell �Ы� ZIP �ɮ�
echo ���b�Ы� ZIP �ɮ� %OUTPUT_ARCHIVE%...
powershell -Command "Compress-Archive -Path '%TEMP_DIR%\*' -DestinationPath '%OUTPUT_ARCHIVE%' -Force"

echo ����! �w�Ы� %OUTPUT_ARCHIVE%

goto cleanup

:showhelp
echo.
echo Git �ܧ��ɮץ��]�u��
echo =====================
echo.
echo �N��Ӥ��䶡���t���ɮץ��]�����Y�ɡA�ѨM�R�O��Ѽƪ��׭�����D�C
echo.
echo �y�k: create-diff-archive.bat [��X�ɦW] [������] [�ؼФ���]
echo.
echo �Ѽ�:
echo   [��X�ɦW]   - ���Y���ɮצW�١A���ɦW�����Y���w�M�w (�w�]: APP_SIT.zip)
echo   [������]     - �������Ǥ��� (�w�]: master)
echo   [�ؼФ���]   - ������ؼФ��� (�w�]: SIT)
echo.
echo �d��:
echo   create-diff-archive.bat                         - �ϥιw�]�]�w
echo   create-diff-archive.bat changes.zip             - �ۭq��X�ɦW
echo   create-diff-archive.bat changes.zip main        - �ۭq�ɦW�M������
echo   create-diff-archive.bat changes.zip main dev    - �ۭq�Ҧ��Ѽ�
echo.
exit /b 0

:cleanup
rem �M�z�{���ɮשM�ؿ�
echo �M�z�{���ɮ�...
rmdir /S /Q "%TEMP_DIR%" 2>nul

endlocal