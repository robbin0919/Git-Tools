<#
.SYNOPSIS
    自動依據 CSV 順序合併 Git 分支，並產出 Markdown 報告。
    衝突策略：使用 "theirs" (傳入變更) 優先。
#>

[CmdletBinding()]
param(
    [string]$RepoPath,

    [string]$TargetBranch,

    [string]$BaseBranch = "master",

    [string]$CsvPath,

    [switch]$Help,

    # 捕捉所有未被綁定的剩餘參數
    [Parameter(ValueFromRemainingArguments=$true)]
    $RemainingArgs
)

function Show-Usage {
    Write-Host "用法 (Usage):" -ForegroundColor Cyan
    Write-Host "    .\auto_merge_flow.ps1 -RepoPath <Git倉庫路徑> -TargetBranch <目標分支> -CsvPath <CSV清單路徑> [-BaseBranch <基底分支>]"
    Write-Host ""
    Write-Host "參數說明:"
    Write-Host "    -RepoPath      (必要) 本地 Git 倉庫的絕對路徑"
    Write-Host "    -TargetBranch  (必要) 合併後產出的目標分支名稱"
    Write-Host "    -CsvPath       (必要) 包含分支清單的 CSV 檔案路徑"
    Write-Host "    -BaseBranch    (選填) 基底分支名稱 (預設: master)"
    Write-Host "    -Help          顯示此說明"
    Write-Host ""
}

# 1. 檢查是否要求顯示說明
if ($Help) {
    Show-Usage
    exit 0
}

# 2. 檢查是否有未識別的多餘參數
if ($null -ne $RemainingArgs -and $RemainingArgs.Count -gt 0) {
    Write-Host ("錯誤：偵測到未識別的參數或值: {0}" -f ($RemainingArgs -join ", ")) -ForegroundColor Red
    Write-Host "請確認是否忘記加上參數名稱 (例如 -RepoPath)，或輸入了不支援的參數。"
    Write-Host ""
    Show-Usage
    exit 1
}

# 3. 檢查必要參數
if ([string]::IsNullOrWhiteSpace($RepoPath) -or [string]::IsNullOrWhiteSpace($TargetBranch) -or [string]::IsNullOrWhiteSpace($CsvPath)) {
    Write-Host "錯誤：缺少必要參數。" -ForegroundColor Red
    Write-Host ""
    Show-Usage
    exit 1
}

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
    Write-Host "你提供的 CSV 路徑好像不太對，我找不到這個檔案" -ForegroundColor Red
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
$ConflictDetails = New-Object System.Collections.Generic.List[string]  # 獨立儲存衝突詳情
$NetworkWarning = "" # 用於記錄網路/更新狀態

# 3. Git 環境準備
Write-Host "更新遠端分支資訊 (git fetch)..." -ForegroundColor Yellow
$FetchRes = Run-GitCmd -Command "fetch --all --prune" -WorkingDir $RepoPath
if ($FetchRes.ExitCode -ne 0) {
    Write-Host " [注意] 無法連接遠端伺服器進行更新 (可能處於離線狀態)。" -ForegroundColor Cyan
    Write-Host "        將嘗試使用本地現有的分支資訊繼續執行。" -ForegroundColor Cyan
    $NetworkWarning += "> ⚠️ **警告:** 無法連線至遠端 Git 伺服器 (Fetch failed)。此報告基於**本地快取**的舊代碼產生，可能不包含遠端最新變更。  `n"
}

# 切換到 Base 分支並更新
Write-Host ("切換至基底分支 {0}..." -f $BaseBranch)
Run-GitCmd -Command ("checkout {0}" -f $BaseBranch) -WorkingDir $RepoPath | Out-Null

$PullRes = Run-GitCmd -Command ("pull origin {0}" -f $BaseBranch) -WorkingDir $RepoPath
if ($PullRes.ExitCode -ne 0) {
    Write-Host (" [注意] 無法從遠端 pull {0} 的最新代碼，將使用本地版本。" -f $BaseBranch) -ForegroundColor Cyan
    $NetworkWarning += ("> ⚠️ **警告:** 無法更新基底分支 ``{0}`` (Pull failed)。使用本地舊版本進行合併。  `n" -f $BaseBranch)
}

# 檢查目標分支是否存在，若存在則記錄資訊
$CheckTarget = Run-GitCmd -Command ("rev-parse --verify {0}" -f $TargetBranch) -WorkingDir $RepoPath
$OldBranchInfo = ""

