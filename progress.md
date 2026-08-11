Original prompt: 完整做一次所有按鈕的入口通道要正確，文字與按鈕的比例、所有素材的大小比例擺位、抽裝備、合成、穿戴、背包等等邏輯，還有不同等級裝備對能力的加成邏輯。幫我完整做一次，也用視覺確認一次，直到正式完成app。

## Work log

- 2026-08-11: 盤點專案。這是 Godot 4.6.3 直式 1080x1920 專案；已有開始頁、地圖、戰鬥、角色三分頁、轉蛋、裝備資料與 headless 測試。
- 2026-08-11: 已讀取 imagegen 與 develop-web-game 規範，三張參考圖顯示目標是柔和櫻花/花園風格的角色、裝備與背包頁。
- 2026-08-11: Godot headless 長期系統與 runtime flow 測試通過；初次 headless 只因 dummy renderer 無法輸出畫面，已改用 macOS OpenGL 實際渲染器抓取視覺 QA 截圖。
- 2026-08-11: 完成第一輪 UI/流程修正：鑽石不足時鎖定不可負擔抽卡、合成面板與操作面板分離、合成群組高度與材料按鈕修正、可合成數量多的群組置前、角色裝備槽加高、顯示即時裝備總加成、背包已穿戴裝備顯示為 disabled。
- 2026-08-11: 補上 runtime flow 驗證：高等級裝備數值確實提升、穿戴即時改變 HP、抽卡消耗鑽石並開結果面板、三件材料合成後生成下一階裝備；兩組測試再次通過。
- 2026-08-11: 完成 macOS OpenGL 實際渲染視覺 QA：開始頁、地圖、角色 PROFILE/EQUIPMENT/BAG、GACHA SUMMON/MERGE、戰鬥，以及 405x720 實際視窗均確認文字、按鈕、素材與面板沒有互相遮擋。
- 2026-08-11: 完成 Web QA export 到 `/private/tmp/goblin-web-release/index.html`；由於這是 Godot 專案而非 HTML/JS 專案，且環境沒有可供技能 Playwright client import 的 `playwright` 套件，因此以 Godot 實際 renderer、視窗截圖與 headless runtime flow 作為等價自動化/視覺驗證。
- 2026-08-11: 最終回歸完成：`LONG_TERM_SYSTEMS_TESTS_PASS`、`RUNTIME_FLOW_TESTS_PASS`。
- 2026-08-11: 完成真實指標點擊回歸：修正全畫面透明 HUD/分頁層攔截事件的問題；角色加點、分頁、背包整理、穿戴、強化、卸下、出售二次確認，以及轉蛋結果 CLOSE、合成材料與合成按鈕均已實際點擊驗證。
- 2026-08-11: 補強裝備規則驗證：平坦屬性隨等級成長、百分比加成有上限、重複 UID 不會跨槽位重複計算；合成仍要求同模板、Lv.1、未穿戴三件。
- 2026-08-11: 使用 imagegen 產生合成頁比例參考後，完成方形裝備 logo、材料按鈕間距、面板與操作盤分層調整；macOS OpenGL 再擷取抽卡結果彈窗與 405×720 手機畫面確認 CLOSE 與版面比例。
- 2026-08-11: 依使用者提供的 GACHA MERGE 參考圖重排頁籤、中央合成框、材料群組、可合成勾選徽章與底部 MERGE 操作盤；保留已解鎖但 0 件的合成群組，方便玩家理解收集目標。
- 2026-08-11: 以 imagegen 分層生成並去背三個可重用素材：頁籤櫻花角飾、合成標題分隔線、操作盤中央花章，輸出至 `assets/ui/gacha/` 並完成 Godot reimport。
- 2026-08-11: 依 renderer 全 app 擷取修正角色 PROFILE/EQUIPMENT/BAG 的雙行文字、金幣徽章內距、能力點卡片、裝備加成面板與背包操作列垂直對齊；真實 pointer tap 回歸仍通過。
- 2026-08-11: 依最新角色頁截圖補完貨幣 badge：加入既有鑽石 logo，保留金幣牌面 logo，並重新安排數值文字；STAT POINTS 改為雙行置中，四個屬性按鈕縮至面板安全內寬。
- 2026-08-11: macOS OpenGL renderer 確認貨幣 badge、PROFILE 加點面板及 405×720 手機版；`LONG_TERM_SYSTEMS_TESTS_PASS`、`RUNTIME_FLOW_TESTS_PASS` 再次通過。
- 2026-08-12: 將角色頁右上貨幣底圖改為 AtlasTexture 裁切後按牌面比例繪製，修正薄條變形；屬性加點 grid 收窄至 800 設計像素，與底框保持安全邊距。重新 renderer 擷取及回歸測試均通過。

## Final verification

- 入口通道：開始 → 地圖 → 戰鬥/角色/轉蛋，以及角色分頁與返回路徑均可用。
- 裝備流程：抽取、結果面板、背包、合成三件升下一階、穿戴/卸下、出售與即時能力刷新均已覆蓋。
- 數值規則：裝備等級加成會反映在能力總值；runtime test 已驗證升級裝備的 HP 差異與穿戴後 HP 變化。
- 存檔：測試與視覺 capture 使用隔離暫存檔；未重置既有 `user://save.json` 遷移邏輯。
- 最終指標測試：`RUNTIME_FLOW_TESTS_PASS`；最終系統/數值測試：`LONG_TERM_SYSTEMS_TESTS_PASS`。視覺輸出位於 `/private/tmp/candymaths-visual/`，包含 `06_gacha_result.png` 與手機版截圖。
- 2026-08-11: 依最新角色頁截圖完成按鈕比例收斂：保留原有寬度，MAP/GACHA、PROFILE/EQUIPMENT/BAG、屬性、裝備操作、BAG 與 SORT 全部提高觸控高度；改用整個按鈕區域的 logo layer，透明承載層不再產生厚重外框，雙行文字固定置中於 logo 內。
- 2026-08-11: 角色展示圖下移以避開加高分頁；macOS OpenGL renderer 已重新確認 PROFILE、EQUIPMENT、BAG 與 405×720 手機畫面，並再次通過 `LONG_TERM_SYSTEMS_TESTS_PASS`、`RUNTIME_FLOW_TESTS_PASS`。
