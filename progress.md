Original prompt: 完整做一次所有按鈕的入口通道要正確，文字與按鈕的比例、所有素材的大小比例擺位、抽裝備、合成、穿戴、背包等等邏輯，還有不同等級裝備對能力的加成邏輯。幫我完整做一次，也用視覺確認一次，直到正式完成app。

## Gacha button size plan — 2026-09-08

- 本次按明確計劃將 MAP 高度設為 128、三個抽卡操作鍵設為 144（接手時為 160／176）；保留寬度、位置、現有皮膚與文案、費用、disabled 和訊號。鎖頭沿用依高度計算的垂直置中。
- 尺寸與 96×96 觸控區回歸通過；`/private/tmp/gacha-size-runtime.log` = RUNTIME_FLOW_TESTS_PASS，涵蓋真實輸入單抽、結果關閉及模式切換；返回目前驗證訊號連線，未新增實際跨場景點擊驗證。`/private/tmp/gacha-size-systems.log` = LONG_TERM_SYSTEMS_TESTS_PASS。
- visual_capture 改為目標像素尺寸搭配 1080×1920 邏輯畫布 stretch，不再將大圖縮小。直接渲染並目視 1080×1920 與 405×720 轉蛋圖：文字完整包覆、鎖頭置中、說明及邊框無重疊；這是 SubViewport 渲染，非真機／原生視窗安全區驗證。輸出 `/private/tmp/candymaths-visual/07_gacha_summon.png`、`14_mobile_gacha.png`，log 為 `/private/tmp/gacha-size-direct-visual.log`。
- 2026-09-09：補上空背包的明確狀態面板，並讓角色與轉蛋貨幣徽章依數字位數自適應字級；新增空背包、長貨幣值的 runtime 邊界檢查。`/private/tmp/ui-quality-runtime-final.log` = RUNTIME_FLOW_TESTS_PASS，`/private/tmp/ui-quality-systems-final.log` = LONG_TERM_SYSTEMS_TESTS_PASS。
- 2026-09-09：macOS OpenGL renderer 完成 26/26 張視覺回歸，包含 `23_character_empty_bag.png`、`24_character_long_values.png`、`25_gacha_long_values.png`；轉蛋 1080×1920／405×720 畫面再次確認文字完整、按鈕底圖與鎖頭位置正確。standalone 原生視窗可建立但本機 CUA 只捕捉到 Godot 啟動底色，未將此環境的原生點擊檢查宣稱為通過，也未修改使用者存檔。
- 2026-09-09：戰鬥 HUD 改用現有心形素材建立滿／半／空生命狀態列，並用鑽石素材呈現勝利獎勵；修正心形圖示在 HBox 中被壓成 0 寬的布局問題。`ui-battle-health-visual-final.log` 完成 26/26 視覺輸出。
- 2026-09-09：補上 405×720 的地圖、轉蛋結果／合成、戰鬥暫停／勝利等狀態，macOS OpenGL 視覺回歸已完成 31/31 張（`/private/tmp/ui-mobile-surfaces-visual-rerun.log`）。目視確認手機尺寸下文字、按鈕皮膚、生命圖示、彈窗與底部操作區沒有裁切或重疊；長鑽石數值也維持在 badge 內。原生視窗仍保留啟動底色捕捉限制，未將其宣稱為真機安全區驗證。
- 2026-09-09：修正 visual capture 在 `--disable-vsync` 下只等幀數而可能截到淡入中畫面的問題；長等待補足 0.5 秒實際動畫時間後，`/private/tmp/ui-settled-visual.log` 再次完成 31/31，角色頁文字對比與面板顏色以 settled state 重新確認。
- 2026-09-09：地圖初始定位新增固定標題下方 28px viewport gutter，並在底端定位保留 96px edge padding；第 3 關節點不再被捲動邊界或頂部資訊卡裁切，底部章節／主導航仍維持原位置。`/private/tmp/ui-map-edge-visual-rerun.log` 完成 31/31 視覺輸出，runtime 新增安全緩衝 invariant 並通過。
- 2026-09-09：地圖修正後最終回歸再次通過：`/private/tmp/ui-map-edge-runtime-final.log` = `RUNTIME_FLOW_TESTS_PASS`（含目前關卡不遮住底部操作列檢查），`/private/tmp/ui-map-edge-systems-final.log` = `LONG_TERM_SYSTEMS_TESTS_PASS`；`git diff --check` 通過。
- 2026-09-09：將戰鬥倒數與答題回饋整理成固定高度、高對比狀態卡；錯誤回饋區增至 72px，兩行文案與數字鍵保持安全間距。角色出售提示與轉蛋合成提示使用同一套底部 toast 規格。`/private/tmp/ui-status-runtime-flow.log` = `RUNTIME_FLOW_TESTS_PASS`、`/private/tmp/ui-status-runtime.log` = `LONG_TERM_SYSTEMS_TESTS_PASS`，`/private/tmp/ui-status-visual.log` 完成 37/37（含 1080×1920／405×720 戰鬥回饋、角色提示、轉蛋提示）並已目視確認無裁切或重疊。
- 2026-09-09：將地圖、角色頁／角色選擇器與轉蛋清單的 ScrollBar 收斂為共用粉彩皮膚，並修正角色拖曳最大值使用 `max_value - page`；戰鬥與地圖狀態文案移除跨平台 emoji，統一為 `EXP`／`COINS`／`AUTO`／`DROP`／`GEMS`／星星等可讀文字。視覺擷取加入 0.12 秒 GPU settle，`/private/tmp/ui-scrollbar-visual-settled.log` 完成 37/37 且無 `Skipping`；`/private/tmp/ui-scrollbar-runtime-flow.log` = `RUNTIME_FLOW_TESTS_PASS`、`/private/tmp/ui-scrollbar-systems.log` = `LONG_TERM_SYSTEMS_TESTS_PASS`。
- 2026-09-09：補回角色頁寬版按鍵的既有作者皮膚：分頁、主角選擇、背包排序、裝備操作、穿戴／強化／出售與角色卡操作會依實際寬高套用素材；方形 MAP／GACHA 快捷鍵保留圓角底，避免橫向素材變形。runtime 新增角色皮膚 invariant 並通過；最新 OpenGL 視覺擷取完成 37/37，結果位於 `/private/tmp/candymaths-visual/`。
- 2026-09-09：修正隱藏中的 EQUIPMENT 分頁寬按鍵不會套用作者皮膚的時機問題：寬版判斷改依建立規格處理，不再等待隱藏容器先完成 layout；新增 `OpenBagButton` 皮膚檢查與 layout settle 後的真實點擊入口回歸。修正後 `/private/tmp/ui-openbag-runtime-final.log` = `RUNTIME_FLOW_TESTS_PASS`、`/private/tmp/ui-openbag-systems-final.log` = `LONG_TERM_SYSTEMS_TESTS_PASS`，OpenGL 視覺擷取重新完成 37/37。
- 2026-09-09：補上共用 safe-area bottom margin：角色頁與轉蛋頁的訊息 Toast 會依實際 viewport safe-area 與至少 64px 的產品底距離定位，避免手機底部手勢區裁切；新增 runtime 邊界檢查。`/private/tmp/ui-safe-bottom-runtime.log` = `RUNTIME_FLOW_TESTS_PASS`、`/private/tmp/ui-safe-bottom-systems.log` = `LONG_TERM_SYSTEMS_TESTS_PASS`、`/private/tmp/ui-safe-bottom-visual.log` = `VISUAL_CAPTURE_DONE 37`。405×720 原生 Godot 視窗在目前環境仍只能取得啟動底色，因此未將它列為可靠的真機畫面證據。
- 2026-09-09：視覺回歸 runner 改為共用單一 SubViewport，並將「實際寫檔數」與「嘗試數」分開計算；若 renderer 跳過任何畫面，runner 現在會以失敗結束，不再只輸出誤導性的 DONE。新增 393×852 長手機比例的地圖、角色、轉蛋、戰鬥與勝利彈窗覆蓋；`/private/tmp/ui-common-phone-visual-shared-viewport.log` = `VISUAL_CAPTURE_DONE 42`，五張長比例畫面均已目視確認固定 HUD、操作區與彈窗沒有漂移。
- 2026-09-09：補強入口回歸檢查：地圖底部 HOME／CHARACTER／GACHA、角色 BACK 的 signal wiring 與 96px 觸控區均確認；戰鬥暫停／恢復改用實際指標點擊驗證。`/private/tmp/ui-entry-runtime-final.log` = `RUNTIME_FLOW_TESTS_PASS`，`/private/tmp/ui-entry-systems-final.log` = `LONG_TERM_SYSTEMS_TESTS_PASS`；37/37 settled 視覺回歸仍有效，原生安全區限制維持如前。
- 2026-09-09：地圖底部 HOME／CHARACTER／GACHA 補上不切換場景的真實 pointer `gui_input` 回歸，並在測試後接回正式 action callback；`/private/tmp/ui-map-nav-pointer-test-fixed.log` = `RUNTIME_FLOW_TESTS_PASS`，`/private/tmp/ui-map-nav-pointer-systems-fixed.log` = `LONG_TERM_SYSTEMS_TESTS_PASS`。前次失敗是測試點擊 HOME 觸發正式場景切換造成 runner 提前釋放，已以測試隔離修正，未改變產品輸入流程。
- 2026-09-09：視覺 runner 補上場景建立與 PNG 寫入失敗的嚴格計數；以 OpenGL renderer 重新完成 `/private/tmp/ui-common-phone-visual-final.log` = `VISUAL_CAPTURE_DONE 42`。目視檢查 393×852 長手機的地圖、角色、轉蛋、戰鬥與勝利彈窗，固定 HUD、按鍵、說明文字、彈窗及底部手勢安全距離均無裁切或重疊。
- 2026-09-09：直接啟動 standalone Godot 405×720 視窗並目視確認開始頁、地圖、轉蛋、角色、目前關卡戰鬥與暫停彈窗；標題列與底部手勢區未裁切 UI，MAP／導覽／暫停按鈕可實際點擊，文字與底圖比例穩定。此前僅能捕捉啟動底色的環境限制已解除；本次未進行抽卡、答題或會改寫存檔的操作。
- 2026-09-09：依 `Web QA` preset 以 Godot 4.6.3 export-release 重新打包公開 Web bundle；`web/index.pck` 與 `web/index.html` 已更新，HTML／JS／WASM／音效 worklet／icon 均通過輸出檔案檢查，未把 build、tests 或 `.godot` 暫存產物加入版本庫。
- 本次依 frontend-skill 檢查文字包覆與間距；未擴大修改其他 UI，工作區既有變更保留。

