# ShareKit 部署紀錄

日期：2026-11-19

## 做了什麼

1. 確認這是同一個 Flutter 專案，已經同時包含 Android 工程（`android/`）和網站工程（`web/`）。沒有再拆成兩套程式。
2. 讓介面在手機和電腦都能用：
   - 螢幕寬度小於 840：底部導覽（探索、預約、上架），給 Android 手機和窄螢幕瀏覽器。
   - 螢幕寬度達到 840 或以上：左側導覽，內容置中，最寬 1200。電腦網站不會被拉成一條超寬的手機畫面。
   - 探索頁在寬螢幕改成卡片網格。
   - 網站可以用滑鼠拖曳捲動。
   - 網頁加上手機 viewport，PWA 不再鎖死直向，Android 瀏覽器可以「加到主畫面」，橫向平板和電腦也能開。
3. Android 應用名稱改為 ShareKit。
4. 加上 GitHub Actions（`.github/workflows/pages.yml`）。推送到 `main` 後會執行 `flutter build web --base-href "/ISEM_3027_Sharekit/"`，再發佈到 GitHub Pages。
5. 把專案推送到 `https://github.com/Horse630/ISEM_3027_Sharekit.git`。
6. 2026-11-19 加上登入頁和本機 SQLite：
   - 登入頁是公開頁：填名稱和密碼，按「登入」。沒有帳號可以按「還沒有帳號？註冊」，並填電郵或電話。
   - 註冊後要輸入驗證碼。這台裝置沒有真實短訊，頁面會顯示驗證碼。
   - 頁面上不再顯示示範帳號。資料庫仍會預先寫入已驗證的 `Isem_3027` / `Isem_3027`。
   - 資料庫檔案是 `sharekit.db`。Android 存在 App 私有目錄，網站存在瀏覽器裡。
   - 資料表 `users` 存帳號、聯絡方式、是否已驗證、顯示名稱、是否已加入社區和個人相片。密碼以 SHA-256 雜湊保存。
7. 2026-11-19 按借用流程補上功能，並規定上架只能拍照：
   - 點頂部帳號名稱可完善資料、用相機拍個人相片，以及加入九龍塘示範屋苑。
   - 付費預約要先支付按金，再確認付款。歸還或評價後可以確認退款。
   - 預約頁可以回報損壞、逾期歸還或其他問題。
   - 上架物品必須用相機拍攝當時狀況。沒有相簿上載按鈕。沒有照片不能發佈。
   - 上架還要填自己的地址，並選擇當面交接或郵寄。
   - 物品頁可以按「聯絡物主」，跟上架的人聊天。訊息存在本機 SQLite 的 `messages` 表。
   - 資料表 `sessions` 記住目前登入的人。登出後會刪掉這筆記錄，再回到登入頁。
   - 網站用 `sqflite_common_ffi_web`，需要 `web/sqlite3.wasm` 和 `web/sqflite_sw.js`。Android 用 sqflite 外掛。同一份登入程式兩邊都能跑。
8. 2026-11-19 把物品和預約寫進資料庫：
   - 名稱、物主、分類、狀況、地址、交接方式、租金、評價、相片和預約都寫進 `items`、`bookings`。同一個瀏覽器重新開啟仍然在。
   - 每個瀏覽器的 SQLite 存在自己的 IndexedDB，Firefox 讀不到 Edge 的檔案。GitHub Pages 也連不到 `127.0.0.1`。
   - 網站改為讀寫公開的 HTTPS 物品庫。不同瀏覽器、不同帳號看到同一份物品。本機 `python tool/catalog_server.py` 只給本機測試用。
9. 2026-11-24 改為使用 MongoDB Atlas：
   - 帳號、物品、預約、聊天都放在 Atlas 的 `sharekit` 資料庫。
   - 連線密碼只放在本機 `atlas-credentials.env`。這個檔案已列入 `.gitignore`，不會推上 GitHub。
   - 網站不能直接連 MongoDB。先在這台電腦執行 `python tool/mongo_server.py`，瀏覽器再連 `http://127.0.0.1:8780`。
   - 已移除 crudcrud 連線。測試仍可用本機 SQLite，避免測試改到 Atlas。
10. 2026-11-28 浸大試點、條款、按金與身份核對：
   - 去掉示範物品。社區定位改為香港浸會大學，探索頁顯示「你在香港浸會大學」。
   - 分類加上電子、書籍、運動、其他。
   - 介面主色改成簡報的深藍 `#003070`。設定頁有 `Location: HKBU` 標籤。
   - 設定頁寫有中英條款：身份核對、按金由平台暫存、租金不另收費、損壞與暫停帳號。
   - 上架可填按金。金額由物主自訂。預約後按金狀態為待付，付款後由平台暫存，歸還確認後才退回借用者。
   - 未上載香港身份證不能進入主畫面。伺服器只存「已上載」標記。證件相片留在這部裝置，不放進公開物品目錄，避免出現在所有人都能讀的使用者清單。
   - 應用圖示改用專案裡的 ShareKit 箱型圖。
   - 測試帳號寫在本機 `.sharekit.local`。該檔已列入 `.gitignore`，不會推上 GitHub。

## 網址

- 程式庫：https://github.com/Horse630/ISEM_3027_Sharekit
- 網站：https://horse630.github.io/ISEM_3027_Sharekit/

第一次發佈要等 GitHub Actions 跑完，通常幾分鐘。若頁面還是 404，到倉庫 Settings → Pages，Source 選 GitHub Actions。

## 手機和網站怎麼同時成立

| 用法 | 怎麼開 |
| --- | --- |
| 電腦或手機瀏覽器 | 打開上面的 GitHub Pages 網址 |
| Android 瀏覽器當 App | Chrome 選單裡「加到主畫面」或「安裝應用程式」 |
| 原生 Android App | 電腦接上手機或開模擬器後，在專案目錄執行 `flutter run` |
| 安裝包 | 在專案目錄執行 `flutter build apk`，安裝 `build/app/outputs/flutter-apk/app-release.apk` |

同一份 `lib/` 介面會編進網站和 Android，預約、取件、歸還、評價流程兩邊共用。

## 本機檢查

- `flutter test`：兩個 widget 測試已通過。
- `flutter build web --release --base-href "/ISEM_3027_Sharekit/"`：網站可以編出來，資源路徑對上 GitHub 專案頁。
- 本機打開編好的網站：寬螢幕是左側導覽，手機寬度是直向列表和底部導覽。
- Android 編譯：專案路徑含中文時，Gradle 預設會拒絕建置。已在 `android/gradle.properties` 加上 `android.overridePathCheck=true`。本機已打出 `build/app/outputs/flutter-apk/app-release.apk`（約 47.7MB）。安裝包沒有放進 Git。
