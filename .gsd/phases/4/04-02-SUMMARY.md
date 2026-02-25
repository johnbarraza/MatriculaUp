## Wave 2 Summary

**Objective:** Package the PyInstaller output into a standalone Windows installer using Inno Setup.

**Changes:**
- Created `installer/MatriculaUp.iss` with Inno Setup configuration.
- Created `scripts/build_installer.ps1` to automate `iscc` compiler execution.
- User verified the generated `dist/MatriculaUp_v1_Setup.exe` installs correctly and the app runs without issues.

**Files Touched:**
- `installer/MatriculaUp.iss`
- `scripts/build_installer.ps1`

**Verification:**
- Installer created and manually verified by user. Start Menu shortcut works, app runs smoothly.

**Risks/Debt:**
- None.

**Next Wave TODO:**
- Complete Phase 4.