## UI quality goal — completed 2026-09-09

- 完成稽核：開始頁、地圖、角色 PROFILE／EQUIPMENT／BAG／角色選擇、轉蛋 SUMMON／MERGE／結果／自動合成、戰鬥／暫停／勝敗的版面、文字、素材比例、對比、safe-area 間距與互動入口均已完成；runtime、長期系統、42 張 OpenGL 視覺回歸及 standalone 405×720 直接畫面檢查全部通過。

- 第三輪：單抽結果縮至 760 高置中，十抽 1360 高；結果內距 128、預覽 138。勝敗卡依實際獎勵內容最小高度自動長高，增加上下 64 內距。背包／裝備／結果名稱使用深棕，獎勵綠字改深綠。
- 合成頁拖曳現在依頂層彈窗選擇正確 ScrollContainer，支援十抽結果與自動合成預覽；runtime 新增真實 touch drag 十抽驗證與拖曳後 CLOSE 操作，ui-scroll-tested.log = RUNTIME_FLOW_TESTS_PASS。
- visual_capture 現在涵蓋含升級＋章節＋掉落的勝利、失敗、十抽、空背包、長數值，以及地圖／轉蛋結果／合成／戰鬥暫停／勝利的多尺寸畫面；已目視 1080×1920、405×720 與 393×852。standalone 405×720 原生視窗後續也已直接確認，先前的啟動底色捕捉限制已解除。

