# Git-Automation-Workflow

本專案包含多個 Git 自動化流程工具，旨在簡化日常開發與整合流程。

This project contains several Git automation workflow tools designed to simplify daily development and integration processes.

## 工具說明 (Tool Descriptions)

### 1. [archive_changes](./archive_changes/) - Git 變更檔案打包工具 (Git Change Archiver)
*   **用途**: 比對兩個 Git 分支間的差異，並將變更的檔案按原始目錄結構打包成 ZIP 壓縮檔。
*   **特色**: 支援中文檔名、自動生成執行報告、簡化版本發布前的檔案提取。
*   **Purpose**: Compares differences between two Git branches and archives the changed files into a ZIP file while maintaining the original directory structure.
*   **Features**: Supports Chinese filenames, automatically generates execution reports, and simplifies file extraction before release.

### 2. [auto_merge_flow](./auto_merge_flow/) - 自動化 Git 分支合併工具 (Auto Merge Flow)
*   **用途**: 依據 CSV 清單自動將多個功能分支合併至目標分支（如 SIT/UAT）。
*   **特色**: 自動處理衝突（採用 "Take Theirs" 策略）、生成詳細的 Markdown 合併報告、支援離線模式。
*   **Purpose**: Automatically merges multiple feature branches into a target branch (e.g., SIT/UAT) based on a CSV list.
*   **Features**: Automatically handles conflicts (using "Take Theirs" strategy), generates detailed Markdown merge reports, and supports offline mode.

### 3. [Git_Blob_Header](./Git_Blob_Header/) - Git Blob 大小計算工具 (Git Blob Size Calculator)
*   **用途**: 計算檔案在 Git 內部存儲為 Blob 物件時的完整大小（包含 Git Header）。
*   **特色**: 提供 Shell 與 Batch 腳本、詳細顯示 Header 與原始檔案的大小資訊。
*   **Purpose**: Calculates the full size of a file when stored as a Git Blob object (including the Git Header).
*   **Features**: Provides Shell and Batch scripts, detailing the sizes of both the header and the original file.