if ($CheckTarget.ExitCode -eq 0) {
    # 分支存在，收集資訊
    $OldHash = $CheckTarget.Output.Trim().Substring(0, 7)
    # 取得最後提交時間
    # 使用 --date=iso 避免格式化字串在 Shell 傳遞時的問題
    $OldTimeRes = Run-GitCmd -Command ("log -1 --format=%cd --date=iso {0}" -f $TargetBranch) -WorkingDir $RepoPath
    $OldTime = "未知時間"
    if (-not [string]::IsNullOrEmpty($OldTimeRes.Output)) {
        $OldTime = $OldTimeRes.Output.Trim()
    }
    
    $OldBranchInfo = "**⚠️ 注意:** 目標分支 ``{0}`` 原本已存在，系統已將其**刪除並重建**。  `n> **舊分支最後紀錄:** Commit ``{1}`` (時間: {2})" -f $TargetBranch, $OldHash, $OldTime
    
    Write-Host ("偵測到舊的目標分支，已記錄資訊並準備刪除..." -f $TargetBranch) -ForegroundColor Yellow
}

$ReportContent.Add("# 自動合併報告 (Auto Merge Report)")
if (-not [string]::IsNullOrWhiteSpace($NetworkWarning)) {
    $ReportContent.Add("")
    $ReportContent.Add($NetworkWarning)
}
$ReportContent.Add( ("**執行時間:** {0}  " -f $CurrentTime) )
$ReportContent.Add( ("**目標分支:** ``{0}``  " -f $TargetBranch) )
$ReportContent.Add( ("**基底分支:** ``{0}``  " -f $BaseBranch) )
$ReportContent.Add( ("**倉庫位置:** ``{0}``  " -f $RepoPath) )
if (-not [string]::IsNullOrWhiteSpace($OldBranchInfo)) {
    $ReportContent.Add("")
    $ReportContent.Add($OldBranchInfo)
}
$ReportContent.Add("")
$ReportContent.Add("## 合併執行明細")
# 這裡使用格式化字串來避開直接在程式碼中寫入 | 符號
$Header = "| {0} | {1} | {2} | {3} | {4} |" -f "序號", "分支名稱 (Branch)", "合併結果 (Status)", "Commit Hash", "備註 (Notes)"
$Divider = "|:---:|:---|:---|:---|:---|"
$ReportContent.Add($Header)
$ReportContent.Add($Divider)

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
        $ConflictFilesList = @()
        if (-not [string]::IsNullOrWhiteSpace($DiffRes.Output)) {
            $ConflictFilesList = $DiffRes.Output.Trim() -split "`r?`n"
        }
        
        $ConflictFiles = $ConflictFilesList -join ", "
        if ([string]::IsNullOrWhiteSpace($ConflictFiles)) {
             $ConflictFiles = "Tree Conflict / Binary Conflict (無法列出詳細檔案)"
        }
        
        # 2-1. 使用 Git 內建 grep 搜尋衝突標記，顯示上下文 (方便 PM/PG 判斷)
        # 直接讀取有衝突的檔案內容並搜尋衝突標記
        # -I: 忽略二進位檔案
        # -n: 顯示行號
        # -C 15: 顯示上下文 15 行（確保能捕捉完整的衝突區塊，包含 <<<<<<<、======= 和 >>>>>>>）
        if ($ConflictFilesList.Count -gt 0) {
            # 對每個衝突檔案執行 grep
            $GrepResults = @()
            foreach ($File in $ConflictFilesList) {
                if (-not [string]::IsNullOrWhiteSpace($File)) {
                    # 使用 -- 來明確指定檔案路徑，避免路徑被當作選項
                    $GrepCmd = "grep -I -n -C 15 `"<<<<<<<`" -- `"$File`""
                    $GrepRes = Run-GitCmd -Command $GrepCmd -WorkingDir $RepoPath
                    if ($GrepRes.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($GrepRes.Output)) {
                        $HighlightedOutput = $GrepRes.Output.Trim()
                        
                        # 1. 進行 HTML Escape，避免程式碼內容被瀏覽器誤判為標籤
                        $HighlightedOutput = $HighlightedOutput.Replace("&", "&amp;").Replace("<", "&lt;").Replace(">", "&gt;")

                        # 2. 使用 HTML 標籤為衝突標記整行上色
                        # 注意：因為已進行 Escape，所以要匹配 &lt; 和 &gt;
                        # (?m) 開啟多行模式，^...$ 匹配整行
                        
                        # <<<<<<< (HEAD) -> 紅色
                        $HighlightedOutput = $HighlightedOutput -replace '(?m)^.*(?:&lt;){7}.*$', '<span style="color: #d9534f; font-weight: bold;">$0</span>'
                        
                        # ======= (Divider) -> 藍色
                        $HighlightedOutput = $HighlightedOutput -replace '(?m)^.*={7}.*$', '<span style="color: #5bc0de; font-weight: bold;">$0</span>'
                        
                        # >>>>>>> (Branch) -> 綠色
                        $HighlightedOutput = $HighlightedOutput -replace '(?m)^.*(?:&gt;){7}.*$', '<span style="color: #5cb85c; font-weight: bold;">$0</span>'
                        
                        $GrepResults += "**檔案:** ``$File```n<pre>`n" + $HighlightedOutput + "`n</pre>`n"
                    }
                }
            }
            
            # 如果有衝突上下文，記錄到獨立章節
            if ($GrepResults.Count -gt 0) {
                $ConflictDetails.Add("### [$Index] ``$BranchName``")
                $ConflictDetails.Add("")
                foreach ($Result in $GrepResults) {
                    $ConflictDetails.Add($Result)
                }
                $ConflictDetails.Add("")
            }
        }
        
        # 記錄到 Note (只記錄簡要資訊)
        $Note = "衝突檔案: " + $ConflictFiles
        
        # 3. 使用 Theirs 解決衝突
        # checkout --theirs . 會將所有 Unmerged 檔案的內容替換為對方版本
        Run-GitCmd -Command "checkout --theirs ." -WorkingDir $RepoPath | Out-Null
        Run-GitCmd -Command "add ." -WorkingDir $RepoPath | Out-Null
        
        # 4. 提交
        $CommitMsg = "{0} (Conflicts Resolved: Taken Theirs)" -f $MergeMsg
        
        # 嘗試讀取 Git 產生的預設 MERGE_MSG (通常包含衝突檔案列表)
        $MergeMsgFile = Join-Path $RepoPath ".git\MERGE_MSG"
        if (Test-Path $MergeMsgFile) {
            $OriginalMsg = Get-Content $MergeMsgFile -Encoding UTF8 -Raw -ErrorAction SilentlyContinue
            if (-not [string]::IsNullOrWhiteSpace($OriginalMsg)) {
                $CommitMsg += "`r`n`r`n--- Git Merge Message ---`r`n" + $OriginalMsg
            }
        }
        
        # 由於訊息可能包含多行，使用暫存檔來傳遞給 commit 指令會更安全
        $MsgTempFile = Join-Path $env:TEMP ([Guid]::NewGuid().ToString() + ".txt")
        $CommitMsg | Out-File -FilePath $MsgTempFile -Encoding UTF8
        
        $CommitCmd = 'commit --no-edit -F "{0}"' -f $MsgTempFile
        $CommitRes = Run-GitCmd -Command $CommitCmd -WorkingDir $RepoPath
        
        # 清理訊息暫存檔
        if (Test-Path $MsgTempFile) { Remove-Item $MsgTempFile -Force }
            
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

