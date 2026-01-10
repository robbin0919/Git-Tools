<#
.SYNOPSIS
    自動依據 CSV 順序合併 Git 分支，並產出 Markdown 報告。
    衝突策略：使用 "theirs" (傳入變更) 優先。
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$RepoPath,

    [Parameter(Mandatory=$true)]
    [string]$TargetBranch,

    [string]$BaseBranch = "master",

    [Parameter(Mandatory=$true)]
    [string]$CsvPath
)

# 強制設定輸出編碼為 UTF-8，確保 PowerShell 內部的字串處理正確
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 定義 Helper 函式來執行 Git 指令
function Run-GitCmd {
    param(
        [string]$Command,
        [string]$WorkingDir
    )
    
    # 定義暫存檔路徑
    $TempId = [Guid]::NewGuid().ToString()
    $OutFile = Join-Path $env:TEMP "git_out_$TempId.tmp"
    $ErrFile = Join-Path $env:TEMP "git_err_$TempId.tmp"

    try {
        # 將命令字串拆解為引數陣列，這是 Start-Process 要求的格式
        # 簡單的 Split 處理不了引號內的空白，這裡改用 Invoke-Expression 的方式稍微複雜，
        # 為了保持兼容性，我們手動解析或直接讓 git 處理。
        # 由於我們前面的呼叫都有格式化引數，這裡直接用 cmd /c wrapper 最簡單，
        # 能確保引號與參數被正確傳遞給 git。
        
        $ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
        $ProcessInfo.FileName = "cmd.exe"
        $ProcessInfo.Arguments = "/c git $Command > ""$OutFile"" 2> ""$ErrFile"""
        $ProcessInfo.WorkingDirectory = $WorkingDir
        $ProcessInfo.CreateNoWindow = $true
        $ProcessInfo.UseShellExecute = $false
        
        $Process = New-Object System.Diagnostics.Process
        $Process.StartInfo = $ProcessInfo
        $Process.Start() | Out-Null
        $Process.WaitForExit()

        $stdout = ""
        $stderr = ""

        if (Test-Path $OutFile) {
            $stdout = Get-Content $OutFile -Encoding UTF8 -Raw -ErrorAction SilentlyContinue
        }
        if (Test-Path $ErrFile) {
            $stderr = Get-Content $ErrFile -Encoding UTF8 -Raw -ErrorAction SilentlyContinue
        }

        return [PSCustomObject]@{
            ExitCode = $Process.ExitCode
            Output   = $stdout
            Error    = $stderr
        }
    }
    catch {
        return [PSCustomObject]@{
            ExitCode = -1
            Output   = ""
            Error    = "Execution Exception: $_"
        }
    }
    finally {
        # 清理暫存檔
        if (Test-Path $OutFile) { Remove-Item $OutFile -Force -ErrorAction SilentlyContinue }
        if (Test-Path $ErrFile) { Remove-Item $ErrFile -Force -ErrorAction SilentlyContinue }
    }
}

# --- 主程式開始 ---

$CurrentTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$ReportFileName = "Merge_Report_{0}_{1}.md" -f $TargetBranch, (Get-Date -Format 'yyyyMMdd_HHmmss')
$ReportPath = Join-Path -Path $RepoPath -ChildPath $ReportFileName

Write-Host ("[{0}] 開始執行自動合併流程..." -f $CurrentTime) -ForegroundColor Cyan
Write-Host ("倉庫路徑: {0}" -f $RepoPath)
Write-Host ("目標分支: {0} (基底: {1})" -f $TargetBranch, $BaseBranch)
Write-Host ("來源 CSV: {0}" -f $CsvPath)

# 1. 檢查路徑
if (-not (Test-Path "$RepoPath\.git")) {
    Write-Error ("路徑 {0} 不是有效的 Git 倉庫。" -f $RepoPath)
    exit 1
}

if (-not (Test-Path $CsvPath)) {
    Write-Error ("CSV 檔案不存在: {0}" -f $CsvPath)
    exit 1
}

