# Pengawas Asesmen Online – SMAN 85 Jakarta

Aplikasi untuk kepengawasan ujian yang membuka halaman pengawas **tanpa memperlihatkan alamatnya** kepada pengawas. Tujuannya: alamat/link ujian tidak bocor ke siswa, sehingga siswa tidak bisa membuat konfigurasi SEB sendiri.

Satu basis kode (Flutter) untuk **Android, iOS, Windows, dan macOS**. Pengawas **boleh** membuka aplikasi lain.

## Cara aplikasi menyembunyikan link
- Tidak ada address bar dan judul halaman web tidak ditampilkan.
- Alamat tidak tertulis polos di kode; disimpan teredam (XOR + base64) di `lib/main.dart`.
- Tidak bisa menyalin teks/tautan, menekan lama tautan, atau berbagi alamat; menu konteks dan pratinjau tautan dimatikan.
- Navigasi hanya ke host yang diizinkan; tautan lain diblokir tanpa menyebut alamat.
- Pesan kesalahan jaringan dibuat umum (tidak memuat alamat).
- Android: screenshot, perekaman layar, dan pratinjau di daftar aplikasi terbaru diblokir (`FLAG_SECURE`).
- iOS/Android: layar ditutup saat aplikasi tidak aktif (pratinjau app switcher).

## Batas teknis (penting dibaca)
Penyembunyian di sisi aplikasi **menyulitkan, tetapi tidak mutlak**. Aplikasi harus mengetahui alamat agar bisa membukanya, sehingga pengawas yang ahli teknis masih bisa mengintip lewat:
- bongkar paket aplikasi (decompile) untuk mengurai konstanta teredam,
- memantau lalu lintas jaringan (proxy/VPN pemantau), atau
- memotret layar dengan kamera lain bila halaman itu sendiri menampilkan alamat.

Karena itu, **perkuat juga di sisi server** (paling efektif):
1. Batasi akses halaman ujian ke **IP/jaringan sekolah** atau butuh login/token berumur pendek.
2. Aktifkan **Browser Exam Key / Config Key SEB** di server, jadi konfigurasi buatan siswa ditolak walau link diketahui.
3. Ganti link/token ujian secara berkala atau per sesi.
4. Pastikan halaman `cbtadmin` tidak menampilkan atau menautkan alamat ujian pada isi halamannya.
5. Bila perlu, ambil alamat dari server sekolah saat aplikasi dibuka (kode akses pengawas), jangan ditanam di aplikasi. Saya bisa menambahkannya.

## Mengganti alamat
```bash
python3 tool/generate_secret.py https://contoh.my.id/cbtadmin contoh.my.id
```
Salin keluarannya (`_k`, `_eUrl`, `_eHost`) ke `lib/main.dart`.

## Build otomatis dengan GitHub Actions (tanpa memasang Flutter)
File `.github/workflows/build.yml` membuild **APK Android, Windows, dan macOS** di cloud GitHub.

1. Buat akun di github.com, lalu buat repositori baru. **Pilih Private**, karena berisi alamat yang disembunyikan (meski teredam).
2. Unggah seluruh isi folder `pengawas_asesmen85` (termasuk folder tersembunyi `.github`) ke cabang `main`. Cara mudah: **Add file → Upload files** di halaman repositori, atau pakai GitHub Desktop.
3. Buka tab **Actions**. Build jalan otomatis setelah unggah; bisa juga dijalankan manual lewat **Build Aplikasi Pengawas → Run workflow**.
4. Tunggu sekitar 10–20 menit sampai tanda centang hijau, lalu buka run tersebut dan unduh hasilnya di bagian **Artifacts**:
   - `pengawas-android-apk`: file `app-release.apk` untuk HP pengawas.
   - `pengawas-windows`: folder aplikasi Windows (jalankan `pengawas_asesmen85.exe`).
   - `pengawas-macos`: `.zip` berisi aplikasi macOS (di Mac lain: klik kanan → Open).
5. Bila build gagal, buka langkah yang bertanda merah dan kirim pesan kesalahannya ke saya.

Catatan: iOS tidak dibuild otomatis karena butuh akun Apple Developer dan penandatanganan. APK yang dihasilkan memakai kunci debug, cukup untuk dibagikan langsung ke perangkat sekolah, tetapi tidak untuk Play Store.

## 1. Siapkan proyek (cara manual)
Pasang [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.22+), lalu:

```bash
flutter create --org id.sch.sman85jkt --project-name pengawas_asesmen85 --platforms=android,ios,windows,macos .
flutter pub get
```
`flutter create .` hanya menambah folder platform; `lib/main.dart` dan `pubspec.yaml` tidak ditimpa.

## 2. Konfigurasi per platform

### Android
1. Ganti `MainActivity.kt` di `android/app/src/main/kotlin/...` dengan `platform_setup/android/MainActivity.kt` (samakan baris `package` dengan `applicationId` di `android/app/build.gradle`).
2. Pastikan `AndroidManifest.xml` memuat `<uses-permission android:name="android.permission.INTERNET"/>`.
3. Build dengan **obfuscation** agar kode lebih sulit dibaca:
   ```bash
   flutter build apk --release --obfuscate --split-debug-info=build/debug-info
   ```

### iOS
1. Buka `ios/Runner.xcworkspace`, atur Team & Bundle ID, deployment target minimal iOS 13.
2. Build: `flutter build ipa --release --obfuscate --split-debug-info=build/debug-info` (butuh Mac + Apple Developer Account).
3. iOS tidak mengizinkan pemblokiran screenshot oleh aplikasi biasa; hanya pratinjau app switcher yang ditutup.

### Windows
1. Perlu Visual Studio 2022 (*Desktop development with C++*) dan **WebView2 Runtime**.
2. `flutter build windows --release --obfuscate --split-debug-info=build/debug-info`
3. Hasil di `build/windows/x64/runner/Release/` (salin seluruh folder).
4. Screenshot di Windows tidak diblokir oleh aplikasi ini.

### macOS
1. Tambahkan di `macos/Runner/DebugProfile.entitlements` dan `Release.entitlements`:
   ```xml
   <key>com.apple.security.network.client</key>
   <true/>
   ```
2. Di `macos/Podfile`: `platform :osx, '10.15'`.
3. `flutter build macos --release --obfuscate --split-debug-info=build/debug-info`
4. Untuk distribusi di luar App Store, lakukan code signing dan notarization.

## Uji coba
```bash
flutter run -d windows   # atau macos / android / ios
```
