# 如何查詢 Jira 自定義欄位 ID

## 重要提示：Jira 版本差異

**本文件適用於 Jira Server/Data Center（地端版本）**

- **Jira Cloud**: 使用 REST API v3 (`/rest/api/3/...`)
- **Jira Server/Data Center**: 使用 REST API v2 (`/rest/api/2/...`)

如果您的 Jira 網址不是 `*.atlassian.net`，通常是地端版本，請使用 **API v2**。

### 認證方式差異

**Jira Server/Data Center** 支援以下認證方式：

1. **用戶名 + 密碼** (Basic Auth) - 最常用
   ```powershell
   $Username = "your-username"  # 注意：是用戶名，不是 Email
   $Password = "your-password"
   $AuthPair = "$($Username):$($Password)"
   $EncodedAuth = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($AuthPair))
   $Headers = @{ Authorization = "Basic $EncodedAuth" }
   ```

2. **Personal Access Token (PAT)** - Jira 8.14 以上版本
   ```powershell
   $Token = "your-personal-access-token"
   $Headers = @{ Authorization = "Bearer $Token" }
   ```

3. **API Token** - 主要用於 Jira Cloud

**Jira Cloud** 使用：
- Email + API Token (Basic Auth)

**診斷工具**：如果遇到 401 錯誤，請使用 `test_jira_auth.ps1` 測試不同認證方式。

## 什麼是自定義欄位 ID？

`customfield_xxxxx` 是 Jira 系統自動分配給自定義欄位的唯一識別碼。每個 Jira 實例的自定義欄位 ID 可能不同，因此需要根據您的實際 Jira 環境來查詢正確的 ID。

例如：
- `customfield_10001` 可能對應 "AP編號"
- `customfield_10002` 可能對應 "DB編號"

## 方法 1: 使用 PowerShell 查詢所有自定義欄位

### 步驟 0: 測試認證方式（如果遇到 401 錯誤）

```powershell
# 使用診斷工具測試認證
.\test_jira_auth.ps1 -JiraDomain "https://jira.example.com" `
                     -Username "your-username" `
                     -Password "your-password"
```

### 步驟 1: 查詢所有欄位列表

**方式 A: 使用用戶名和密碼（推薦用於 Jira Server/Data Center）**

```powershell
# 設定您的 Jira 資訊（地端版本範例）
$JiraDomain = "https://jira.example.com"  # 地端版本不含尾部斜線
$Username = "your-username"  # 注意：是用戶名，不是 Email
$Password = "your-password"

# 建立認證
$AuthPair = "$($Username):$($Password)"
$EncodedAuth = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($AuthPair))
$Headers = @{ Authorization = "Basic $EncodedAuth" }

# 查詢所有欄位（地端版本使用 API v2）
$Fields = Invoke-RestMethod -Uri "$JiraDomain/rest/api/2/field" -Headers $Headers

# 篩選並顯示自定義欄位
$CustomFields = $Fields | Where-Object { $_.custom -eq $true } | Select-Object id, name, schema
$CustomFields | Format-Table -AutoSize

# 匯出到 CSV 方便查看
$CustomFields | Export-Csv -Path "jira_custom_fields.csv" -NoTypeInformation -Encoding UTF8
Write-Host "已匯出到 jira_custom_fields.csv" -ForegroundColor Green
```

**方式 B: 使用 Personal Access Token（Jira 8.14+）**

```powershell
$JiraDomain = "https://jira.example.com"
$Token = "your-personal-access-token"

# 建立認證
$Headers = @{ Authorization = "Bearer $Token" }

# 查詢所有欄位
$Fields = Invoke-RestMethod -Uri "$JiraDomain/rest/api/2/field" -Headers $Headers
$CustomFields = $Fields | Where-Object { $_.custom -eq $true } | Select-Object id, name, schema
$CustomFields | Format-Table -AutoSize
```

### 步驟 2: 尋找特定欄位