# 2. 讀取 CSV
$BranchList = @()
try {
    # 讀取 CSV，嘗試使用 UTF8 (含 BOM) 讀取
    $Lines = Get-Content -Path $CsvPath -Encoding UTF8
    foreach ($Line in $Lines) {
        if (-not [string]::IsNullOrWhiteSpace($Line) -and -not $Line.StartsWith("#")) {
            # CSV 格式: JiraID, BranchName, Seq
            $Parts = $Line.Split(",")
            if ($Parts.Count -ge 2) {
                $BranchName = $Parts[1].Trim()
                if (-not [string]::IsNullOrWhiteSpace($BranchName)) {
                    $BranchList += $BranchName
                }
            }
        }
    }
}
catch {
    Write-Error ("讀取 CSV 失敗: {0}" -f $_)
    exit 1
}

if ($BranchList.Count -eq 0) {
    Write-Warning "CSV 中沒有讀取到任何分支名稱。"
    exit 0
}

# 初始化報告內容
$ReportContent = New-Object System.Collections.Generic.List[string]
$ReportContent.Add("# 自動合併報告 (Auto Merge Report)")
$ReportContent.Add( ("**執行時間:** {0}  " -f $CurrentTime) )
$ReportContent.Add( ("**目標分支:** ``{0}``  " -f $TargetBranch) )
$ReportContent.Add( ("**基底分支:** ``{0}``  " -f $BaseBranch) )
$ReportContent.Add( ("**倉庫位置:** ``{0}``  " -f $RepoPath) )
$ReportContent.Add("")
$ReportContent.Add("## 合併執行明細")
# 這裡使用格式化字串來避開直接在程式碼中寫入 | 符號
$Header = "| {0} | {1} | {2} | {3} | {4} |" -f "序號", "分支名稱 (Branch)", "合併結果 (Status)", "Commit Hash", "備註 (Notes)"
$Divider = "|:---:|:---|:---|:---|:---|"
$ReportContent.Add($Header)
$ReportContent.Add($Divider)

# 3. Git 環境準備
Write-Host "更新遠端分支資訊 (git fetch)..." -ForegroundColor Yellow
Run-GitCmd -Command "fetch --all --prune" -WorkingDir $RepoPath | Out-Null

# 切換到 Base 分支並更新
Write-Host ("切換至基底分支 {0}..." -f $BaseBranch)
Run-GitCmd -Command ("checkout {0}" -f $BaseBranch) -WorkingDir $RepoPath | Out-Null
Run-GitCmd -Command ("pull origin {0}" -f $BaseBranch) -WorkingDir $RepoPath | Out-Null

# 重置/建立目標分支
Write-Host ("建立/重置目標分支 {0}..." -f $TargetBranch)
Run-GitCmd -Command ("branch -D {0}" -f $TargetBranch) -WorkingDir $RepoPath | Out-Null
$Res = Run-GitCmd -Command ("checkout -b {0}" -f $TargetBranch) -WorkingDir $RepoPath
if ($Res.ExitCode -ne 0) {
    Write-Error ("建立分支失敗: {0}" -f $Res.Error)
    exit 1
}

# 4. 執行合併迴圈
$Index = 0
$CriticalError = $false

