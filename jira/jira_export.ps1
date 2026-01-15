<#
.SYNOPSIS
    Jira Issue Export Tool (Dynamic CSV)
    
.DESCRIPTION
    Retrieves issues from Jira and exports to CSV based on a JSON configuration.
    Supports dynamic field mapping without modifying code.
    
.NOTES
    File Name  : jira_export.ps1
    Author     : Robbin (via Gemini)
#>

# --- Helper Function: Get Nested Property Value ---
function Get-NestedValue {
    param (
        [Parameter(Mandatory=$true)] $Object,
        [string] $Path,
        [string] $JiraBaseUrl
    )

    # Special Feature: Construct URL if configured
    if ($Path -eq "__LINK__") {
        return "$JiraBaseUrl/browse/$($Object.key)"
    }

    # Split path by dot (e.g. "fields.status.name")
    $Parts = $Path -split '\.'
    $Current = $Object

    foreach ($Part in $Parts) {
        if ($null -eq $Current) { return $null }
        $Current = $Current.$Part
    }
    return $Current
}

# --- Load Configuration ---
$ConfigPath = Join-Path $PSScriptRoot "jira_config.json"

if (-not (Test-Path $ConfigPath)) {
    Write-Error "Configuration file not found: $ConfigPath"
    Write-Host "Please create 'jira_config.json' based on 'jira_config.json.example'." -ForegroundColor Yellow
    exit 1
}

try {
    # -Ordered preserves the order of ColumnMapping in JSON
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
$Mapping     = $Config.ColumnMapping

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

do {
    $Uri = "$JiraDomain/rest/api/3/search?jql=$Jql&startAt=$StartAt&maxResults=$MaxResults&fields=$FetchFields"
    
    try {
        Write-Host "Fetching records starting at index $StartAt..." -NoNewline
        $Response = Invoke-RestMethod -Uri $Uri -Headers $Headers -Method Get
        $Batch = $Response.issues
        
        if ($null -eq $Batch -or $Batch.Count -eq 0) { 
            Write-Host " Done." -ForegroundColor Yellow
            break 
        }
        
        $AllIssues += $Batch
        $StartAt += $Batch.Count
        Write-Host " Retrieved $($Batch.Count)." -ForegroundColor Green
    }
    catch {
        Write-Host "`nError: Request failed." -ForegroundColor Red
        Write-Error $_.Exception.Message
        break
    }
} while ($Batch.Count -eq $MaxResults)

# --- Dynamic CSV Generation ---
if ($AllIssues.Count -gt 0) {
    Write-Host "Processing $($AllIssues.Count) issues with dynamic mapping..." -ForegroundColor Cyan
    
    $ExportData = $AllIssues | ForEach-Object {
        $Issue = $_
        $Row = [ordered]@{} # Use Ordered Dictionary to keep column order
        
        # Iterate through the JSON Mapping keys
        foreach ($Header in $Mapping.PSObject.Properties.Name) {
            $Path = $Mapping.$Header
            
            # Extract value dynamically
            $Value = Get-NestedValue -Object $Issue -Path $Path -JiraBaseUrl $JiraDomain
            
            # Handle nulls/arrays nicely
            if ($null -eq $Value) { 
                $Value = "" 
            }
            elseif ($Value -is [Array]) {
                $Value = $Value -join "; " # Join arrays (like labels) with semicolon
            }
            
            $Row[$Header] = $Value
        }
        
        [PSCustomObject]$Row
    }

    $ExportData | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding utf8 -Delimiter $Delimiter
    Write-Host "Success! Saved to: $OutputFile" -ForegroundColor Green
}
else {
    Write-Host "No issues found." -ForegroundColor Yellow
}