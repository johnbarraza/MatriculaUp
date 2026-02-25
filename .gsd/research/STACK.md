# Stack Research: Python Desktop App Distribution

**Domain:** Python desktop application (schedule planner) → standalone Windows executable for non-technical users

**Researched:** 2026-02-24

**Confidence:** HIGH

**Recommendation:** Use **PySide6 + PyInstaller + pyside6-deploy** for UI + core extraction logic. Tauri with Python sidecar is the alternative if bundle size becomes critical constraint.

---

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| **PySide6** | 6.7+ | Desktop UI framework wrapping Qt6 | LGPL licensed (free for commercial use), maintains your existing Python ecosystem, pyside6-deploy tool optimizes bundle size automatically, official Qt documentation excellent |
| **PyInstaller** | 6.x | Bundle Python + dependencies into exe | Industry standard, works seamlessly with PySide6 out-of-the-box, handles pdfplumber and pandas automatically, no Rust/build tool learning curve |
| **pyside6-deploy** | Built-in | Optimize and deploy executables | Automatically excludes unused Qt modules (QtWebEngine, QtQuick, etc.), reduces bundle from ~400MB to ~80-150MB typical |
| **Python** | 3.11+ | Runtime and extraction logic | Reuse existing pdfplumber extraction code directly, no API changes needed for PySide6 UI layer |

### Supporting Libraries (Extraction Layer - Reuse Existing)

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| **pdfplumber** | 0.10+ | PDF table/text extraction | Extract course data from academic offering PDFs (already working in project) |
| **pandas** | 2.0+ | Tabular data processing | Clean, normalize extracted schedules and prerequisites (already in requirements) |
| **PyInstaller** | 6.x | Hidden imports | Use `hiddenimports=['pandas._libs']` in PyInstaller spec to catch pandas dynamic imports |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| **PyInstaller** (`pyinstaller --windowed --onedir app.py`) | Create executable | Use `--onedir` mode (not `--onefile`) for faster startup; `--onefile` requires unpacking temp files each run (2-10s overhead) |
| **pyside6-deploy** (run after PyInstaller) | Size optimization | Automatically excludes 6 size-heavy Qt modules if not detected in QML files; manual config via `pysidedeploy.spec` |
| **UPX** (optional) | Binary compression | Further 20-30% size reduction when available, though not guaranteed to work on all systems |
| **Inno Setup** or **NSIS** (v2) | Windows installer | Package PyInstaller output into professional `.exe` installer with uninstall support |

### Architecture Pattern: Backend Extraction + Frontend UI

```
┌─────────────────────────────────────────┐
│      User Desktop (Windows)             │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  PySide6 (Qt6) - UI Layer       │   │
│  │  ├─ Course search/filter        │   │
│  │  ├─ Schedule builder            │   │
│  │  ├─ Conflict detection display  │   │
│  │  └─ Plan browser                │   │
│  └────────────┬────────────────────┘   │
│               │ import                  │
│  ┌────────────▼────────────────────┐   │
│  │ Python Backend (same process)   │   │
│  │ ├─ pdfplumber → PDF extraction  │   │
│  │ ├─ pandas → data normalization  │   │
│  │ ├─ JSON serialization           │   │
│  │ └─ Schedule conflict logic      │   │
│  └─────────────────────────────────┘   │
│                                         │
│  All bundled into single .exe           │
│  (no separate Python install needed)    │
└─────────────────────────────────────────┘
```

---

## Installation

### Development Setup

```bash
# Core packages
pip install PySide6==6.7.0
pip install PyInstaller==6.19.0
pip install pdfplumber==0.10.x
pip install pandas==2.2.x
pip install PyYAML  # for pyside6-deploy config

# Dev dependencies (Windows builds only)
pip install -D pyside6-deploy
```

### Packaging for Distribution

```bash
# Step 1: Create initial executable with PyInstaller
pyinstaller \
  --name MatriculaUp \
  --onedir \
  --windowed \
  --add-data "data:data" \
  --hidden-modules=pandas._libs \
  --icon=icon.ico \
  --collect-all=pdfplumber \
  src/app.py

# Step 2: Deploy and optimize with pyside6-deploy
pyside6-deploy -c pysidedeploy.spec dist/MatriculaUp

# Step 3: (Optional) Compress with Inno Setup
# Install Inno Setup, load dist/MatriculaUp folder
# Output: MatriculaUp-Setup-2026-1.exe (~40-80MB)
```

### pyside6-deploy.spec (Configuration)

```yaml
# Save as pysidedeploy.spec in project root
title=MatriculaUp
binary_name=MatriculaUp
project_dir=./
python_dir=/path/to/venv

# Exclude unused Qt modules
excluded_qml_plugins=QtQuick QtQuick3D QtCharts QtWebEngine QtTest QtSensors

# Bundle pre-extracted JSON data
extra_args=--add-data "data:data"
```