```powershell
# 搜尋包含特定關鍵字的欄位
$Keyword = "AP編號"
$CustomFields | Where-Object { $_.name -like "*$Keyword*" } | Format-Table

# 或者搜尋 DB 編號
$Keyword = "DB編號"
$CustomFields | Where-Object { $_.name -like "*$Keyword*" } | Format-Table
```

## 方法 2: 從特定議題查詢欄位資料

如果您知道某個議題包含這些欄位，可以直接查詢該議題：

```powershell
# 設定議題編號
$IssueKey = "PROJ-383"  # 替換成實際的議題編號

# 查詢議題資料（地端版本使用 API v2）
$Issue = Invoke-RestMethod -Uri "$JiraDomain/rest/api/2/issue/$IssueKey" -Headers $Headers

# 列出所有自定義欄位及其值
$Issue.fields.PSObject.Properties | 
    Where-Object { $_.Name -like "customfield_*" } | 
    Select-Object Name, Value | 
    Format-Table -AutoSize
```

### 完整範例腳本

```powershell
# 從議題中尋找有值的自定義欄位
$IssueKey = "PROJ-383"
$Issue = Invoke-RestMethod -Uri "$JiraDomain/rest/api/2/issue/$IssueKey" -Headers $Headers

Write-Host "`n=== 議題 $IssueKey 的自定義欄位 ===" -ForegroundColor Cyan

$Issue.fields.PSObject.Properties | 
    Where-Object { $_.Name -like "customfield_*" -and $null -ne $_.Value -and $_.Value -ne "" } | 
    ForEach-Object {
        $FieldId = $_.Name
        $FieldValue = $_.Value
        
        # 嘗試從欄位列表中找到欄位名稱
        $FieldInfo = $Fields | Where-Object { $_.id -eq $FieldId }
        $FieldName = if ($FieldInfo) { $FieldInfo.name } else { "未知" }
        
        [PSCustomObject]@{
            ID = $FieldId
            Name = $FieldName
            Value = $FieldValue
        }
    } | Format-Table -AutoSize
```

## 方法 3: 使用瀏覽器開發者工具

### 步驟：

1. 在瀏覽器中開啟一個 Jira 議題（例如：`https://your-domain.atlassian.net/browse/PROJ-383`）

2. 按 **F12** 開啟開發者工具

3. 切換到 **Network** (網路) 標籤

4. 重新整理頁面 (**F5**)

5. 在網路請求中找到包含議題資料的 API 請求，通常是：
   - Jira Server/Data Center: `/rest/api/2/issue/PROJ-383`
   - Jira Cloud: `/rest/api/3/issue/PROJ-383`

6. 點擊該請求，查看 **Response** (回應) 標籤

7. 在回應的 JSON 中找到 `fields` 物件

8. 尋找 `customfield_` 開頭的欄位，例如：
   ```json
   {
     "fields": {
       "customfield_10001": "00360",
       "customfield_10002": "E2136",
       ...
     }
   }
   ```

## 方法 4: 從現有 CSV 檔案對照

如果您已經有從 Jira 匯出的 CSV 檔案，可以：

1. 查看 CSV 檔案的欄位名稱：
   - `Custom field (AP編號)`
   - `Custom field (DB編號)`

2. 使用方法 1 或 2 找到這些欄位名稱對應的 `customfield_xxxxx`

3. 在 `jira_config.json` 中更新：
   ```json
   "Custom field (AP編號)": "fields.customfield_10XXX",
   "Custom field (DB編號)": "fields.customfield_10YYY"
   ```

## 完整自動化查詢腳本

儲存以下腳本為 `find_custom_fields.ps1`：

