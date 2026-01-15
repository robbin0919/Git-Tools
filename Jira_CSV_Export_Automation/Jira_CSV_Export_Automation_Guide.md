# Jira 匯出 CSV 自動化實作指南

本文件說明如何透過 Jira REST API 自動化將問題 (Issues) 資料匯出為 CSV 檔案，適用於定期備份、報表製作或資料整合需求。

---

## 1. 前置準備

### 1.1 取得 API Token (Jira Cloud)
1. 登入 [Atlassian Account API Tokens](https://id.atlassian.com/manage-profile/security/api-tokens)。
2. 點擊 **Create API token**。
3. 複製並妥善保存 Token（此 Token 將取代密碼進行驗證）。

### 1.2 確定 JQL 查詢語法
在自動化之前，建議先在 Jira 網頁介面的「篩選器」測試 JQL，確保能精準抓取目標資料。
*   範例：`project = "MYPROJ" AND status = "Done" ORDER BY created DESC`

---

## 2. 實作方法

### 方法一：使用 Python 腳本 (推薦)
Python 適合處理分頁抓取（Pagination）以及複雜的 JSON 欄位轉換。

**檔案名稱：`jira_export.py`**

```python
import requests
import csv
from requests.auth import HTTPBasicAuth

# --- 設定區 ---
JIRA_DOMAIN = "https://your-domain.atlassian.net"
EMAIL = "your-email@example.com"
API_TOKEN = "your-api-token"
JQL_QUERY = 'project = "PROJ" ORDER BY created DESC'
OUTPUT_FILE = "jira_export_results.csv"

def get_jira_data():
    url = f"{JIRA_DOMAIN}/rest/api/3/search"
    auth = HTTPBasicAuth(EMAIL, API_TOKEN)
    headers = {"Accept": "application/json"}
    
    issues = []
    start_at = 0
    max_results = 50
    
    while True:
        params = {
            'jql': JQL_QUERY,
            'startAt': start_at,
            'maxResults': max_results,
            'fields': ['key', 'summary', 'status', 'assignee', 'created']
        }
        response = requests.get(url, headers=headers, params=params, auth=auth)
        if response.status_code != 200:
            break
            
        data = response.json()
        batch = data.get('issues', [])
        if not batch:
            break
            
        issues.extend(batch)
        start_at += len(batch)
        if len(batch) < max_results:
            break
            
    return issues

def save_to_csv(issues):
    with open(OUTPUT_FILE, mode='w', newline='', encoding='utf-8-sig') as f:
        writer = csv.writer(f)
        writer.writerow(['Key', 'Summary', 'Status', 'Assignee', 'Created'])
        for issue in issues:
            fld = issue['fields']
            assignee = fld['assignee']['displayName'] if fld.get('assignee') else 'Unassigned'
            writer.writerow([
                issue['key'],
                fld['summary'],
                fld['status']['name'],
                assignee,
                fld['created']
            ])

if __name__ == "__main__":
    data = get_jira_data()
    save_to_csv(data)
    print(f"匯出完成，共 {len(data)} 筆資料。")
```

### 方法二：使用 Curl 與 jq (輕量化)
適用於簡單的 Shell 腳本環境。

```bash
#!/bin/bash
curl -s -u "EMAIL:TOKEN" \
     -X GET \
     -H "Content-Type: application/json" \
     "https://your-domain.atlassian.net/rest/api/3/search?jql=project=PROJ&maxResults=100" \
     | jq -r '.issues[] | [.key, .fields.summary, .fields.status.name] | @csv' > jira_export.csv
```

### 方法三：使用 PowerShell (跨平台 Windows/Linux)
PowerShell Core (pwsh) 內建強大的 JSON 處理與 REST API 呼叫功能，無需額外安裝 Python 套件即可執行。

**檔案名稱：`jira_export.ps1`**

```powershell
# --- 設定區 ---
$JiraDomain = "https://your-domain.atlassian.net"
$Email = "your-email@example.com"
$ApiToken = "your-api-token"
$Jql = 'project = "PROJ" ORDER BY created DESC'
$OutputFile = "jira_export_ps.csv"

# --- 驗證標頭 ---
$AuthPair = "$($Email):$($ApiToken)"
$EncodedAuth = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($AuthPair))
$Headers = @{ Authorization = "Basic $EncodedAuth" }

# --- 抓取資料 (含分頁處理) ---
$StartAt = 0
$MaxResults = 50
$AllIssues = @()

Write-Host "開始匯出..."

do {
    $Uri = "$JiraDomain/rest/api/3/search?jql=$Jql&startAt=$StartAt&maxResults=$MaxResults&fields=key,summary,status,assignee,created"
    
    try {
        $Response = Invoke-RestMethod -Uri $Uri -Headers $Headers -Method Get
        $Batch = $Response.issues
        
        if ($null -eq $Batch -or $Batch.Count -eq 0) { break }
        
        $AllIssues += $Batch
        $StartAt += $Batch.Count
        Write-Host "已抓取 $StartAt 筆資料..."
    }
    catch {
        Write-Error "API 請求失敗: $($_.Exception.Message)"
        break
    }
} while ($Batch.Count -eq $MaxResults)

# --- 轉換並存檔 CSV ---
# 注意：需自定義物件以處理巢狀 JSON (如 fields.status.name)
$ExportData = $AllIssues | ForEach-Object {
    [PSCustomObject]@{
        Key      = $_.key
        Summary  = $_.fields.summary
        Status   = $_.fields.status.name
        Assignee = if ($_.fields.assignee) { $_.fields.assignee.displayName } else { "Unassigned" }
        Created  = $_.fields.created
    }
}

$ExportData | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding utf8
Write-Host "匯出完成：$OutputFile (共 $($ExportData.Count) 筆)"
```

**執行方式：**
*   **Windows:** 右鍵執行或在終端機輸入 `.\jira_export.ps1`
*   **Linux:** 安裝 PowerShell 後輸入 `pwsh ./jira_export.ps1`

---

## 3. 自動化排程

### 3.1 Linux Crontab
若要在 Linux 伺服器每天固定時間執行：

```bash
# 每天凌晨 2 點執行 Python 腳本
0 2 * * * /usr/bin/python3 /path/to/jira_export.py
```

### 3.2 CI/CD Pipeline (GitHub Actions / GitLab CI)
將 API Token 存放在 Secret 中，並設定 Schedule Trigger：

*   **GitHub Actions 範例 (.yml):**
    ```yaml
    on:
      schedule:
        - cron: '0 0 * * *' # 每天午夜
    jobs:
      export:
        runs-on: ubuntu-latest
        steps:
          - uses: actions/checkout@v2
          - name: Run Export
            env:
              JIRA_TOKEN: ${{ secrets.JIRA_TOKEN }}
            run: python3 jira_export.py
    ```

---

## 4. 注意事項
1.  **分頁限制**：Jira API 單次請求上限通常為 100 筆，若資料量大必須實作 `startAt` 迴圈（如方法一所示）。
2.  **安全建議**：絕對不要將 API Token 直接寫死在程式碼中並上傳至公開 Git 倉庫，請使用環境變數或 Secret 管理。
3.  **欄位選擇**：透過 `fields` 參數限制抓取的欄位，可有效提升執行效率。
