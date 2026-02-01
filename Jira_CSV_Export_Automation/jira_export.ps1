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

    # Check for array index notation (e.g., "fields.labels[0]")
    if ($Path -match '^(.+)\[(\d+)\]$') {
        $BasePath = $Matches[1]
        $Index = [int]$Matches[2]
        
        # Split base path by dot
        $Parts = $BasePath -split '\.'
        $Current = $Object
        
        foreach ($Part in $Parts) {
            if ($null -eq $Current) { return $null }
            $Current = $Current.$Part
        }
        
        # Get array element at index
        if ($Current -is [Array] -and $Index -lt $Current.Count) {
            return $Current[$Index]
        }
        return $null
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

# --- Helper Function: Format Date for Project ---
function Format-ProjectDate {
    param ([string]$DateString)
    
    if ([string]::IsNullOrWhiteSpace($DateString)) {
        return ""
    }
    
    try {
        $Date = [DateTime]::Parse($DateString)
        return $Date.ToString("dd/MMM/yy h:mm tt", [System.Globalization.CultureInfo]::InvariantCulture)
    }
    catch {
        return $DateString
    }
}

# --- Helper Function: Extract Version Names ---
function Get-VersionNames {
    param ([array]$Versions)
    
    if ($null -eq $Versions -or $Versions.Count -eq 0) {
        return ""
    }
    
    return ($Versions | ForEach-Object { $_.name }) -join ", "
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
$JiraDomain  = $Config.JiraDomain.TrimEnd('/')  # 移除結尾斜線
$Email       = $Config.Email
$ApiToken    = $Config.ApiToken
$Username    = $Config.Username
$Password    = $Config.Password
$PAT         = $Config.PersonalAccessToken
$Jql         = $Config.Jql
$OutputFile  = $Config.OutputFile
$Delimiter   = $Config.Delimiter
$FetchFields = $Config.FetchFields
$Mapping     = $Config.ColumnMapping
$ApiVersion  = if ($Config.ApiVersion) { $Config.ApiVersion } else { "3" }  # 預設 v3 (Cloud)

# --- Authentication ---
# 支援多種認證方式
if ($PAT) {
    # 方式 1: Personal Access Token (Jira Server/Data Center 8.14+)
    Write-Host "使用認證方式: Personal Access Token (PAT)" -ForegroundColor Gray
    $Headers = @{ 
        Authorization = "Bearer $PAT" 
        Accept        = "application/json"
    }
}
elseif ($Username -and $Password) {
    # 方式 2: Username + Password (Jira Server/Data Center)
    Write-Host "使用認證方式: Username + Password" -ForegroundColor Gray
    $AuthPair = "$($Username):$($Password)"
    $EncodedAuth = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($AuthPair))
    $Headers = @{ 
        Authorization = "Basic $EncodedAuth" 
        Accept        = "application/json"
    }
}
elseif ($Email -and $ApiToken) {
    # 方式 3: Email + API Token (Jira Cloud)
    Write-Host "使用認證方式: Email + API Token" -ForegroundColor Gray
    $AuthPair = "$($Email):$($ApiToken)"
    $EncodedAuth = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($AuthPair))
    $Headers = @{ 
        Authorization = "Basic $EncodedAuth" 
        Accept        = "application/json"
    }
}
else {
    Write-Error "未提供認證資訊。請在設定檔中提供以下其中一組：`n  - PersonalAccessToken (Jira Server/Data Center 8.14+)`n  - Username + Password (Jira Server/Data Center)`n  - Email + ApiToken (Jira Cloud)"
    exit 1
}

# --- Main Logic ---
$StartAt = 0
$MaxResults = 50 
$AllIssues = @()

Write-Host "Starting Jira export..." -ForegroundColor Cyan
Write-Host "Target: $JiraDomain (API v$ApiVersion)" -ForegroundColor Gray

do {
    # URL 編碼 JQL 和 fields 參數
    $EncodedJql = [System.Uri]::EscapeDataString($Jql)
    $EncodedFields = [System.Uri]::EscapeDataString($FetchFields)
    $Uri = "$JiraDomain/rest/api/$ApiVersion/search?jql=$EncodedJql&startAt=$StartAt&maxResults=$MaxResults&fields=$EncodedFields"
    
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
        Write-Host "`nDebug Info:" -ForegroundColor Yellow
        Write-Host "  JQL: $Jql" -ForegroundColor Gray
        Write-Host "  Encoded JQL: $EncodedJql" -ForegroundColor Gray
        Write-Host "  URI: $Uri" -ForegroundColor Gray
        break
    }
} while ($Batch.Count -eq $MaxResults)

# --- Dynamic CSV Generation ---
if ($AllIssues.Count -gt 0) {
    Write-Host "Processing $($AllIssues.Count) issues with dynamic mapping..." -ForegroundColor Cyan
    
    # 準備 CSV 行
    $CsvLines = @()
    
    # 支援陣列或物件格式的 ColumnMapping
    $MappingArray = @()
    if ($Mapping -is [Array]) {
        # 新格式：陣列
        $MappingArray = $Mapping
    } else {
        # 舊格式：物件（轉換為陣列）
        foreach ($prop in $Mapping.PSObject.Properties) {
            $MappingArray += @{
                Header = $prop.Name
                Path = $prop.Value
            }
        }
    }
    
    # 建立標題行
    $Headers = $MappingArray | ForEach-Object { $_.Header }
    $HeaderLine = $Headers -join $Delimiter
    $CsvLines += $HeaderLine
    
    # 處理每個議題
    foreach ($Issue in $AllIssues) {
        $Values = @()
        
        # 按照配置順序提取每個欄位的值
        foreach ($FieldMapping in $MappingArray) {
            $Path = $FieldMapping.Path
            
            # Extract value dynamically
            $Value = Get-NestedValue -Object $Issue -Path $Path -JiraBaseUrl $JiraDomain
            
            # Special handling for different field types
            if ($null -eq $Value) { 
                $Value = "" 
            }
            # Handle date fields (Created, Updated, Due Date)
            elseif ($Path -match "(created|updated|duedate)$" -and ![string]::IsNullOrWhiteSpace($Value)) {
                $Value = Format-ProjectDate -DateString $Value
            }
            # Handle Fix Versions array
            elseif ($Path -eq "fields.fixVersions") {
                $Value = Get-VersionNames -Versions $Value
            }
            # Handle Labels array (only if not using array index)
            elseif ($Path -eq "fields.labels" -and $Value -is [Array]) {
                $Value = $Value -join ", "
            }
            # Handle other arrays (but not if using array index notation)
            elseif ($Value -is [Array] -and $Path -notmatch '\[\d+\]$') {
                $Value = $Value -join "; "
            }
            
            # 處理包含分隔符的值（用雙引號包裹）
            if ($Value -match [regex]::Escape($Delimiter)) {
                $Value = "`"$Value`""
            }
            
            $Values += $Value
        }
        
        # 建立資料行
        $DataLine = $Values -join $Delimiter
        $CsvLines += $DataLine
    }
    
    # 寫入檔案
    $CsvLines | Out-File -FilePath $OutputFile -Encoding UTF8
    Write-Host "Success! Saved to: $OutputFile" -ForegroundColor Green
    Write-Host "Total records: $($AllIssues.Count)" -ForegroundColor Cyan
}
else {
    Write-Host "No issues found." -ForegroundColor Yellow
}