# 5. 附加衝突詳情章節
if ($ConflictDetails.Count -gt 0) {
    $ReportContent.Add("")
    $ReportContent.Add("---")
    $ReportContent.Add("")
    $ReportContent.Add("## 衝突標記上下文 (Conflict Markers Context)")
    $ReportContent.Add("")
    $ReportContent.Add('> <span style="color: red; font-weight: bold;">以下為發生衝突的分支之詳細衝突標記內容，包含上下文 15 行，方便 PM 與 PG 判斷衝突原因。</span>')
    $ReportContent.Add("")
    foreach ($Line in $ConflictDetails) {
        $ReportContent.Add($Line)
    }
}

# 6. 輸出報告 (UTF8 在 WinPS 5.1 即為 UTF-8 with BOM)
$ReportContent | Out-File -FilePath $ReportPath -Encoding UTF8

# 7. 轉換並輸出 HTML 報告
$HtmlPath = $ReportPath -replace '\.md$', '.html'
$HtmlBody = New-Object System.Collections.Generic.List[string]

# HTML Header & Style
$HtmlBody.Add("<!DOCTYPE html>")
$HtmlBody.Add("<html>")
$HtmlBody.Add("<head>")
$HtmlBody.Add("<meta charset='UTF-8'>")
$HtmlBody.Add("<style>")
$HtmlBody.Add("body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; color: #333; }")
$HtmlBody.Add("h1 { color: #2c3e50; border-bottom: 2px solid #eee; padding-bottom: 10px; }")
$HtmlBody.Add("h2 { color: #e67e22; margin-top: 30px; }")
$HtmlBody.Add("h3 { color: #3498db; margin-top: 20px; }")
$HtmlBody.Add("table { border-collapse: collapse; width: 100%; margin: 20px 0; box-shadow: 0 2px 3px rgba(0,0,0,0.1); }")
$HtmlBody.Add("th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }")
$HtmlBody.Add("th { background-color: #f8f9fa; color: #333; font-weight: bold; }")
$HtmlBody.Add("tr:nth-child(even) { background-color: #f9f9f9; }")
$HtmlBody.Add("tr:hover { background-color: #f1f1f1; }")
$HtmlBody.Add("blockquote { border-left: 5px solid #eee; margin: 10px 0; padding: 10px 20px; color: #666; background-color: #fdfdfd; }")
$HtmlBody.Add("code { background-color: #f0f0f0; padding: 2px 5px; border-radius: 3px; font-family: Consolas, monospace; color: #c7254e; }")
$HtmlBody.Add("pre { background-color: #2b2b2b; color: #f8f8f2; padding: 15px; border-radius: 5px; overflow-x: auto; font-family: Consolas, monospace; line-height: 1.5; }")
$HtmlBody.Add(".conflict-file { font-weight: bold; margin-bottom: 5px; display: block; }")
$HtmlBody.Add("</style>")
$HtmlBody.Add("</head>")
$HtmlBody.Add("<body>")