---

## Bundle Size Estimates

| Option | Raw Output | Installer | Notes |
|--------|------------|-----------|-------|
| **PySide6 + PyInstaller + pyside6-deploy** | 80-150 MB | 40-80 MB | **RECOMMENDED**: Qt module exclusion reduces bloat significantly |
| **PyQt6 + PyInstaller** | 150-200 MB | 70-100 MB | Larger Qt footprint; requires commercial license for proprietary distribution |
| **Tauri + Python sidecar** | 5-30 MB exe + 50-100 MB Python | 60-80 MB | Requires WebView2 runtime (180 MB if embedded); more deployment complexity |
| **Electron + Python backend** | 180-250 MB | 100-150 MB | Chromium bloat; overkill for schedule planner; slower startup |
| **CustomTkinter + PyInstaller** | 100-150 MB | 50-80 MB | Slightly larger than PySide6; fewer customization options for professional look |

---

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative | Why Not for MatriculaUp |
|-------------|-------------|-------------------------|-------------------------|
| **PySide6 + PyInstaller** | PyQt6 + PyInstaller | Commercial GUI with GPL acceptance | Licensing friction: requires paid commercial license ($200-500) for non-open-source distribution; LGPL (PySide6) has no such requirement |
| **PySide6 + PyInstaller** | Tauri + Python sidecar | If bundle size < 30 MB is critical | Added complexity: requires Node.js build chain, WebView2 distribution hassle (180 MB embedded), communication overhead via HTTP; not worth it for ~70 MB difference |
| **PySide6 + PyInstaller** | CustomTkinter + PyInstaller | Lightweight, modern Look | Severely limited for your use case: No native table widgets for course listings, poor data visualization, fewer layout options; PySide6 models/views designed for schedule data |
| **PySide6 + PyInstaller** | Electron + FastAPI | Cross-platform polish | Massive overkill: ~200+ MB bundles, Chromium startup overhead, JavaScript fatigue for Python team, no benefit for Windows-first desktop utility |
| **PyInstaller** | PyOxidizer (Rust-based) | Single-file executables with zero unpacking | Learning curve steep (Rust); binary dependencies (pdfplumber, pandas) require compilation from source; not worth effort for 60-100 MB application |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| **PyQt6 unlicensed** | GPL license requires all source code disclosure or $200-500 commercial license purchase | PySide6 (LGPL allows proprietary use without purchase) |
| **PyInstaller --onefile** | Unpacks entire bundle to temp folder on every launch (~2-10 second delay); slower; defeats startup speed gains | Use `--onedir` (dist/ folder with .exe + libs); negligible size difference |
| **Electron** | Chromium bundle (~180 MB) unnecessary for non-web app; massive memory footprint (200-300 MB idle vs. 30-40 MB PySide6) | PySide6 native widgets match Windows UX better |
| **CustomTkinter** | Tkinter lacks native data-bound widgets; building course list and schedule conflict display is tedious; styling limited | PySide6's QTableWidget, QListWidget, QStandardItemModel built for tabular UX |
| **Tauri without backend** | Attempting to run Python extraction logic in browser context (no native Python) | Tauri with Python sidecar (adds complexity) |
| **Nuitka compilation** | Compiles Python to C++; only marginal speed gains (~5-10%) for your app; requires MSVC toolchain; breaks pdfplumber binary dependencies | PyInstaller unchanged |

---

## Licensing Summary

| Framework | License | Commercial Use | Caveat |
|-----------|---------|-----------------|---------|
| **PySide6** | LGPL v3 | Free (no payment required) | You can distribute proprietary app without licensing cost; LGPL only requires disclosure of PySide6 source (not your code) |
| **PyQt6** | GPL v3 | Requires license ($200-500) | Unless app is open-source; commercial license mandatory for closed-source distribution |
| **PyInstaller** | GPLv2 (but bootloader PyInstaller works with any app) | Free | Can bundle proprietary Python apps |
| **CustomTkinter** | MIT | Free | Most permissive; can distribute freely |

**Decision:** PySide6 is free for commercial distribution unlike PyQt6; LGPL is much friendlier than GPL for proprietary tools.

---

## Version Compatibility

| Package | Version | Notes |
|---------|---------|-------|
| PySide6 | 6.7.0+ | Stable; Qt 6.7 LTS, no breaking changes from 6.6 |
| PyInstaller | 6.x | Latest is 6.19.0; ensure `--collect-all` works for pdfplumber binary hooks |
| pdfplumber | 0.10.x+ | Works with PyInstaller; hooks included in PyInstaller >= 6.0 |
| pandas | 2.2.x+ | PyInstaller requires `hiddenimports=['pandas._libs']` in .spec |
| Python | 3.11, 3.12 | Target Python 3.11 for widest Windows compatibility (3.12 is newer but may break older OS); build on same Python version you'll bundle |

