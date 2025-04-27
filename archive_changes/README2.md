# Git 變更檔案打包工具 - 流程圖

```mermaid
flowchart TD
    Start([開始]) --> Init[初始化]
    Init --> CheckHelp{是否為說明請求?}
    CheckHelp -->|是| ShowHelp[顯示說明文件] --> End([結束])
    
    CheckHelp -->|否| CheckGit{是否在Git儲存庫中?}
    CheckGit -->|否| GitError[顯示錯誤訊息] --> End
    
    CheckGit -->|是| SetVars[設定預設變數]
    SetVars --> ParseArgs[處理命令行參數]
    ParseArgs --> SetFileName[設定輸出檔案名稱]
    SetFileName --> ShowSettings[顯示基本設定]
    
    ShowSettings --> CreateTempDir[建立臨時目錄]
    CreateTempDir --> SetGitConfig[設定Git配置]
    
    SetGitConfig --> CheckBranches[檢查分支]
    CheckBranches --> CheckSource{源分支存在?}
    CheckSource -->|否| BranchError[顯示錯誤訊息] --> Cleanup
    CheckSource -->|是| CheckTarget{目標分支存在?}
    CheckTarget -->|否| BranchError
    
    CheckTarget -->|是| GetFileList[獲取檔案變更清單]
    GetFileList --> ConvertEncoding[編碼轉換]
    ConvertEncoding --> HasChanges{有檔案變更?}
    HasChanges -->|否| NoChanges[顯示無變更訊息] --> Cleanup
    
    HasChanges -->|是| CountFiles[計算檔案總數]
    CountFiles --> ExtractFiles[提取檔案]
    ExtractFiles --> CreateZip[建立ZIP壓縮檔]
    
    CreateZip --> GenerateReport[生成執行報告]
    GenerateReport --> ShowRepoInfo[顯示儲存庫資訊]
    ShowRepoInfo --> ShowPackageInfo[顯示打包資訊]
    ShowPackageInfo --> ShowOutputInfo[顯示輸出檔案資訊]
    ShowOutputInfo --> ShowDevInfo[顯示開發資訊]
    
    ShowDevInfo --> Cleanup[清理臨時檔案]
    Cleanup --> End
```

## 流程說明

### 1. 初始化階段
- 檢查是否為說明請求 (`--help` 或 `/?`)
- 驗證是否在 Git 儲存庫中執行
- 設定預設變數 (輸出檔名、源分支、目標分支)
- 處理位置參數或具名參數 (`-F`, `-S`, `-T`)

### 2. 準備階段
- 在系統臨時目錄中建立工作資料夾
- 設定 Git 配置以正確處理中文路徑

### 3. 分支檢查階段
- 檢查源分支是否存在
- 檢查目標分支是否存在

### 4. 檔案分析階段
- 使用 `git diff-tree` 獲取檔案變更清單
- 進行編碼轉換 (UTF-8 → BIG5)
- 檢查是否有檔案變更

### 5. 檔案處理階段
- 計算變更檔案總數
- 按照原始目錄結構提取檔案
- 顯示處理進度

### 6. 壓縮打包階段
- 使用 PowerShell 將檔案打包成 ZIP 格式

### 7. 報告生成階段
- 顯示儲存庫資訊 (路徑、分支、提交)
- 顯示打包資訊 (源分支、目標分支、檔案數量)
- 顯示輸出檔案資訊 (路徑、大小、時間)
- 顯示開發及使用說明資訊

### 8. 清理階段
- 刪除臨時檔案和目錄

## 決策節點

1. **是否為說明請求** - 決定是顯示說明還是執行操作
2. **是否在 Git 儲存庫中** - 確保在正確環境執行
3. **分支是否存在** - 驗證源分支和目標分支的有效性
4. **是否有檔案變更** - 決定是否繼續打包流程

此流程圖清楚呈現了工具的運行邏輯及主要處理步驟，有助於理解工具的工作原理。
