<#
.SYNOPSIS
    Jira Issue Export Tool (CSV)
    
.DESCRIPTION
    This script retrieves issues from Jira using the REST API (JQL) and exports them to a CSV file.
    It handles pagination automatically.
    
.NOTES
    File Name  : jira_export.ps1
    Author     : Robbin (via Gemini)
    Prerequisite: PowerShell Core (pwsh) recommended for Linux/Mac compatibility.
#>

# --- Configuration (請修改此處) ---
$JiraDomain = "https://your-domain.atlassian.net"      # 您的 Jira 網址
$Email      = "your-email@example.com"                 # 您的登入 Email
$ApiToken   = "your-api-token"                         # Atlassian API Token
$Jql        = 'project = "PROJ" ORDER BY created DESC' # JQL 查詢語法
$OutputFile = "jira_export_ps.csv"                     # 輸出檔案名稱
$Delimiter  = ","                                      # CSV 分隔符號 (例如 "," 或 ";")

# --- Authentication ---
# 建立 Basic Auth Header
$AuthPair = "$($Email):$($ApiToken)"
$EncodedAuth = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($AuthPair))
$Headers = @{ 
    Authorization = "Basic $EncodedAuth" 
    Accept        = "application/json"
}

# --- Main Logic ---
$StartAt = 0
$MaxResults = 50 # 每次請求抓取的數量 (建議 50-100)
$AllIssues = @()

Write-Host "Starting Jira export..." -ForegroundColor Cyan
Write-Host "Target: $JiraDomain" -ForegroundColor Gray
Write-Host "Query: $Jql" -ForegroundColor Gray

do {
    # 組合 API URL
    $Uri = "$JiraDomain/rest/api/3/search?jql=$Jql&startAt=$StartAt&maxResults=$MaxResults&fields=key,summary,status,assignee,created,priority"
    
    try {
        Write-Host "Fetching records starting at index $StartAt..." -NoNewline
        
        $Response = Invoke-RestMethod -Uri $Uri -Headers $Headers -Method Get
        $Batch = $Response.issues
        
        if ($null -eq $Batch -or $Batch.Count -eq 0) { 
            Write-Host " Done (No more records)." -ForegroundColor Yellow
            break 
        }
        
        $AllIssues += $Batch
        $StartAt += $Batch.Count
        Write-Host " Retrieved $($Batch.Count) records." -ForegroundColor Green
    }
    catch {
        Write-Host "`nError: Request failed." -ForegroundColor Red
        Write-Error $_.Exception.Message
        break
    }
} while ($Batch.Count -eq $MaxResults)

# --- Export to CSV ---
if ($AllIssues.Count -gt 0) {
    Write-Host "Processing $($AllIssues.Count) issues..." -ForegroundColor Cyan
    
    $ExportData = $AllIssues | ForEach-Object {
        # 處理巢狀物件與空值檢查
        [PSCustomObject]@{
            Key       = $_.key
            Summary   = $_.fields.summary
            Status    = $_.fields.status.name
            Priority  = if ($_.fields.priority) { $_.fields.priority.name } else { "None" }
            Assignee  = if ($_.fields.assignee) { $_.fields.assignee.displayName } else { "Unassigned" }
            Created   = $_.fields.created
            Link      = "$JiraDomain/browse/$($_.key)"
        }
    }

    # 匯出 CSV (UTF-8)
    $ExportData | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding utf8 -Delimiter $Delimiter
    
    Write-Host "Export successfully saved to: $OutputFile (Delimiter: '$Delimiter')" -ForegroundColor Green
}
else {
    Write-Host "No issues found." -ForegroundColor Yellow
}