- 第二輪已完成：合成材料改成六欄換行、移除七件截斷、格高 184 容納已裝備副標，未選取圓圈不再顯示勾號；角色總覽 620 高／68 內距及自適應文字寬；戰鬥 HP 改深莓紅。結果與自動合成預覽改安全內距和彈性清單高度。
- 擴充 visual_capture 到 20 種狀態，新增 20 件材料、三件選取、8 組自動合成預覽、戰鬥暫停。已開啟檢查最新 17/18/19 以及角色總覽、單抽結果；ui-modal-runtime.log 顯示 RUNTIME_FLOW_TESTS_PASS。預覽和結果標題／按鈕仍接近花框，後续宜再增加上下內距並改善單抽的大面積留白；未完成整體上架驗收。

- 全 UI 達上架品質仍未完成；本輪重新渲染 16 個畫面，確認先前「完整包覆、沒有重疊」結論過度樂觀。
- 已修正共用皮膚透明留白：快取裁切後的 ImageTexture，完整縮放手繪素材，避免不適用的九宮格切片將外框拉成粗橫條。移除全域標籤重影；disabled 皮膚改用淺中性色。
- 轉蛋操作面板增加 64 內距、操作文案縮為兩行，按鈕標題 30 並保留內距。runtime flow 通過（最後完整縮放修正後需再回歸）。最新畫面位於 /private/tmp/candymaths-visual，render4 log 記錄本輪結果。
- 下一步：逐頁完成角色資訊卡內距與小字、背包按鈕與卡片邊界、合成材料文字和選取狀態、戰鬥 HUD 對比；擴充暫停、勝敗、購買、自動合成確認、多項結果、空背包、長數值與捲動到底的視覺覆蓋。手機目前是 1080 設計畫面縮圖，仍需真實視窗與長螢幕／安全區驗證。不得以目前窄範圍測試宣稱全 UI 達標。

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
- 2026-08-16: 依轉蛋頁最新視覺需求，將左上 MAP 按鈕高度調整為 160、1 抽／10 抽／Watch Ad 按鈕高度調整為 176，並將 Watch Ad 鎖頭圖垂直置中；補上 runtime 尺寸回歸檢查，未改動抽卡、廣告或返回邏輯。
- 2026-08-16: 完成轉蛋頁視覺回歸；1080×1920 與 405×720 截圖確認 MAP／地圖及三個抽卡按鈕文字完整落在 logo 內，鎖頭置中且沒有版面裁切。`RUNTIME_FLOW_TESTS_PASS` 與 `LONG_TERM_SYSTEMS_TESTS_PASS` 均通過。

