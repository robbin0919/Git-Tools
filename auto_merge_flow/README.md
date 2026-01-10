# Auto Merge Flow Script 使用說明

此腳本用於自動化 Git 分支合併作業，特別適用於整合測試環境（如 SIT/UAT）的建置流程。它會讀取指定的 CSV 清單，依序將分支合併至目標分支，並在發生衝突時自動採用「傳入變更 (Take Theirs)」策略，最終產出詳細的 Markdown 報告。

## 功能特色

*   **自動化批量合併**：依據 CSV 檔案定義的順序執行合併。
*   **自動衝突處理**：
    *   使用標準合併 (`git merge`)。
    *   若發生衝突，自動執行 `git checkout --theirs .` 強制採用對方分支的內容。
    *   自動將 Git 原生的衝突檔案列表 (`MERGE_MSG`) 附加到 Commit Message 中，保留完整紀錄。
*   **詳細報表**：產出 Markdown 格式報告，包含每個分支的合併狀態（成功/略過/衝突解決）、Commit Hash 及備註。
*   **穩健執行**：使用暫存檔處理輸出，避免大量 Log 造成腳本卡死 (Deadlock)。
*   **編碼支援**：支援 UTF-8 (with BOM) 輸出，確保繁體中文顯示正常。

## 前置需求

1.  **環境**：Windows (PowerShell 5.1 或 PowerShell Core) 或 Linux (安裝 PowerShell Core)。
2.  **工具**：需安裝 `git` 命令行工具並設定好環境變數。
3.  **權限**：執行腳本的環境需有權限存取遠端 Git 倉庫 (如 SSH Key 或 Credential Helper)。

## CSV 檔案格式

CSV 檔案需包含分支資訊，腳本會讀取 **第二欄** 作為 Git 分支名稱。

*   **格式**：`JiraID, BranchName, Sequence` (無 Header 或忽略第一行註解)
*   **範例**：
    ```csv
    # JiraID, BranchName, Seq
    robbinLab-179,robbinLab-179-feature-login,001
    robbinLab-300,robbinLab-300-fix-bug-123,002
    ```

## 使用方式

### 語法

```powershell
.\auto_merge_flow.ps1 -RepoPath <Git倉庫路徑> -TargetBranch <目標分支名稱> -CsvPath <CSV檔案路徑> [-BaseBranch <基底分支名稱>]
```

### 參數說明

| 參數 | 必填 | 預設值 | 說明 |
| :--- | :---: | :--- | :--- |
| `-RepoPath` | 是 | - | 本地 Git 倉庫的根目錄路徑 (包含 .git 的資料夾)。 |
| `-TargetBranch` | 是 | - | 要合併進去的目標分支名稱 (例如 `SIT_Integration`)。若分支已存在會被重置。 |
| `-CsvPath` | 是 | - | 包含合併清單的 CSV 檔案完整路徑。 |
| `-BaseBranch` | 否 | `master` | 目標分支的基底來源，每次執行會先切到此分支更新後，再建立目標分支。 |

### 執行範例

**基本範例：**

```powershell
.\auto_merge_flow.ps1 -RepoPath "D:\Projects\rep_project" -TargetBranch "SIT_20260110" -CsvPath "D:\Docs\merge_list.csv"
```

**指定基底分支範例 (例如基於 `main` 而非 `master`)：**

```powershell
.\auto_merge_flow.ps1 -RepoPath "D:\Projects\rep_project" -TargetBranch "UAT_Build" -BaseBranch "main" -CsvPath "D:\Docs\uat_list.csv"
```

## 輸出結果

1.  **Console 輸出**：執行過程中會即時顯示合併進度、成功/失敗狀態與 Commit ID。
2.  **Markdown 報告**：
    *   位置：Git 倉庫根目錄。
    *   檔名格式：`Merge_Report_<TargetBranch>_<YYYYMMDD_HHMMSS>.md`
    *   內容範例：
        ```markdown
        # 自動合併報告 (Auto Merge Report)
        **執行時間:** 2026-01-10 18:30:00  
        ...
        ## 合併執行明細
        | 序號 | 分支名稱 (Branch) | 合併結果 (Status) | Commit Hash | 備註 (Notes) |
        |:---:|:---|:---|:---|:---:|
        | 1 | robbinLab-179-feature... | ✅ 成功 | a1b2c3d | - |
        | 2 | robbinLab-300-fix... | ⚠️ 衝突解決 | e5f6g7h | 衝突檔案: src/config.json |
        ```

## 常見問題 (FAQ)

*   **Q: 為什麼顯示「略過 (遠端分支不存在)」？**
    *   A: 請確認 CSV 第二欄的分支名稱是否正確，以及本地是否已執行 `git fetch` (腳本會自動執行，但若權限不足可能失敗)。
*   **Q: 發生衝突時，為什麼我修改的程式碼不見了？**
    *   A: 此腳本採用 **"Take Theirs"** 策略。當發生衝突時，會無條件使用「要合併進來的分支」內容覆蓋目標分支的內容。這是為了確保特定功能的程式碼能完整進入整合環境。
*   **Q: 報表出現亂碼？**
    *   A: 腳本預設使用 UTF-8 with BOM 編碼輸出，大部分編輯器 (VS Code, Notepad++) 應能正常顯示。若在舊版 Console 顯示亂碼屬正常現象，不影響檔案內容。
