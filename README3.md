# Git 變更檔案打包工具設計文件

## 1. 功能概述

**create-diff-archive_line_end_style_DOS.bat** 是一個專為 Windows 環境設計的 Git 工具，主要功能包括：

- 提取 Git 倉庫中兩個分支之間的差異檔案
- 將 Unix 風格換行符（LF）自動轉換為 Windows 風格（CRLF）
- 保留原始檔案編碼和二進制特性
- 將處理後的檔案打包為 ZIP 格式
- 提供詳細的執行報告和統計資訊

## 2. 系統架構

此工具採用混合架構，結合了以下技術：

- **批處理腳本**：提供主要的流程控制和參數處理
- **Git 命令**：用於分支比較和檔案提取
- **PowerShell 腳本**：處理換行符轉換和檔案編碼
- **檔案系統操作**：處理臨時文件和目錄管理

### 架構圖：
```
┌───────────────────┐     ┌─────────────────────┐
│  參數解析與驗證    │ ──> │  Git 分支差異分析    │
└───────────────────┘     └──────────┬──────────┘
                                    │
┌───────────────────┐     ┌─────────┴──────────┐
│  ZIP 壓縮打包      │ <── │  換行符轉換處理     │
└─────────┬─────────┘     └────────────────────┘
          │
┌─────────┴─────────┐     ┌─────────────────────┐
│  執行報告生成      │ ──> │  臨時資源清理        │
└───────────────────┘     └─────────────────────┘
```

## 3. 換行符轉換設計

### 3.1 檔案類型識別

工具支援多種常見的文字檔案類型，通過副檔名識別：

- **程式碼檔案**：`.js`, `.java`, `.cs`, `.cpp`, `.h`, `.c`, `.php`, `.py`, `.vb`
- **網頁檔案**：`.html`, `.htm`, `.css`, `.xml`, `.aspx`
- **文件檔案**：`.txt`, `.md`, `.json`, `.yaml`, `.yml`, `.config`
- **資料庫腳本**：`.sql`, `.prc`, `.fnc`, `.trg`, `.vw`, `.spc`, `.bdy`, `.seq`, `.tab`, `.idx`, `.tps`
- **批次檔**：`.bat`, `.cmd`, `.ps1`

### 3.2 二進制換行符轉換機制

換行符轉換採用位元組層級操作，避免編碼問題：

1. **檢測階段**：
   ```powershell
   for($i = 0; $i -lt $bytes.Length - 1; $i++) {
     if($bytes[$i] -eq 10 -and ($i -eq 0 -or $bytes[$i-1] -ne 13)) {
       $needConversion = $true
       break
     }
   }
   ```

2. **轉換階段**：
   ```powershell
   $newBytes = New-Object System.Collections.ArrayList
   for($i = 0; $i -lt $bytes.Length; $i++) {
     if($bytes[$i] -eq 10 -and ($i -eq 0 -or $bytes[$i-1] -ne 13)) {
       [void]$newBytes.Add(13) # 先加入 CR
     }
     [void]$newBytes.Add($bytes[$i])
   }
   ```

3. **優點**：
   - 保留原始二進制特性
   - 不改變檔案編碼
   - 只轉換需要轉換的部分
   - 避免重複轉換

## 4. 檔案提取流程

### 4.1 差異檔案識別

使用 `git diff-tree` 命令獲取兩個分支間的變更檔案：
```bat
git diff-tree -r --name-only --diff-filter=ACMRT %SOURCE_BRANCH% %TARGET_BRANCH% > "%TEMP_DIR%\filelist_utf8.txt"
```

### 4.2 檔案編碼處理

處理中文路徑問題，將 UTF-8 檔案清單轉換為 BIG5 編碼：
```bat
powershell -Command "$content = Get-Content -Path '%TEMP_DIR%\filelist_utf8.txt' -Encoding UTF8; [System.IO.File]::WriteAllLines('%TEMP_DIR%\filelist.txt', $content, [System.Text.Encoding]::GetEncoding(950))"
```

### 4.3 檔案提取

從目標分支提取每個檔案的內容：
```bat
git cat-file -p %TARGET_BRANCH%:"%%f" > "!target_file!" 2>nul
```

## 5. 執行報告設計

報告包含豐富的執行信息，分成四個主要區塊：

### 5.1 Repository 信息
- 本地路徑
- 遠端 URL
- 當前分支和提交

### 5.2 同步狀態
- 最後 Fetch 時間
- 最後 Pull 時間
- 與當前時間的差距

### 5.3 打包信息
- 源分支與目標分支
- 檔案總數與成功提取數
- ZIP 檔案大小和位置

### 5.4 操作完成信息
- 完成時間
- 開發者信息

## 6. 技術挑戰與解決方案

### 6.1 檔案編碼問題

**挑戰**：中文路徑在批處理中可能出現亂碼。  
**解決方案**：
- 使用 PowerShell 處理編碼轉換
- 配置 Git `core.quotepath false`

### 6.2 換行符處理精確性

**挑戰**：需要精確識別並僅轉換單獨的 LF。  
**解決方案**：
- 使用二進位讀寫，而非文字處理
- 精準檢查每個位元組

### 6.3 PowerShell 執行策略

**挑戰**：PowerShell 執行策略可能限制腳本運行。  
**解決方案**：
- 使用 `-ExecutionPolicy Bypass` 參數
- 腳本執行後立即刪除臨時 PS1 檔案

## 7. 使用指南

### 7.1 基本使用

```
create-diff-archive_line_end_style_DOS.bat [輸出檔名] [源分支] [目標分支]
```

### 7.2 具名參數格式

```
create-diff-archive_line_end_style_DOS.bat -F [輸出檔名] -S [源分支] -T [目標分支]
```

### 7.3 預設值

- 輸出檔名：`APP_SIT.zip`
- 源分支：`master`
- 目標分支：`SIT`

## 8. 擴展與維護建議

### 8.1 潛在改進

1. **支援更多壓縮格式**：擴展對 7z、tar.gz 等格式的支援
2. **自動化測試**：增加驗證轉換結果的檢查機制
3. **增強錯誤處理**：添加重試邏輯和更詳細的錯誤報告
4. **圖形介面**：開發基於 PowerShell 的簡易 GUI
5. **增加忽略清單**：支援指定不需要轉換的檔案類型

### 8.2 維護指南

1. **文件類型擴展**：在 `$fileTypes` 數組中添加新的副檔名
2. **編碼處理調整**：根據專案需求修改編碼轉換部分
3. **報告格式調整**：可依需求調整執行報告的輸出格式
4. **效能優化**：大型倉庫可考慮使用並行處理技術

---

設計者：Robbie Lee  
文件版本：1.0  
最後更新：2025-04-27