## Systems batch — 2026-09-17

- 選擇主角彈窗水平滑動修正：`character.gd` 的 `_input` 改為依 `_get_active_scroll()` 分流，選擇器開啟時拖曳導向 `CharacterCardScroll`（新增水平軸拖曳，HScrollBar `max_value - page` clamp，12px 門檻保留），購買確認彈窗開啟時不捲動。runtime 新增真實 touch drag 水平捲動回歸。
- 體力制度上線：上限 20、每關消耗 1（戰敗 RETRY 同樣消耗，不足時按鈕 disabled、可返回地圖）、每 10 分鐘回 1 點（存檔欄位 `stamina`／`stamina_updated_at`，`GameBalance.apply_stamina_regen` 統一離線結算與倒數數學；`updated_at=0` 視為無時間戳、不發離線補貼）、看廣告回 5 點（`RewardedAdService.request_reward(kind)` 支援 gems/stamina，signal 改為 `reward_completed(kind, amount)`；debug build 無廣告 SDK 時直接發放）。地圖底部新列顯示 `體力 X/20 · MM:SS 後 +1` + WATCH AD 按鈕（1 秒刷新），體力不足點關卡顯示 toast 並阻擋。
- 取消戰鬥掉落：`apply_victory` 移除 `_roll_and_store_drop`／`dropped_item`／`auto_salvage_coins`，刪除 `EquipmentSystem.roll_drop`／`starter_item`／`loot_pity`；新存檔改為空背包（無初始武器），既有存檔不受影響；勝利畫面移除 DROP 列；空背包文案改為引導轉蛋。合成／強化／出售／穿戴保留（素材僅來自轉蛋）。
- 抽裝備 0 鑽測試：`gacha.json` 新增 `test_cost_enabled/test_single_cost/test_ten_cost`（同角色測試價模式）；`GachaSystem.pull_cost` 回傳有效價、`roll` 允許 0 元免費抽（跳過鑽石檢查）；轉蛋按鈕顯示「免費 FREE」且不因鑽石不足 disabled；恢復正式價格只需將 flag 改 false。
- 測試同步：vertical_slice 更新（新存檔空背包、掉落移除、0 鑽抽卡、體力單元數學／門檻／廣告回復），runtime_flow 新增 `_test_stamina_gate`（地圖體力 HUD、0 體力阻擋＋toast、debug 廣告 +5）與選擇器水平拖曳、免費抽不扣鑽檢查；`visual_capture` 移除 `dropped_item`。`LONG_TERM_SYSTEMS_TESTS_PASS`、`RUNTIME_FLOW_TESTS_PASS`（兩次）、OpenGL 視覺擷取 42/42 並目視地圖體力列、選擇器、轉蛋免費標示。

