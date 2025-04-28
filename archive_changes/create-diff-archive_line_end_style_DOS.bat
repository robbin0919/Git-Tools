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

rem ===== ��i���P�B�\�� =====
echo.
echo ===================================
echo      �P����Repository�P�B��...      
echo ===================================
echo.

rem �x�s�ثe����W�١A�y��|��^������
for /f "tokens=*" %%b in ('git rev-parse --abbrev-ref HEAD') do set ORIGINAL_BRANCH=%%b
echo ��e�u�@����: %ORIGINAL_BRANCH%

rem �ˬd�u�@�ϬO�_���b
git diff --quiet
set GIT_CLEAN_WORKSPACE=%errorlevel%
if %GIT_CLEAN_WORKSPACE% neq 0 (
    echo ĵ�i: �����u�@�Ϧ������檺�ܧ�A�N�b�P�B���٭�C
    git stash push -m "�۰ʼȦs�� %date% %time%" >nul 2>&1
)

rem ������Ҧ����ݤ����T
echo ���b������ݤ����T...
git remote update origin --prune
set GIT_REMOTE_ERROR=%errorlevel%
if %GIT_REMOTE_ERROR% neq 0 (
    echo ĵ�i: �L�k�s�����ݭܮw (���~�X: %GIT_REMOTE_ERROR%)
    echo �i���]: �������D�BVPN���s���λ��ݦ��A���ȮɵL�k�X��
    
    rem �ˬd�O�_�ܤ֦����a����i��
    git rev-parse --verify %SOURCE_BRANCH% >nul 2>&1
    set LOCAL_SOURCE_EXISTS=%errorlevel%
    git rev-parse --verify %TARGET_BRANCH% >nul 2>&1
    set LOCAL_TARGET_EXISTS=%errorlevel%
    
    if %LOCAL_SOURCE_EXISTS% neq 0 (
        echo �Y�����~: ������ %SOURCE_BRANCH% ���s�b�󥻦a�A�B�L�k�q��������C
        echo �ާ@�L�k�~��A���ˬd����W�٬O�_���T�Ϋ�_�����s���᭫�աC
        goto cleanup
    )
    
    if %LOCAL_TARGET_EXISTS% neq 0 (
        echo �Y�����~: �ؼФ��� %TARGET_BRANCH% ���s�b�󥻦a�A�B�L�k�q��������C
        echo �ާ@�L�k�~��A���ˬd����W�٬O�_���T�Ϋ�_�����s���᭫�աC
        goto cleanup
    )
    
    echo �N�~��ϥΥ��a�����i�����A�p�ݳ̷s�����нT�O�����s����A������C
    
    rem ���L�P�B�����i����
    goto skip_sync
) else (
    echo ���\������ݤ����T�C
    
    rem �ˬd�æP�B������
    echo.
    echo ���b�ˬd������ %SOURCE_BRANCH%...
    
    rem ���ˬd���a����O�_�s�b
    git rev-parse --verify %SOURCE_BRANCH% >nul 2>&1
    set LOCAL_SOURCE_EXISTS=%errorlevel%
    
    rem �ˬd���ݤ���O�_�s�b
    git rev-parse --verify origin/%SOURCE_BRANCH% >nul 2>&1
    set REMOTE_SOURCE_EXISTS=%errorlevel%
    
    if %LOCAL_SOURCE_EXISTS% neq 0 (
        if %REMOTE_SOURCE_EXISTS% equ 0 (
            echo ������ %SOURCE_BRANCH% ���s�b�󥻦a���s�b�󻷺ݡA���b�Ы�...
            git checkout -b %SOURCE_BRANCH% origin/%SOURCE_BRANCH%
            if %errorlevel% equ 0 (
                echo ���\�Ыبä����ܷ����� %SOURCE_BRANCH%
            ) else (
                echo ĵ�i: �L�k�Ыط����� %SOURCE_BRANCH%�A�N�~��ϥλ��ݪ����i�����C
            )
        ) else (
            echo ĵ�i: ������ %SOURCE_BRANCH% ���s�b�󥻦a�]���s�b�󻷺ݡC
        )
    ) else (
        echo ������ %SOURCE_BRANCH% �s�b�󥻦a�A���b�P�B...
        git checkout %SOURCE_BRANCH% >nul 2>&1
        git pull origin %SOURCE_BRANCH% --ff-only
        if %errorlevel% neq 0 (
            echo ĵ�i: �L�k�ϥΧֳt�e�i�X�֤覡��s %SOURCE_BRANCH%�A���ե��`�X��...
            git pull origin %SOURCE_BRANCH%
        )
    )
    
    rem �ˬd�æP�B�ؼФ���
    echo.
    echo ���b�ˬd�ؼФ��� %TARGET_BRANCH%...
    
    rem ���ˬd���a����O�_�s�b
    git rev-parse --verify %TARGET_BRANCH% >nul 2>&1
    set LOCAL_TARGET_EXISTS=%errorlevel%
    
    rem �ˬd���ݤ���O�_�s�b
    git rev-parse --verify origin/%TARGET_BRANCH% >nul 2>&1
    set REMOTE_TARGET_EXISTS=%errorlevel%
    
    if %LOCAL_TARGET_EXISTS% neq 0 (
        if %REMOTE_TARGET_EXISTS% equ 0 (
            echo �ؼФ��� %TARGET_BRANCH% ���s�b�󥻦a���s�b�󻷺ݡA���b�Ы�...
            git checkout -b %TARGET_BRANCH% origin/%TARGET_BRANCH%
            if %errorlevel% equ 0 (
                echo ���\�Ыبä����ܥؼФ��� %TARGET_BRANCH%
            ) else (
                echo ĵ�i: �L�k�ЫإؼФ��� %TARGET_BRANCH%�A�N�~��ϥλ��ݪ����i�����C
            )
        ) else (
            echo ĵ�i: �ؼФ��� %TARGET_BRANCH% ���s�b�󥻦a�]���s�b�󻷺ݡC
        )
    ) else (
        echo �ؼФ��� %TARGET_BRANCH% �s�b�󥻦a�A���b�P�B...
        git checkout %TARGET_BRANCH% >nul 2>&1
        git pull origin %TARGET_BRANCH% --ff-only
        if %errorlevel% neq 0 (
            echo ĵ�i: �L�k�ϥΧֳt�e�i�X�֤覡��s %TARGET_BRANCH%�A���ե��`�X��...
            git pull origin %TARGET_BRANCH%
        )
    )
    
    rem ��^�쥻������
    echo.
    echo ��^��l�u�@����: %ORIGINAL_BRANCH%
    git checkout %ORIGINAL_BRANCH% >nul 2>&1
    
    rem �p�G�쥻���Ȧs�ܧ�A�٭줧
    if %GIT_CLEAN_WORKSPACE% neq 0 (
        git stash pop >nul 2>&1
        if %errorlevel% neq 0 (
            echo ĵ�i: �٭�Ȧs���ܧ󥢱ѡC�Ȧs���e���O�d�b stash ���C
        ) else (
            echo �w�٭�Ȧs���u�@���ܧ�C
        )
    )
)

