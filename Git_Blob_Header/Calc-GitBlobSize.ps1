<#
.SYNOPSIS
    �p���ɮפj�p�ü��� Git Blob �榡�� header �j�p�p��
.DESCRIPTION
    ���}�������@���ɮ׸��|�A�M��p����ɮפj�p�ι����� Git Blob �榡 header �j�p
.PARAMETER FilePath
    �n�p��j�p���ɮ׸��|
.EXAMPLE
    .\Calc-GitBlobSize.ps1 -FilePath C:\path\to\image.png
#>

param (
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [string]$FilePath
)

# �]�w��e����ɶ��]�ϥ� UTC �ɶ��^
$currentDateTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$currentUTC = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss")

# �����e�Τ�
$currentUser = $env:USERNAME

# ����ɮ׸�T
$fileInfo = Get-Item -Path $FilePath
$fileName = $fileInfo.Name
$filePath = $fileInfo.FullName
$fileSize = $fileInfo.Length
$fileModified = $fileInfo.LastWriteTime

# �إ��{�ɥؿ�
$tempDir = Join-Path $env:TEMP "git_blob_calc_$([Guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

# �إ� Git Blob Header
$blobHeader = "blob $fileSize" + [char]0
$headerPath = Join-Path $tempDir "blob_header.bin"
[System.IO.File]::WriteAllBytes($headerPath, [System.Text.Encoding]::UTF8.GetBytes($blobHeader))

# �p�� Header �j�p
$headerSize = (Get-Item -Path $headerPath).Length

# �X�� Header �P�ɮס]�b PowerShell ���u��j�p�A����ڦX�֡^
$totalSize = $headerSize + $fileSize

# ����ɮ׸�T
Write-Host "`n=== �ɮ׸�T (�p��ɶ�: $currentDateTime) ===" -ForegroundColor Cyan
Write-Host
Write-Host "�ɮצW��: $fileName"
Write-Host "�ɮ׸��|: $filePath"
Write-Host "�ɮפj�p: $fileSize bytes"
Write-Host "�ק�ɶ�: $fileModified"
Write-Host "���a�ɶ�: $currentDateTime"
Write-Host "UTC �ɶ�: $currentUTC"
Write-Host

# ��� Git Blob ��T
Write-Host "=== Git Blob �j�p�p�⵲�G ===" -ForegroundColor Cyan
Write-Host
Write-Host "Blob Header: 'blob $fileSize\0'"
Write-Host "Header �j�p: $headerSize bytes"
Write-Host "���� Blob �j�p: $totalSize bytes"
Write-Host "�إߪ�: $currentUser"
Write-Host

# ���Ū�� Header �ɮץH��ܽT�����e
$headerContent = [System.IO.File]::ReadAllBytes($headerPath)
$headerString = [System.Text.Encoding]::UTF8.GetString($headerContent)
$headerHex = [BitConverter]::ToString($headerContent).Replace("-", " ")

Write-Host "=== Header �ԲӸ�T ===" -ForegroundColor Green
Write-Host
Write-Host "��r���e: " -NoNewline
$headerContent | ForEach-Object {
    if ($_ -eq 0) { 
        Write-Host "\0" -NoNewline -ForegroundColor Yellow
    } else {
        Write-Host ([char]$_) -NoNewline 
    }
}
Write-Host
Write-Host "�Q���i��: $headerHex"
Write-Host

# �M�z�{���ɮ�
Remove-Item -Path $tempDir -Recurse -Force

# �p�G�n��ګإߧ��㪺 Blob ���� (�i�ﳡ���A�w�`��)
<#
# �إߧ��㪺 Blob ����]Header + �ɮפ��e�^
$fullBlobPath = Join-Path $tempDir "full_blob.bin"
$headerBytes = [System.IO.File]::ReadAllBytes($headerPath)
$fileBytes = [System.IO.File]::ReadAllBytes($FilePath)
$fullBlob = New-Object byte[] ($headerBytes.Length + $fileBytes.Length)
[Array]::Copy($headerBytes, 0, $fullBlob, 0, $headerBytes.Length)
[Array]::Copy($fileBytes, 0, $fullBlob, $headerBytes.Length, $fileBytes.Length)
[System.IO.File]::WriteAllBytes($fullBlobPath, $fullBlob)

# �p���ڤj�p������
$actualSize = (Get-Item -Path $fullBlobPath).Length
if ($actualSize -eq $totalSize) {
    Write-Host "���ҵ��G: ���\ - �ɮפj�p�p�⥿�T" -ForegroundColor Green
} else {
    Write-Host "���ҵ��G: ���� - �j�p���@�P�I" -ForegroundColor Red
    Write-Host "  �w��: $totalSize bytes"
    Write-Host "  ���: $actualSize bytes"
}
#>