## iOS Xcode project — 2026-09-17

- 原本 repo 沒有 Xcode 專案；以 `iOS Xcode` preset（export_project_only）生成 `build/ios/GoblinLeveling.xcodeproj`（build/ 已 gitignore，可隨時重新匯出）。
- 修復三項匯出阻擋：① `export_presets.cfg` 填入本機憑證對應的 App Store Team ID `8YJDJ64XYS`；② 啟用 `rendering/textures/vram_compression/import_etc2_astc=true`（Godot 4.6.3 iOS 匯出在 macOS 上必備，否則 CLI 只回報空白 configuration errors）；③ 以 PIL 生成 1024×1024 App icon `assets/ui/start/app_icon_v1.png`（哥布林素材＋app 粉彩漸層）並設定 `config/icon`。
- AdMob：`ios_export.cfg` is_real=true，Release App ID 已嵌入 Info.plist；無 mediation 故略過 Podfile。
- 驗證：`xcodebuild -sdk iphoneos CODE_SIGNING_ALLOWED=NO`（arm64 真機）與 `-sdk iphonesimulator ARCHS=x86_64` 均 BUILD SUCCEEDED。注意：官方 Godot 4.6.3 ios.zip 的模擬器切片只含 x86_64 objects（Info.plist 卻宣告 arm64），Apple Silicon 模擬器需以 x86_64/Rosetta 跑或直接真機測試；真機簽名需在 Xcode 選團隊（DEVELOPMENT_TEAM 已寫入）。
- 頭less 兩套測試在 icon／etc2_astc 變更後重跑仍通過。
- 2026-09-17：修正 Xcode「conflicting provisioning settings」— `export_presets.cfg` 將 debug／release code sign identity 明確設為 `Apple Development`（原本留空時 release 會被 Godot 預設成 `Apple Distribution`，與自動簽名衝突）；重新匯出後 device build 仍 BUILD SUCCEEDED。