:skip_sync
echo.
echo ===================================
echo        �P�B�����A�}�l����ɮ�       
echo ===================================
echo.
rem ===== �s�W�P�B�\�൲�� =====

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
        echo ^(!file_count!^/%total_files%^) ����^: [%TARGET_BRANCH%] %%f
    )
)

rem filepath: d:\LAB\Git-Tools\archive_changes\create-diff-archive_line_end_style_DOS.bat
rem �ഫ�Ҧ��奻�ɮת������ (Unix LF -> DOS CRLF)
echo ���b�ഫ��r�ɮ״���� ^(Unix -^> DOS^)...

rem �b�u�@�ؿ��إߧ��T�� PowerShell �}��
echo $fileTypes = @('.vw','.tps','.trg','.tab','.seq','.prc','.spc','.bdy','.fnc','.idx','.txt','.xml','.html','.htm','.css','.js','.java','.aspx','.cshtml','.cs','.vb','.cpp','.h','.c','.php','.py','.bat','.cmd','.ps1','.json','.config','.yml','.yaml','.md','.sql','.map','.csproj','.vbproj','.settings','.myapp','.sln') > "convert_eol.ps1"
echo $count = 0 >> "convert_eol.ps1"
echo $errorCount = 0 >> "convert_eol.ps1"
echo $changedCount = 0 >> "convert_eol.ps1"
echo $files = Get-ChildItem -Path '%TEMP_DIR%' -Recurse -File ^| Where-Object { $fileTypes -contains $_.Extension.ToLower() } >> "convert_eol.ps1"
echo Write-Host "���" $files.Count "�ӥi�઺��r�ɮ׻ݭn�ˬd" >> "convert_eol.ps1"
echo foreach($file in $files) { >> "convert_eol.ps1"
echo   try { >> "convert_eol.ps1"
echo     $count++ >> "convert_eol.ps1"
echo     # Ū���ɮפG�i��e >> "convert_eol.ps1"
echo     $bytes = [System.IO.File]::ReadAllBytes($file.FullName) >> "convert_eol.ps1"
echo     # �ˬd�O�_�ݭn�ഫ >> "convert_eol.ps1"
echo     $needConversion = $false >> "convert_eol.ps1"
echo     for($i = 0; $i -lt $bytes.Length - 1; $i++) { >> "convert_eol.ps1"
echo       if($bytes[$i] -eq 10 -and ($i -eq 0 -or $bytes[$i-1] -ne 13)) { >> "convert_eol.ps1"
echo         $needConversion = $true >> "convert_eol.ps1"
echo         break >> "convert_eol.ps1"
echo       } >> "convert_eol.ps1"
echo     } >> "convert_eol.ps1"
echo     if($needConversion) { >> "convert_eol.ps1"
echo       # �إ߷s���줸�հ}�C�i���ഫ >> "convert_eol.ps1"
echo       $newBytes = New-Object System.Collections.ArrayList >> "convert_eol.ps1"
echo       for($i = 0; $i -lt $bytes.Length; $i++) { >> "convert_eol.ps1"
echo         if($bytes[$i] -eq 10 -and ($i -eq 0 -or $bytes[$i-1] -ne 13)) { >> "convert_eol.ps1"
echo           [void]$newBytes.Add(13) # ���[�J CR >> "convert_eol.ps1"
echo         } >> "convert_eol.ps1"
echo         [void]$newBytes.Add($bytes[$i]) >> "convert_eol.ps1"
echo       } >> "convert_eol.ps1"
echo       # �����g�J�G�i���ơA�O�d�즳�S�� >> "convert_eol.ps1"
echo       [System.IO.File]::WriteAllBytes($file.FullName, $newBytes.ToArray()) >> "convert_eol.ps1"
echo       $changedCount++ >> "convert_eol.ps1"
echo       if($changedCount %% 10 -eq 0) { >> "convert_eol.ps1"
echo         Write-Host "�w�ഫ $changedCount ���ɮ�..." >> "convert_eol.ps1"
echo       } >> "convert_eol.ps1"
echo     } else { >> "convert_eol.ps1"
echo       Write-Host "�ɮ� $($file.FullName) �w�g�O CRLF �榡�A�����ഫ" -ForegroundColor Green >> "convert_eol.ps1"
echo     } >> "convert_eol.ps1"
echo   } catch { >> "convert_eol.ps1"
echo     $errorCount++ >> "convert_eol.ps1"
echo     Write-Host "�B�z�ɮ� $($file.Name) �ɵo�Ϳ��~: $_" -ForegroundColor Red >> "convert_eol.ps1"
echo   } >> "convert_eol.ps1"
echo } >> "convert_eol.ps1"
echo Write-Host "�ˬd�����I�@�ˬd�F $count ���ɮסA�ഫ�F $changedCount ���ɮת�����šC(���~: $errorCount ��)" >> "convert_eol.ps1"

rem ���� PowerShell �}��
powershell -ExecutionPolicy Bypass -File "convert_eol.ps1"

rem �R���{�ɸ}��
del "convert_eol.ps1" >nul 2>&1

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