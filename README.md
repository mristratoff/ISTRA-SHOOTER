# ISTRA SHOOTER — Build kit (Windows / Android)
Creator: Oleg Istratov

**Status:** Source and CI export configuration, NOT compiled or runtime-tested. No EXE/APK is included.

## Automated builds (GitHub)
1. Create a new GitHub repository and upload the **contents** of this folder (including hidden `.github`).
2. Open Actions -> Build ISTRA SHOOTER -> Run workflow.
3. If the build succeeds, download the `ISTRA-SHOOTER-builds` artifact.

The workflow uses a third-party Godot CI container. It may need fixes for export template versions or Android SDK/signing configuration; review its logs. The Android preset requests a **debug-signed APK**, not a Play Store release package. Windows export produces a portable EXE (not an installer wizard).

## Local import
Open `project.godot` in Godot 4.4.1, then press F5. Godot 4 export templates are required to export builds. Android export also requires Android SDK/JDK and a signing keystore.

## Known limits
- Prototype 2D procedural art (not production 2.5D assets).
- No monetization or purchase integration.
- No runtime test or verified installer in this environment.
