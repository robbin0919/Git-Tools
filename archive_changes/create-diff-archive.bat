@echo off
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
set OUTPUT_ARCHIVE=APP_SIT.zip
set SOURCE_BRANCH=master
set TARGET_BRANCH=SIT

rem �B�z�R�O��Ѽ�
if not "%~1"=="" set OUTPUT_ARCHIVE=%~1
if not "%~2"=="" set SOURCE_BRANCH=%~2
if not "%~3"=="" set TARGET_BRANCH=%~3

rem �������ɦW
set FILE_EXT=%~x1
if "%FILE_EXT%"=="" set OUTPUT_ARCHIVE=%OUTPUT_ARCHIVE%.zip

echo ��X�ɮ�: %OUTPUT_ARCHIVE%
echo ������: %SOURCE_BRANCH%
echo �ؼФ���: %TARGET_BRANCH%

set TEMP_DIR=temp_archive_%RANDOM%

rem �Ы��{�ɥؿ�
mkdir %TEMP_DIR%
echo �Ы��{�ɥؿ�: %TEMP_DIR%

rem ����ɮײM����{���ɮ�
echo ���b���o�ܧ��ɮײM��...
git diff-tree -r --name-only --diff-filter=ACMRT %SOURCE_BRANCH% %TARGET_BRANCH% > filelist.txt

rem �ˬd�ɮײM��O�_����
for %%I in (filelist.txt) do if %%~zI==0 (
    echo �S���o�{�ɮ��ܧ�A�����B�z�C
    goto cleanup
)

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

rem �Τ@�ϥ� git cat-file �R�O�����ɮ� (��A�X�G�i���ɮ�)
for /F "tokens=*" %%f in (filelist.txt) do (
    rem �T�O�ؿ��s�b
    for %%d in ("!TEMP_DIR!\%%~pf") do if not exist "%%~d" mkdir "%%~d"
    
    rem �q�ؼФ��䴣���ɮפ��e (�ϥΤG�i��w������k)
    git cat-file -p %TARGET_BRANCH%:"%%f" > "!TEMP_DIR!\%%f"
    if !errorlevel! neq 0 echo ĵ�i: �L�k�����ɮ� %%f
)

rem �R���{���� zip �ɮ�(�p�G�s�b)
if exist %OUTPUT_ARCHIVE% del %OUTPUT_ARCHIVE%

rem �ϥ� PowerShell �Ы� ZIP �ɮ�
echo ���b�Ы� ZIP �ɮ� %OUTPUT_ARCHIVE%...
powershell -Command "Compress-Archive -Path '%TEMP_DIR%\*' -DestinationPath '%OUTPUT_ARCHIVE%'"

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
del filelist.txt
rmdir /S /Q %TEMP_DIR%

endlocal