<#
.SYNOPSIS
    Jira Issue Export Tool (CSV)
    
.DESCRIPTION
    This script retrieves issues from Jira using the REST API (JQL) and exports them to a CSV file.
    Configuration is loaded from 'jira_config.json'.
    
.NOTES
    File Name  : jira_export.ps1
    Author     : Robbin (via Gemini)
    Prerequisite: PowerShell Core (pwsh) recommended for Linux/Mac compatibility.
#>

# --- Load Configuration ---
$ConfigPath = Join-Path $PSScriptRoot "jira_config.json"

if (-not (Test-Path $ConfigPath)) {
    Write-Error "Configuration file not found: $ConfigPath"
    Write-Host "Please create 'jira_config.json' based on 'jira_config.json.example'." -ForegroundColor Yellow
    exit 1
}

try {
    $Config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
}
catch {
    Write-Error "Failed to parse JSON configuration: $($_.Exception.Message)"
    exit 1
}

# Map configuration variables
$JiraDomain  = $Config.JiraDomain
$Email       = $Config.Email
$ApiToken    = $Config.ApiToken
$Jql         = $Config.Jql
$OutputFile  = $Config.OutputFile
$Delimiter   = $Config.Delimiter
$FetchFields = $Config.FetchFields

# --- Authentication ---
$AuthPair = "$($Email):$($ApiToken)"
$EncodedAuth = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($AuthPair))
$Headers = @{ 
    Authorization = "Basic $EncodedAuth" 
    Accept        = "application/json"
}

# --- Main Logic ---
$StartAt = 0
$MaxResults = 50 
$AllIssues = @()

Write-Host "Starting Jira export..." -ForegroundColor Cyan
Write-Host "Target: $JiraDomain" -ForegroundColor Gray
Write-Host "Query: $Jql" -ForegroundColor Gray

do {
    $Uri = "$JiraDomain/rest/api/3/search?jql=$Jql&startAt=$StartAt&maxResults=$MaxResults&fields=$FetchFields"
    
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
        
        # [CSV Column Mapping]
        # Adjust the properties below to change CSV headers or order
        [PSCustomObject]@{
            "Issue Key" = $_.key
            "Summary"   = $_.fields.summary
            "Status"    = $_.fields.status.name
            "Priority"  = if ($_.fields.priority) { $_.fields.priority.name } else { "None" }
            "Assignee"  = if ($_.fields.assignee) { $_.fields.assignee.displayName } else { "Unassigned" }
            "Created"   = $_.fields.created
            "Link"      = "$JiraDomain/browse/$($_.key)"
        }
    }

    $ExportData | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding utf8 -Delimiter $Delimiter
    
    Write-Host "Export successfully saved to: $OutputFile (Delimiter: '$Delimiter')" -ForegroundColor Green
}
else {
    Write-Host "No issues found." -ForegroundColor Yellow
}