## 三語國際化（繁中／英文／日文）— 2026-09-17

- 新增 `LanguageManager` autoload（語言碼 zh_tw/en/ja，存進 save.json `language` 欄位，normalize 驗證；`t(key)`／`tf(key, args)`／`pair(key, args)` 查表）。`pair` 保證 zh_tw 模式輸出與舊雙語排版逐字相同（`zh`＋`zh2` 雙行），en/ja 為單行顯示；GDScript `%` 要求參數精確匹配，故只格式化含佔位符的字串。
- 翻譯表 `data/i18n.json`：219 個 key × 三語（含所有 toast、按鈕、HUD、獎勵、稀有度、合成流程）。資料 JSON 全數加上 `name_ja`（怪物／裝備／關卡／角色含 description_ja），endless 關卡與 zone 名同步日文化（`LanguageManager.pick()` 依語言取 name_zh/name/name_ja）。
- 字型：新增 M PLUS Rounded 1c（500/700，OFL）供日文；`UITheme.shared_font` 依語言選字型並依 role+language 快取。ChironGoRoundTC 缺 復從氣款 等字，翻譯文案已改寫避開；測試內建三語字型 glyph 涵蓋檢查。
- 六個畫面全部改用 key 式 helper（`make_tr_label`／`make_tr_dual`／`make_tr_en_dual`／`make_tr_button`／`make_pair_button`／`set_tr_button_text`）；battle 動態字串（stage/monster 名、combo、倒數、勝敗面板）與 gacha 合成預覽全部三語化。
- 切換入口：開始畫面右上三顆語言鈕（各語以自己的字型渲染，避免缺字）、地圖 header 語言循環鈕；切換後存檔並 `reload_current_scene()` 重建畫面。
- 測試：vertical_slice 新增 `_test_language_system`（預設 zh_tw、三語查表、資料 pick、存檔 round-trip、字型 glyph 涵蓋、循環順序）；runtime 新增 `_test_language_toggle`（開始畫面按鈕存檔、重建後英文文案、地圖循環鈕）與 `_test_language_layout`（三語下所有按鈕標籤不侵入其他按鈕）。既有兩套 headless 測試維持通過；OpenGL 視覺擷取 62/62（新增 en/ja 各 10 張開始／地圖／角色／轉蛋／戰鬥畫面），PIL 差異驗證三語皆有實際渲染變化。
- 2026-09-17：三語版本重新匯出 Xcode 專案（含 i18n.json 與 M PLUS 字型，pck ~29.5MB）；`xcodebuild` 真機 arm64 與模擬器 x86_64 均 BUILD SUCCEEDED（CODE_SIGNING_ALLOWED=NO，真機安裝需在 Xcode 選團隊簽名）。

## 即時玩家對戰（PvP）— 2026-09-21

