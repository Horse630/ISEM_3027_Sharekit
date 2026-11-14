# ShareKit 部署紀錄

日期：2026-11-14

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