```powershell
<#
.SYNOPSIS
    查詢 Jira 自定義欄位 ID（支援 Jira Server/Data Center 和 Jira Cloud）
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$JiraDomain,
    
    [Parameter(Mandatory=$true)]
    [string]$Email,
    
    [Parameter(Mandatory=$true)]
    [string]$ApiToken,
    
    [Parameter(Mandatory=$false)]
    [string]$IssueKey = "",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("v2", "v3")]
    [string]$ApiVersion = "v2"  # 預設使用 v2 (Jira Server/Data Center)
)

# 移除結尾的斜線
$JiraDomain = $JiraDomain.TrimEnd('/')

# 建立認證
$AuthPair = "$($Email):$($ApiToken)"
$EncodedAuth = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($AuthPair))
$Headers = @{ Authorization = "Basic $EncodedAuth" }

Write-Host "正在查詢 Jira 自定義欄位... (使用 REST API $ApiVersion)" -ForegroundColor Cyan

# 查詢所有欄位
try {
    $Fields = Invoke-RestMethod -Uri "$JiraDomain/rest/api/$ApiVersion/field" -Headers $Headers
    $CustomFields = $Fields | Where-Object { $_.custom -eq $true }
    
    Write-Host "`n=== 所有自定義欄位 (共 $($CustomFields.Count) 個) ===" -ForegroundColor Green
    $CustomFields | Select-Object id, name, schema | Format-Table -AutoSize
    
    # 匯出到 CSV
    $CustomFields | Select-Object id, name, schema | 
        Export-Csv -Path "jira_custom_fields.csv" -NoTypeInformation -Encoding UTF8
    Write-Host "已匯出到 jira_custom_fields.csv`n" -ForegroundColor Green
}
catch {
    Write-Error "查詢欄位失敗: $($_.Exception.Message)"
    Write-Host "`n提示: 如果是 Jira Cloud，請加上參數 -ApiVersion v3" -ForegroundColor Yellow
    exit 1
}

# 如果提供議題編號，顯示該議題的自定義欄位值
if ($IssueKey) {
    Write-Host "`n=== 議題 $IssueKey 的自定義欄位值 ===" -ForegroundColor Cyan
    
    try {
        $Issue = Invoke-RestMethod -Uri "$JiraDomain/rest/api/$ApiVersion/issue/$IssueKey" -Headers $Headers
        
        $Issue.fields.PSObject.Properties | 
            Where-Object { $_.Name -like "customfield_*" -and $null -ne $_.Value -and $_.Value -ne "" } | 
            ForEach-Object {
                $FieldId = $_.Name
                $FieldValue = $_.Value
                
                # 找到欄位名稱
                $FieldInfo = $CustomFields | Where-Object { $_.id -eq $FieldId }
                $FieldName = if ($FieldInfo) { $FieldInfo.name } else { "未知" }
                
                [PSCustomObject]@{
                    ID = $FieldId
                    Name = $FieldName
                    Value = if ($FieldValue -is [string]) { $FieldValue } else { $FieldValue | ConvertTo-Json -Compress }
                }
            } | Format-Table -AutoSize
    }
    catch {
        Write-Error "查詢議題失敗: $($_.Exception.Message)"
    }
}

Write-Host "`n提示: 請在 jira_config.json 中更新對應的 customfield ID" -ForegroundColor Yellow
```

### 使用方式：

```powershell
# Jira Server/Data Center (預設使用 API v2)
.\find_custom_fields.ps1 -JiraDomain "https://jira.example.com" `
                         -Email "your-email@example.com" `
                         -ApiToken "your-api-token"

# 同時查看特定議題的欄位值
.\find_custom_fields.ps1 -JiraDomain "https://jira.example.com" `
                         -Email "your-email@example.com" `
                         -ApiToken "your-api-token" `
                         -IssueKey "PROJ-383"

# Jira Cloud (明確指定使用 API v3)
.\find_custom_fields.ps1 -JiraDomain "https://your-domain.atlassian.net" `
                         -Email "your-email@example.com" `
                         -ApiToken "your-api-token" `
                         -ApiVersion "v://your-domain.atlassian.net" `
                         -Email "your-email@example.com" `
                         -ApiToken "your-api-token"