- 制度：鏡像 PvE 攻擊制 — 伺服器以同一 seed 生成同組題目，雙方同時作答；答對照連擊加成攻擊對手（`calculate_damage`），答錯／逾時自身受創（`damage_taken(PVP_BASE_ATTACK, 0)`）；固定 HP 30／攻 10，題目參數取兩人已解鎖關卡較低者；每題 10 秒、倒數 3-2-1（0.8s/拍）；勝 30 金幣、敗／平 10 金幣；對戰扣 1 體力（match_found 時扣，rejoin 不重扣）。
- 網路層：`PvpNetwork` autoload（client 狀態機 + 權威伺服器雙模式）+ `pvp_protocol.gd` 常數（訊息／錯誤／結束原因／狀態）。傳輸用 high-level MultiplayerAPI + `WebSocketMultiplayerPeer`（autoload 與測試實例節點路徑同名 `/root/PvpNetwork` 使 RPC 對上）；所有訊息 `rpc_id` 點對點（絕不廣播，避免跨場洩漏）。伺服器模式：`--pvp-server` 參數或 `PVP_SERVER=1`，埠號取 `$PORT` 否則 9123。`bootstrap` 場景成為新 main scene：server 模式停留待命，一般客戶端轉跳主選單。
- 配對與房間：快速配對 FIFO 即時撮合；4 字元房間碼（去混淆字母集）、房間 120 秒過期（`ERR_ROOM_EXPIRED`）；無效房碼回 `ERR_INVALID_ROOM` 且客戶端回到大廳狀態。
- 斷線重連：比賽中斷線進入 10 秒重連視窗（`phase=reconnect`、token-based rejoin），對手端顯示倒數覆蓋層；rejoin 成功回補 match payload（resumed）＋當前題目（剩餘秒數不足補 3 秒寬限）；放棄／逾時判負 `opponent_forfeit`；主動離開判負 `you_left`（對手勝）。客戶端 `_process` 每 1.5s 自動重試連線（連線逾時 10s）。
- 畫面：`pvp_lobby`（暱稱編輯存檔、快速配對、開房／輸入房碼加入、狀態列、toast）＋ `pvp_battle`（雙方頭貼／HP 條／連擊、題目卡＋10 秒計時條、數字鍵盤、對答回饋、重連／結果覆蓋層）；開始畫面新增「玩家對戰」入口鈕（哥布林與冒險鈕之間，goblin 層下緣 0.72→0.70）。大廳／對戰場景 Panel 內改用 MarginContainer（Panel 的 margin theme constant 無效，會導致內容溢出）。
- i18n：`pvp.*` 33 keys × 三語。ChironGoRoundTC 為子集字型，實測缺 競技待朋友房代碼暱稱大廳伺其你 等字 — 文案改寫為「對戰場／通關號／玩家號／離開／連不上主機」等已覆蓋字；省略號全語系改 ASCII `...`（TC 拉丁無 U+2026）。字型涵蓋測試恢復通過。
- 伺服器部署：`Linux Server` export preset（dedicated_server、embed_pck、排除 build/tests/web）→ `build/server/goblin_pvp_server.x86_64`（96MB）；`Dockerfile.server`（debian-slim、非 root、`PVP_SERVER=1`、EXPOSE 9123）；客戶端伺服器位址優先序：`PVP_SERVER_URL` env → `data/server_config.json` `default_url`；README 補部署流程（Railway 第二個 service）。
- 測試：新增 `tests/pvp_flow_runner.tscn` 整合測試 — 以三個獨立 per-viewport `SceneMultiplayer` 網域跑真實本機 WebSocket 對戰：快速配對全場戰（同 seed、HP、回合結算、勝敗獎勵與金幣入帳）、房碼流程（開房／小寫房碼加入／对称傷害／離開判負）、斷線重連回補（HP 保留、token 互異、對手恢復通知）、放棄判負、無效房碼錯誤、體力精確扣 8。注意：SceneTree 只自動 poll 根 API，per-viewport 測試網域需每幀手動 `poll()`；`is_server_mode` 的環境偵測以 `_server_mode_resolved` 鎖定，避免 `_ready` 蓋掉測試預設。PvpNetwork 另暴露 last_round_payload/last_round_index/last_end_payload/last_error/last_room_code/opponent_offline_seen/current_question_index 供 UI 與測試輪詢。
- 驗證：`LONG_TERM_SYSTEMS_TESTS_PASS`、`RUNTIME_FLOW_TESTS_PASS`、`PVP_FLOW_TESTS_PASS`；OpenGL 視覺擷取 68/68（新增 zh/en/ja 大廳＋對戰 6 張，並修復 lobby toast 位置與名字面板排版）；`Linux Server` 匯出成功；Xcode 專案重新匯出後 `xcodebuild -sdk iphoneos CODE_SIGNING_ALLOWED=NO` BUILD SUCCEEDED；Web QA bundle 已更新至 `web/`。