foreach ($BranchName in $BranchList) {
    $Index++
    Write-Host ("[{0}/{1}] 正在合併: {2} ..." -f $Index, $BranchList.Count, $BranchName) -NoNewline

    # 檢查遠端分支是否存在
    $CheckRemote = Run-GitCmd -Command ("rev-parse --verify origin/{0}" -f $BranchName) -WorkingDir $RepoPath
    if ($CheckRemote.ExitCode -ne 0) {
        Write-Host " [略過] (遠端分支不存在)" -ForegroundColor Red
        $Row = "| {0} | ``{1}`` | {2} | {3} | {4} |" -f $Index, $BranchName, "❌ 略過", "-", "遠端分支不存在"
        $ReportContent.Add($Row)
        continue
    }

    # 執行合併
    # 策略調整：先嘗試標準合併，若有衝突則記錄並使用 Theirs 解決
    $MergeMsg = "Auto-merge {0} into {1}" -f $BranchName, $TargetBranch
    
    # 1. 嘗試合併但不提交 (以便偵測衝突)
    $MergeCmd = 'merge origin/{0} --no-commit --no-ff' -f $BranchName
    $MergeRes = Run-GitCmd -Command $MergeCmd -WorkingDir $RepoPath

    $CommitHash = "-"
    $Note = ""
    $StatusIcon = "✅ 成功"

    if ($MergeRes.ExitCode -eq 0) {
        # --- 合併順利，無衝突 ---
        # 執行提交
        $CommitCmd = 'commit --no-edit -m "{0}"' -f $MergeMsg
        $CommitRes = Run-GitCmd -Command $CommitCmd -WorkingDir $RepoPath
        
        if ($CommitRes.ExitCode -eq 0) {
            $HashRes = Run-GitCmd -Command "rev-parse --short HEAD" -WorkingDir $RepoPath
            $CommitHash = $HashRes.Output.Trim()
            Write-Host (" [成功] ({0})" -f $CommitHash) -ForegroundColor Green
        } else {
            # 極少見情況：Merge 成功但 Commit 失敗 (例如沒有變更)
            $StatusIcon = "ℹ️ 無變更"
            $Note = "合併成功但無需提交 (No changes)"
            Write-Host " [無變更]" -ForegroundColor Cyan
        }
    }
    else {
        # --- 發生衝突 ---
        Write-Host " [衝突] 正在記錄並修復..." -ForegroundColor Yellow
        
        # 2. 取得衝突檔案清單
        $DiffRes = Run-GitCmd -Command "diff --name-only --diff-filter=U" -WorkingDir $RepoPath
        $ConflictFiles = $DiffRes.Output.Trim() -replace "`r`n", ", " -replace "`n", ", "
        
        if ([string]::IsNullOrWhiteSpace($ConflictFiles)) {
             $ConflictFiles = "Tree Conflict / Binary Conflict (無法列出詳細檔案)"
        }
        
        # 記錄到 Note
        $Note = "衝突檔案: " + $ConflictFiles
        
        # 3. 使用 Theirs 解決衝突
        # checkout --theirs . 會將所有 Unmerged 檔案的內容替換為對方版本
        Run-GitCmd -Command "checkout --theirs ." -WorkingDir $RepoPath | Out-Null
        Run-GitCmd -Command "add ." -WorkingDir $RepoPath | Out-Null
        
        # 4. 提交
        $CommitMsg = "{0} (Conflicts Resolved: Taken Theirs)" -f $MergeMsg
        $CommitCmd = 'commit --no-edit -m "{0}"' -f $CommitMsg
        $CommitRes = Run-GitCmd -Command $CommitCmd -WorkingDir $RepoPath
            
        if ($CommitRes.ExitCode -eq 0) {
            $HashRes = Run-GitCmd -Command "rev-parse --short HEAD" -WorkingDir $RepoPath
            $CommitHash = $HashRes.Output.Trim()
            $StatusIcon = "⚠️ 衝突解決"
            Write-Host ("    -> 已強制選用 Theirs 並提交 ({0})" -f $CommitHash) -ForegroundColor Cyan
        }
        else {
            $StatusIcon = "❌ 失敗"
            $Note = ("無法自動解決衝突: {0}" -f ($CommitRes.Error -replace '\n',' '))
            Write-Host "    -> 無法解決，中止合併" -ForegroundColor Red
            Run-GitCmd -Command "merge --abort" -WorkingDir $RepoPath | Out-Null
            $CriticalError = $true
        }
    }

    $Row = "| {0} | ``{1}`` | {2} | ``{3}`` | {4} |" -f $Index, $BranchName, $StatusIcon, $CommitHash, $Note
    $ReportContent.Add($Row)

    if ($CriticalError) {
        $ReportContent.Add("")
        $ReportContent.Add( ("> **警告**: 由於合併失敗，流程已中止於 ``{0}``，後續分支未執行。" -f $BranchName) )
        break
    }
}

# 5. 輸出報告 (UTF8 在 WinPS 5.1 即為 UTF-8 with BOM)
$ReportContent | Out-File -FilePath $ReportPath -Encoding UTF8
Write-Host "`n流程結束。" -ForegroundColor Green
Write-Host ("報告已產出: {0}" -f $ReportPath)
Write-Host "請通知 PM 與開發人員檢視該報告。"