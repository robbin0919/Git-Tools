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

## 執行流程 (Internal Logic)

1.  **環境檢查**：確認 Git 倉庫路徑與 CSV 檔案是否存在。
2.  **更新遠端資訊**：
    *   **正常模式**：執行 `git fetch --all --prune` 確保獲取最新分支狀態。
    *   **離線模式** (`-Offline`)：跳過此步驟。
3.  **準備目標分支**：
    *   切換至 `BaseBranch` (預設 `master`)。
    *   **正常模式**：執行 `pull` 更新；**離線模式**：僅切換不更新。
    *   刪除舊有的 `TargetBranch` (若存在會先記錄最後 Commit 資訊) 並重新建立。
4.  **依序合併**：
    *   **檢查分支**：
        *   **正常模式**：檢查 `origin/<BranchName>` 是否存在。
        *   **離線模式**：檢查本地 `<BranchName>` 是否存在。
    *   **嘗試合併**：執行 `git merge --no-commit --no-ff`。
    *   **衝突處理**：若發生衝突，自動執行 `git checkout --theirs .` 並將原始 Git 衝突訊息附加至 Commit。
    *   **記錄狀態**：將成功、失敗或衝突解決的結果記錄至報告清單。
5.  **產出報告**：在倉庫根目錄產生 Markdown 格式的合併報告檔案。

## 合併目標邏輯 (Merge Target Logic)

本工具的核心設計原則為「**以遠端伺服器版本為準 (Source of Truth)**」，以確保整合環境的一致性。

| 模式 | 參數 | 合併對象 | 說明 |
| :--- | :--- | :--- | :--- |
| **預設 (連線)** | (無) | `origin/<BranchName>` | **優先使用遠端版本**。<br>腳本會先執行 `fetch` 更新，確保合併內容為伺服器上的最新代碼。若本地有未推送的修改，預設模式下將被忽略。 |
| **離線模式** | `-Offline` | `<BranchName>` | **使用本地版本**。<br>跳過所有網路操作，直接合併您本地電腦中的分支。適用於無網路環境或測試本地實驗性功能。 |

## 使用方式

### 語法


## 參數說明

| 參數 | 必填 | 預設值 | 說明 |
| :--- | :---: | :--- | :--- |
| `-RepoPath` | 是 | - | 本地 Git 倉庫的根目錄路徑 (包含 .git 的資料夾)。 |
| `-TargetBranch` | 是 | - | 要合併進去的目標分支名稱 (例如 `SIT_Integration`)。若分支已存在會被重置。 |
| `-CsvPath` | 是 | - | 包含合併清單的 CSV 檔案完整路徑。 |
| `-BaseBranch` | 否 | `master` | 目標分支的基底來源，每次執行會先切到此分支更新後，再建立目標分支。 |
| `-Offline` | 否 | `$false` | 離線模式。開啟後不執行 `fetch/pull`，且僅合併本地已存在的同名分支。 |
| `-Help` | 否 | - | 顯示參數用法說明。 |

## 執行範例

### 批次檔範例 (CMD/命令提示字元)

**基本合併作業：**
```cmd
.\run_auto_merge.bat -RepoPath "D:\Projects\rep_robbinLab" -TargetBranch "SIT_Integration" -CsvPath "D:\Docs\merge_list.csv"
```

**離線模式執行：**
```cmd
.\run_auto_merge.bat -RepoPath "D:\Projects\rep_robbinLab" -TargetBranch "SIT_Offline" -CsvPath "D:\Docs\list.csv" -Offline
```

### PowerShell 範例

**指定基底分支範例 (例如基於 `main`)：**
```powershell
.\auto_merge_flow.ps1 -RepoPath "D:\Projects\rep_robbinLab" -TargetBranch "UAT_Build" -BaseBranch "main" -CsvPath "D:\Docs\uat_list.csv"
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

---

## 開發者資訊 (Developer Info)

*   **Author**: robbin0919
*   **Last Updated**: 2026-01-10
*   **Project**: Git Auto Merge Tool