$InTable = $false

foreach ($Line in $ReportContent) {
    # 簡單的 Markdown 轉換邏輯
    $HtmlLine = $Line

    # 處理特殊字元 (除了已經是 HTML 的部分)
    # 注意：這裡不 Escape 全部，因為衝突區塊已經包含 HTML tags
    # 我們只針對 Markdown 語法做替換

    # 1. 表格處理
    if ($HtmlLine -match '^\|.*\|$') {
        # 這是表格行
        if ($HtmlLine -match '\|:---|') {
            # 分隔線，忽略
            continue
        }
        
        $Cells = $HtmlLine.Trim('|').Split('|')
        
        if (-not $InTable) {
            $HtmlBody.Add("<table>")
            $HtmlBody.Add("<thead><tr>")
            foreach ($Cell in $Cells) { $HtmlBody.Add("<th>$($Cell.Trim())</th>") }
            $HtmlBody.Add("</tr></thead><tbody>")
            $InTable = $true
        } else {
            $HtmlBody.Add("<tr>")
            # 針對內容做簡單的 Bold/Code 轉換
            foreach ($Cell in $Cells) { 
                $Content = $Cell.Trim()
                # 轉換 ``text`` -> <code>
                $Content = $Content -replace '``(.*?)``', '<code>$1</code>'
                $HtmlBody.Add("<td>$Content</td>") 
            }
            $HtmlBody.Add("</tr>")
        }
        continue
    } else {
        if ($InTable) {
            $HtmlBody.Add("</tbody></table>")
            $InTable = $false
        }
    }

    # 2. 標題
    if ($HtmlLine -match '^# (.*)') {
        $HtmlBody.Add("<h1>$($Matches[1])</h1>")
        continue
    }
    if ($HtmlLine -match '^## (.*)') {
        $HtmlBody.Add("<h2>$($Matches[1])</h2>")
        continue
    }
    if ($HtmlLine -match '^### (.*)') {
        $TitleContent = $Matches[1] -replace '``(.*?)``', '<code>$1</code>'
        $HtmlBody.Add("<h3>$TitleContent</h3>")
        continue
    }

    # 3. 分隔線
    if ($HtmlLine -match '^---$') {
        $HtmlBody.Add("<hr>")
        continue
    }

    # 4. 引用
    if ($HtmlLine -match '^> (.*)') {
        $Content = $Matches[1] -replace '\*\*(.*?)\*\*', '<b>$1</b>' -replace '``(.*?)``', '<code>$1</code>'
        $HtmlBody.Add("<blockquote>$Content</blockquote>")
        continue
    }

    # 5. 一般文字與換行
    if ([string]::IsNullOrWhiteSpace($HtmlLine)) {
        # 空行不輸出或輸出 <br>
    } else {
        # 如果是 HTML 標籤 (如 <pre> 區塊)，直接輸出
        if ($HtmlLine -match '^<.*>$') {
             $HtmlBody.Add($HtmlLine)
        } else {
             # 一般文字：處理 Bold, Code
             $Content = $HtmlLine -replace '\*\*(.*?)\*\*', '<b>$1</b>' -replace '``(.*?)``', '<code>$1</code>'
             # 如果上一行是標題或表格，這裡可能需要 <p>，簡單起見直接輸出並加 <br>
             $HtmlBody.Add("<p>$Content</p>")
        }
    }
}

if ($InTable) {
    $HtmlBody.Add("</tbody></table>")
}

$HtmlBody.Add("</body>")
$HtmlBody.Add("</html>")

$HtmlBody | Out-File -FilePath $HtmlPath -Encoding UTF8

Write-Host "`n流程結束。" -ForegroundColor Green
Write-Host ("Markdown 報告已產出: {0}" -f $ReportPath)
Write-Host ("HTML     報告已產出: {0}" -f $HtmlPath)
Write-Host "請通知 PM 與開發人員檢視該報告。"