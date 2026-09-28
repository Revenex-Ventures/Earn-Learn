# Install "Earn & Learn" on your phone — today

The app code is ready and statically verified. The **build and phone-install must run on your
Windows machine** (where Flutter lives) — I can't reach your phone or your Flutter toolchain from
my side. Below is the whole last mile. Pick Path A (easiest).

App runs **fully offline** with the real KBP seed roster (no Firebase / no internet needed).
Demo logins (shown on the login screen): student `EL2627-001`, supervisor `SV-01`,
admin `sdo@avcoe.edu.in` — shared password `avcoe@2627`.

---

## Path A — one click (recommended)

1. Plug your phone into the PC with a USB cable.
2. On the phone, enable **Developer options** → turn on **USB debugging**
   (Settings → About phone → tap "Build number" 7 times → back → System → Developer options →
   USB debugging). Tap **Allow** on the "Allow USB debugging?" popup that appears on the phone.
3. In the repo folder `C:\Users\Prashil Dalvi\Earn-Learn`, double-click **`build_and_install.bat`**.
   It fetches packages, runs analyze, builds the release APK, then installs and launches it on the phone.

---

## Path B — type the commands yourself

Open a terminal in `C:\Users\Prashil Dalvi\Earn-Learn` and run:

```bat
flutter pub get
flutter analyze
flutter build apk --release
flutter run --release
```

- `flutter run --release` needs the phone plugged in with USB debugging on (step 2 above).
- The standalone APK is written to:
  `build\app\outputs\flutter-apk\app-release.apk`

---

## Path C — no cable / install by file

1. Build it: `flutter build apk --release`
2. Copy `build\app\outputs\flutter-apk\app-release.apk` to the phone (USB file transfer,
   Google Drive, WhatsApp to yourself, etc.).
3. On the phone, open the file and tap **Install**. Allow "install from unknown sources" if asked.

---

## If something goes wrong

- **`flutter` not recognized** — open the terminal you normally use for Flutter, or add the Flutter
  `bin` folder to PATH.
- **Phone not in `flutter devices`** — reconnect the cable, re-confirm the USB-debugging popup on the
  phone, try a different cable/port, and make sure the phone is set to "File transfer / MTP" mode.
- **`flutter analyze` shows red errors** — copy the exact red text and send it to me; I'll fix it
  immediately. (Yellow "warning"/blue "info" lines don't block the build.)
- **Gradle / build failure** — try `flutter clean` then `flutter pub get` and build again; if it still
  fails, send me the red error block.

Send me any error output and I'll turn it around fast.