# 同時查看特定議題的欄位值
.\find_custom_fields.ps1 -JiraDomain "https://your-domain.atlassian.net" `
                         -Email "your-email@example.com" `
                         -ApiToken "your-api-token" `
                         -IssueKey "PROJ-101"
```

## 更新配置檔案

找到正確的欄位 ID 後，更新 `jira_config.json`：

```json
{
    "FetchFields": "key,summary,status,created,updated,labels,fixVersions,duedate,issuetype,customfield_10XXX,customfield_10YYY",
    
    "ColumnMapping": {
        "Custom field (AP編號)": "fields.customfield_10XXX",
        "Custom field (DB編號)": "fields.customfield_10YYY"
    }
}
```

## 版本差異總結

| 項目 | Jira Server/Data Center | Jira Cloud |
|------|------------------------|------------|
| **API 版本** | REST API v2 | REST API v3 |
| **域名範例** | `https://jira.example.com` | `https://your-domain.atlassian.net` |
| **欄位 API** | `/rest/api/2/field` | `/rest/api/3/field` |
| **議題 API** | `/rest/api/2/issue/{key}` | `/rest/api/3/issue/{key}` |
| **認證方式** | Username + Password (Basic Auth)<br>或 Personal Access Token (Bearer) | Email + API Token (Basic Auth) |
| **認證標頭** | `Basic <base64(username:password)>`<br>或 `Bearer <token>` | `Basic <base64(email:apitoken)>` |

## 常見問題

### Q1: 401 未經授權錯誤怎麼辦？

A: **Jira Server/Data Center** 最常見原因：

1. **使用了錯誤的認證方式**
   - ❌ 錯誤：使用 Email + API Token
   - ✓ 正確：使用 Username + Password 或 Personal Access Token

2. **使用測試工具診斷**
   ```powershell
   .\test_jira_auth.ps1 -JiraDomain "https://your-jira.com" `
                        -Username "your-username" `
                        -Password "your-password"
   ```

3. **檢查帳號權限**
   - 確認帳號有 API 訪問權限
   - 確認帳號沒有被鎖定

### Q2: 如何創建 Personal Access Token (PAT)？

A: 適用於 Jira Server/Data Center 8.14 以上版本：

1. 登入 Jira
2. 點擊右上角頭像 > **Personal Access Tokens**
3. 點擊 **Create token**
4. 輸入名稱並設定到期日
5. 複製生成的 Token（只會顯示一次）

### Q3: 為什麼我的自定義欄位 ID 與範例不同？

A: 每個 Jira 實例的自定義欄位 ID 都是獨立分配的，所以不同 Jira 環境的 ID 會不同。

### Q4: 如何知道欄位的資料類型？

A: 查詢欄位時會顯示 `schema` 屬性，例如：
```json
{
    "id": "customfield_10001",
    "name": "AP編號",
    "schema": {
        "type": "string",
        "custom": "com.atlassian.jira.plugin.system.customfieldtypes:textfield"
    }
}
```

### Q5: 某些欄位查不到值？

A: 可能原因：
- 該欄位在議題中沒有填寫值
- 沒有權限查看該欄位
- `FetchFields` 中沒有包含該欄位 ID

## 參考資料

### Jira Server/Data Center
- [Jira Server REST API - Get all fields](https://docs.atlassian.com/software/jira/docs/api/REST/latest/#api/2/field)
- [Jira Server REST API - Get issue](https://docs.atlassian.com/software/jira/docs/api/REST/latest/#api/2/issue)

### Jira Cloud
- [Jira Cloud REST API v3 - Get all fields](https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-fields/#api-rest-api-3-field-get)
- [Jira Cloud REST API v3
}
```

### Q3: 某些欄位查不到值？

A: 可能原因：
- 該欄位在議題中沒有填寫值
- 沒有權限查看該欄位
- `FetchFields` 中沒有包含該欄位 ID

## 參考資料

- [Jira REST API - Get all fields](https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-fields/#api-rest-api-3-field-get)
- [Jira REST API - Get issue](https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issues/#api-rest-api-3-issue-issueidorkey-get)
