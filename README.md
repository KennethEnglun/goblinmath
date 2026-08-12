# 哥布林升級中

Godot 4.6.3、GDScript、離線本機 2D 心算 RPG。遊戲目前包含開始畫面、可捲動冒險地圖、World 1 十關、無限章節生成、計時敵人攻擊、HP／DEF／ATK、Combo、星級、裝備、升級、掉落、轉蛋、三件合成與本機存檔。

戰鬥的自動攻擊時鐘由前期約 7 秒逐步縮短至 2.8 秒公平下限；每十關 Boss 會有可感知但仍保留答題時間的加速。答題錯誤、DEF 減傷、Combo、星級與重玩獎勵都集中在 `scripts/managers/game_balance.gd`。

戰鬥右上角的 `Ⅱ / 暫停` 會停止敵人倒數並鎖住數字鍵盤；可選擇 `RESUME / 繼續答題` 或安全返回地圖。手機失去焦點時也會自動暫停敵人時鐘，回到遊戲後再繼續。

地圖 HUD 會顯示 World 1「花漾原野」；首次完成每章 Boss 返回地圖時會先置中剛完成的 Boss 節點，下一次進入則回到最高已解鎖關卡。

動態 UI 使用內嵌的 `assets/fonts/NotoSansCJKtc-Regular.otf`，並附帶 `assets/fonts/LICENSE.txt`；Web／iOS 不依賴裝置是否有繁中字體。

## 轉蛋與裝備合成

轉蛋頁位於 `scenes/gacha/gacha.tscn`，由 `scripts/gacha/gacha.gd` 與 `scripts/gacha/gacha_system.gd` 驅動。新存檔有 300 鑽石；單抽 100、十連 1000，首次通關每關獎勵 30 鑽石。稀有度依 Stage 4／8／10 逐步解鎖，Legendary 不會直接抽到，只能用三件相同模板、同稀有度、未穿戴的裝備合成下一階；三件材料等級不限，合成後固定為下一階 Lv.1，並退還材料過去支付的強化金幣。

目前 `WATCH AD / 觀看廣告 +100` 只是 disabled 介面，尚未接入真實廣告 SDK，不會偽造鑽石獎勵。轉蛋與合成結果會先寫入 `user://save.json`，背包不再截斷 120 件。

裝備圖示已改為 15 件模板各自的獨立素材，位於 `assets/equipment/items/`；資料中的 `generated_sprite` 會優先載入模板圖，缺圖時仍回退到 weapon／head／body 共用圖示。Rare 以上素材使用乾淨 chroma-key 去背與邊緣清理，生成原稿保留在 `output/imagegen/equipment/` 供後續替換。

## 開啟專案

使用 Godot 4.6.3 stable 開啟本目錄，主場景是 `scenes/main/main_menu.tscn`。設計解析度為 1080×1920，視窗預覽為 405×720。

## Headless 驗證

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --scene res://tests/test_runner.tscn
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --scene res://tests/runtime_flow_runner.tscn
```

成功時會分別輸出 `LONG_TERM_SYSTEMS_TESTS_PASS` 與 `RUNTIME_FLOW_TESTS_PASS`。

## 匯出準備

`export_presets.cfg` 提供 `Web QA` 與 `iOS Xcode` 兩個 preset。資源封裝可用：

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-pack "Web QA" /private/tmp/goblin-web.pck
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-pack "iOS Xcode" /private/tmp/goblin-ios.pck
```

Web release export 已用 Godot 4.6.3 templates 驗證，可輸出 HTML／WASM／PCK：

```sh
mkdir -p /private/tmp/goblin-web-release
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "Web QA" /private/tmp/goblin-web-release/index.html
```

iOS preset 目前設定為產生 Xcode project (`application/export_project_only=true`)，但 Apple 要求每個開發者帳號填入自己的 App Store Team ID。請在 Godot Editor 的 Export → iOS，或直接編輯 `export_presets.cfg` 的 `application/app_store_team_id` 後，再執行：

```sh
mkdir -p /private/tmp/goblin-ios-release
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "iOS Xcode" /private/tmp/goblin-ios-release/GoblinLeveling.xcodeproj
```

沒有 Team ID 時仍可完成 iOS 資源封裝與本機 headless 驗證；不要填入他人的或虛構 Team ID。

## 公開 Web 版（GitHub → Railway）

本 repo 的 `web/` 是由 Godot `Web QA` preset 產生的 release bundle。根目錄的 `Dockerfile` 會用 nginx 靜態服務它；`railway.toml` 已設定 Dockerfile builder、`/healthz` healthcheck 和失敗自動重啟。

本機重新產生 Web bundle：

```sh
rm -rf /private/tmp/goblin-web-release
mkdir -p /private/tmp/goblin-web-release
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "Web QA" /private/tmp/goblin-web-release/index.html
rm -rf web/index.html web/index.js web/index.wasm web/index.pck web/index.png web/index.audio.worklet.js web/index.audio.position.worklet.js
cp /private/tmp/goblin-web-release/index.* web/
```

Railway 建立 service 時選 GitHub repo `KennethEnglun/goblinmath`，root directory 保持 `/`；它會自動偵測根目錄 `Dockerfile`。不需要自行設定 `PORT`，Railway 會注入並由 nginx 使用。部署完成後，在 Railway 的 Networking → Public Networking 產生 public domain。

## 主要存檔

玩家進度寫入 `user://save.json`，並保留 `user://save.json.bak`。存檔包含關卡解鎖、完成關卡、星級、嘗試次數、EXP、金幣、屬性、裝備、掉落保底與統計資料。

目前存檔版本為 7，另包含 `gems` 鑽石、總能力點數、各能力加點紀錄與裝備累計強化花費欄位；舊版首次遷移時會補發一次 300 鑽石，舊裝備會按等級重建累計強化花費，損壞存檔會沿用 backup recovery 流程。

無限章節的星級／嘗試明細會保留 World 1 與最近進度，最多 128 筆，避免長期遊玩讓本機存檔無限膨脹；完成進度則由 sequential high-water mark 持續保留。
