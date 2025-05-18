@echo off
setlocal enabledelayedexpansion

REM === �����e����ɶ� ===
for /f "tokens=2 delims==" %%a in ('wmic OS Get LocalDateTime /value') do set dt=%%a
set YEAR=%dt:~0,4%
set MONTH=%dt:~4,2%
set DAY=%dt:~6,2%
set HOUR=%dt:~8,2%
set MINUTE=%dt:~10,2%
set SECOND=%dt:~12,2%
set CURRENT_DATETIME=%YEAR%-%MONTH%-%DAY% %HOUR%:%MINUTE%:%SECOND%

REM === �ˬd�Ѽ� ===
if "%~1"=="" (
    echo ���~: �ʤ��ɮ׸��|�ѼơI
    echo �Ϊk: CalcFileSize.bat [�ɮ׸��|]
    echo �d��: CalcFileSize.bat C:\path\to\image.png
    exit /b 1
)

REM === �ˬd�ɮ׬O�_�s�b ===
if not exist "%~1" (
    echo ���~: �ɮ� "%~1" ���s�b�I
    exit /b 2
)

REM === �p���ɮ׸�T ===
for %%A in ("%~1") do (
    set FILE_PATH=%%~fA
    set FILE_NAME=%%~nxA
    set FILE_SIZE=%%~zA
    set FILE_DATE=%%~tA
)

REM === �إ��{�ɥؿ� ===
set TEMP_DIR=%TEMP%\file_size_calc_%RANDOM%
mkdir "%TEMP_DIR%" 2>nul

REM === �ϥ� set /p �إ� blob header ===
set /p="blob %FILE_SIZE%"<nul> "%TEMP_DIR%\blob_header.bin"
echo.>> "%TEMP_DIR%\blob_header.bin"

REM === �p�� header �ɮפj�p ===
for %%A in ("%TEMP_DIR%\blob_header.bin") do set HEADER_SIZE=%%~zA

REM === �X�� header �P�ɮ� ===
copy /b "%TEMP_DIR%\blob_header.bin"+"%FILE_PATH%" "%TEMP_DIR%\full_blob.bin" > nul

REM === �p��X���ɮפj�p ===
for %%A in ("%TEMP_DIR%\full_blob.bin") do set TOTAL_SIZE=%%~zA

REM === ����ɮ׫H�� ===
echo.
echo === �ɮ׸�T (�p��ɶ�: %CURRENT_DATETIME%) ===
echo.
echo �ɮצW��: %FILE_NAME%
echo �ɮ׸��|: %FILE_PATH%
echo �ɮפj�p: %FILE_SIZE% bytes
echo �ק�ɶ�: %FILE_DATE%
echo.

REM === ��� Git Blob ��T ===
echo === Git Blob �j�p�p�⵲�G ===
echo.
echo Blob Header: 'blob %FILE_SIZE%\0'
echo Header �j�p: %HEADER_SIZE% bytes
echo ���� Blob �j�p: %TOTAL_SIZE% bytes
echo �إߪ�: %USERNAME%
echo.

REM === �T�{�j�p�p�⥿�T�� ===
set /a EXPECTED_SIZE=%FILE_SIZE% + %HEADER_SIZE%
if %TOTAL_SIZE% EQU %EXPECTED_SIZE% (
    echo ���ҵ��G: ���\ - �ɮפj�p�p�⥿�T
) else (
    echo ���ҵ��G: ���� - �j�p���@�P�I
    echo   �w���`�j�p: %EXPECTED_SIZE% bytes
    echo   ����`�j�p: %TOTAL_SIZE% bytes
)

REM === �M�z�{���ɮ� ===
rd /s /q "%TEMP_DIR%" 2>nul

exit /b 0