---

## Pre-Build Checklist for Packaging

- [ ] All relative paths in code use `pathlib.Path(__file__).parent / "data"` (not working directory relative)
- [ ] Pre-extracted JSON files bundled in `data/` folder (not re-extracted at startup)
- [ ] Config uses `getattr(sys, 'frozen', False)` to detect running as exe vs. script
- [ ] PyInstaller spec includes `hiddenimports=['pandas._libs', 'pdfplumber']`
- [ ] Windows icon file (.ico) included via `--icon=icon.ico`
- [ ] Tested executable on clean Windows VM (no Python/dependencies installed)
- [ ] UAC elevation disabled (users shouldn't need admin rights)

---

## Key Wins for This Stack

1. **Reuse existing Python code:** pdfplumber extraction logic unchanged; no C++ bindings, no new language
2. **No licensing friction:** LGPL (PySide6) vs. GPL (PyQt6) removes commercial license cost
3. **Reasonable bundle size:** 80-150 MB raw (40-80 MB installer) is acceptable for desktop utility
4. **Single file distribution:** One .exe installer; users double-click → installs → runs
5. **Professional UI:** Qt models/views designed for tables, trees, grids (your schedule/course needs)
6. **Industry standard:** PyInstaller + PySide6 is battle-tested in thousands of production apps
7. **Low learning curve:** No Rust, no Node build chain, no Electron JavaScript; stay in Python

---

## Why NOT the Alternatives

- **Tauri:** Extra complexity for marginal bundle size gain (30-40 MB difference doesn't matter for desktop utility); WebView2 distribution headaches; requires JavaScript frontend (not a win)
- **Electron:** Overkill; Chromium bundle makes no sense for schedule planner; ~2x slower startup
- **CustomTkinter:** No native data-bound widgets; UI will feel bolted-on vs. native
- **PyOxidizer:** Rust learning curve; binary dependency compilation complexity not worth 50 MB savings for 200+ MB app

---

## Sources

- [PySide6 · PyPI](https://pypi.org/project/PySide6/)
- [pyside6-deploy: the deployment tool for Qt for Python - Qt for Python](https://doc.qt.io/qtforpython-6/deployment/deployment-pyside6-deploy.html)
- [PyQt6 vs PySide6: What's the difference between the two Python Qt libraries?](https://www.pythonguis.com/faq/pyqt6-vs-pyside6/)
- [PyInstaller · PyPI](https://pypi.org/project/pyinstaller/)
- [Packaging PySide6 applications for Windows with PyInstaller & InstallForge](https://www.pythonguis.com/tutorials/packaging-pyside6-applications-windows-pyinstaller-installforge/)
- [Embedding External Binaries | Tauri](https://v2.tauri.app/develop/sidecar/)
- [GitHub - dieharders/example-tauri-v2-python-server-sidecar](https://github.com/dieharders/example-tauri-v2-python-server-sidecar)
- [Tauri vs. Electron: performance, bundle size, and the real trade-offs](https://www.gethopp.app/blog/tauri-vs-electron)
- [Tauri download | SourceForge.net](https://sourceforge.net/projects/tauri.mirror/)
- [App Size | Tauri](https://v2.tauri.app/concept/size/)
- [Riverbank Computing | PyQt Commercial Version](https://riverbankcomputing.com/commercial/pyqt)
- [Commercial Use - Qt for Python](https://doc.qt.io/qtforpython-6/commercial/index.html)
- [PyQt vs PySide: What are the licensing differences between the two Python Qt libraries?](https://www.pythonguis.com/faq/pyqt-vs-pyside/)
- [Qt for Python & PyInstaller - Qt for Python](https://doc.qt.io/qtforpython-6/deployment/deployment-pyinstaller.html)
- [Comparing Python Executable Packaging Tools: PEX, PyOxidizer, and PyInstaller](https://oriolrius.cat/2024/10/25/comparing-python-executable-packaging-tools-pex-pyoxidizer-and-pyinstaller/)
- [Packaging PyQt6 applications for Windows, with PyInstaller & InstallForge](https://www.pythonguis.com/tutorials/packaging-pyqt6-applications-windows-pyinstaller/)
- [PyInstaller Documentation Release 6.19.0](https://pyinstaller.org/en/latest/pdf/)
- [How to write and package desktop apps with Tauri + Vue + Python | by Senhaji Rhazi hamza | Medium](https://hamza-senhajirhazi.medium.com/how-to-write-and-package-desktop-apps-with-tauri-vue-python-ecc08e1e9f2a)

---

**Stack research for:** MatriculaUp desktop schedule planner (Windows-first distribution)

**Researched:** 2026-02-24
