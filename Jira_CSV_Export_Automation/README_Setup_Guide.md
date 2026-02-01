# Jira 匯出設定說明

## 重要：Jira 版本差異

- **Jira Server/Data Center (地端)**：優先使用 **Personal Access Token (PAT)**，或 Username + Password
- **Jira Cloud**：使用 Email + API Token

## 如何創建 Personal Access Token (PAT)

**適用於 Jira Server/Data Center 8.14 以上版本**

1. 登入 Jira
2. 點擊右上角頭像 → **Profile** (個人檔案)
3. 選擇 **Personal Access Tokens**
4. 點擊 **Create token**
5. 輸入 Token 名稱並設定到期日
6. 複製生成的 Token（**只會顯示一次，請妥善保管**）

## 快速開始

### 步驟 1: 複製設定檔

```powershell
Copy-Item jira_config_template.json jira_config.json
```

### 步驟 2: 編輯設定檔

根據您的 Jira 版本選擇認證方式：

**Jira Server/Data Center - 使用 PAT (推薦)**
```json
{
    "JiraDomain": "https://your-jira.com",
    "ApiVersion": "2",
    "PersonalAccessToken": "your-personal-access-token",
    "Jql": "project = YOUR_PROJECT ORDER BY status DESC, issuetype DESC, KEY DESC",
    ...
}
```

**Jira Server/Data Center - 使用 Username/Password**
```json
{
    "JiraDomain": "https://your-jira.com",
    "ApiVersion": "2",
    "Username": "your-username",
    "Password": "your-password",
    "Jql": "project = YOUR_PROJECT ORDER BY status DESC, issuetype DESC, KEY DESC",
    ...
}
```

**Jira Cloud**
```json
{
    "JiraDomain": "https://your-domain.atlassian.net",
    "ApiVersion": "3",
    "Email": "your-email@example.com",
    "ApiToken": "your-api-token",
    "Jql": "project = YOUR_PROJECT ORDER BY created DESC",
    ...
}
```

### 步驟 3: 測試認證（選擇性）

如果不確定認證方式，可先執行測試：

```powershell
.\test_jira_auth.ps1 -JiraDomain "https://your-jira.com" `
                     -Username "your-username" `
                     -Password "your-password"
```

### 步驟 4: 執行匯出

```powershell
.\jira_export.ps1
```

檔案會匯出到設定檔中指定的路徑

## JIRA 格式說明

此設定檔會匯出以下欄位 (使用 `^` 作為分隔符):

| 欄位名稱 | Jira 欄位路徑 | 說明 |
|---------|--------------|------|
| Issue key | key | 議題編號 (如: PROJ-383) |
| Issue id | id | 議題 ID |
| Status | fields.status.name | 狀態 |
| Created | fields.created | 建立時間 |
| Updated | fields.updated | 更新時間 |
| Summary | fields.summary | 摘要 |
| Labels | fields.labels | 標籤 |
| Fix Version/s | fields.fixVersions | 修復版本 |
| Due Date | fields.duedate | 到期日 |
| Issue Type | fields.issuetype.name | 議題類型 |
| Custom field (AP編號) | fields.customfield_10600 | 自訂欄位 AP 編號 |
| Custom field (DB編號) | fields.customfield_10602 | 自訂欄位 DB 編號 |

## 自訂欄位 ID 查詢

如果您的 Jira 自訂欄位 ID 與範例不同，可以透過以下方式查詢:

1. 在瀏覽器開啟 Jira 議題
2. 開啟開發者工具 (F12)
3. 查看 API 回應中的 `fields` 部分
4. 找到對應的 `customfield_xxxxx`

或使用 Jira REST API:
```powershell
$headers = @{
    Authorization = "Basic YOUR_BASE64_TOKEN"
}
Invoke-RestMethod -Uri "https://your-domain.atlassian.net/rest/api/3/field" -Headers $headers
```

## 日期格式

日期會自動格式化為專案指定格式: `dd/MMM/yy h:mm tt`
範例: `08/Jan/26 11:26 AM`

## 陣列欄位處理

- **Labels**: 使用 `, ` 分隔
- **Fix Versions**: 自動提取版本名稱，使用 `, ` 分隔
