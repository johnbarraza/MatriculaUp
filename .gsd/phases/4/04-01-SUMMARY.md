## Wave 1 Summary

**Objective:** Configure path resolution and create a build script to bundle the MatriculaUp application into a standalone Windows executable directory (`--onedir`).

**Changes:**
- Updated `src/matriculaup/main.py` to use `sys._MEIPASS` when `sys.frozen` is True for finding `input` directory.
- Created `scripts/build_exe.py` which runs `PyInstaller` with required data arguments and excludes heavy packages like pandas/pdfplumber.
- Successfully ran build script generating `dist/MatriculaUp` directory.

**Files Touched:**
- `src/matriculaup/main.py`
- `scripts/build_exe.py`

**Verification:**
- Executable built into `dist/MatriculaUp/MatriculaUp.exe` successfully.
- Command: `python scripts/build_exe.py` passed with exit code 0.

**Risks/Debt:**
- None.

**Next Wave TODO:**
- Implement Windows Installer using Inno Setup (Phase 4.2).
