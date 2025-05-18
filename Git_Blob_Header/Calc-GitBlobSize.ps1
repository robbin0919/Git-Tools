<#
.SYNOPSIS
    計算檔案大小並模擬 Git Blob 格式的 header 大小計算
.DESCRIPTION
    此腳本接受一個檔案路徑，然後計算該檔案大小及對應的 Git Blob 格式 header 大小
.PARAMETER FilePath
    要計算大小的檔案路徑
.EXAMPLE
    .\Calc-GitBlobSize.ps1 -FilePath C:\path\to\image.png
#>

param (
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [string]$FilePath
)

# 設定當前日期時間（使用 UTC 時間）
$currentDateTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$currentUTC = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss")

# 獲取當前用戶
$currentUser = $env:USERNAME

# 獲取檔案資訊
$fileInfo = Get-Item -Path $FilePath
$fileName = $fileInfo.Name
$filePath = $fileInfo.FullName
$fileSize = $fileInfo.Length
$fileModified = $fileInfo.LastWriteTime

# 建立臨時目錄
$tempDir = Join-Path $env:TEMP "git_blob_calc_$([Guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

# 建立 Git Blob Header
$blobHeader = "blob $fileSize" + [char]0
$headerPath = Join-Path $tempDir "blob_header.bin"
[System.IO.File]::WriteAllBytes($headerPath, [System.Text.Encoding]::UTF8.GetBytes($blobHeader))

# 計算 Header 大小
$headerSize = (Get-Item -Path $headerPath).Length

# 合併 Header 與檔案（在 PowerShell 中只算大小，不實際合併）
$totalSize = $headerSize + $fileSize

# 顯示檔案資訊
Write-Host "`n=== 檔案資訊 (計算時間: $currentDateTime) ===" -ForegroundColor Cyan
Write-Host
Write-Host "檔案名稱: $fileName"
Write-Host "檔案路徑: $filePath"
Write-Host "檔案大小: $fileSize bytes"
Write-Host "修改時間: $fileModified"
Write-Host "本地時間: $currentDateTime"
Write-Host "UTC 時間: $currentUTC"
Write-Host

# 顯示 Git Blob 資訊
Write-Host "=== Git Blob 大小計算結果 ===" -ForegroundColor Cyan
Write-Host
Write-Host "Blob Header: 'blob $fileSize\0'"
Write-Host "Header 大小: $headerSize bytes"
Write-Host "完整 Blob 大小: $totalSize bytes"
Write-Host "建立者: $currentUser"
Write-Host

# 實際讀取 Header 檔案以顯示確切內容
$headerContent = [System.IO.File]::ReadAllBytes($headerPath)
$headerString = [System.Text.Encoding]::UTF8.GetString($headerContent)
$headerHex = [BitConverter]::ToString($headerContent).Replace("-", " ")

Write-Host "=== Header 詳細資訊 ===" -ForegroundColor Green
Write-Host
Write-Host "文字內容: " -NoNewline
$headerContent | ForEach-Object {
    if ($_ -eq 0) { 
        Write-Host "\0" -NoNewline -ForegroundColor Yellow
    } else {
        Write-Host ([char]$_) -NoNewline 
    }
}
Write-Host
Write-Host "十六進位: $headerHex"
Write-Host

# 清理臨時檔案
Remove-Item -Path $tempDir -Recurse -Force

# 如果要實際建立完整的 Blob 物件 (可選部分，已注釋)
<#
# 建立完整的 Blob 物件（Header + 檔案內容）
$fullBlobPath = Join-Path $tempDir "full_blob.bin"
$headerBytes = [System.IO.File]::ReadAllBytes($headerPath)
$fileBytes = [System.IO.File]::ReadAllBytes($FilePath)
$fullBlob = New-Object byte[] ($headerBytes.Length + $fileBytes.Length)
[Array]::Copy($headerBytes, 0, $fullBlob, 0, $headerBytes.Length)
[Array]::Copy($fileBytes, 0, $fullBlob, $headerBytes.Length, $fileBytes.Length)
[System.IO.File]::WriteAllBytes($fullBlobPath, $fullBlob)

# 計算實際大小並驗證
$actualSize = (Get-Item -Path $fullBlobPath).Length
if ($actualSize -eq $totalSize) {
    Write-Host "驗證結果: 成功 - 檔案大小計算正確" -ForegroundColor Green
} else {
    Write-Host "驗證結果: 失敗 - 大小不一致！" -ForegroundColor Red
    Write-Host "  預期: $totalSize bytes"
    Write-Host "  實際: $actualSize bytes"
}
#>