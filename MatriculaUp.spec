# -*- mode: python ; coding: utf-8 -*-


a = Analysis(
    ['C:\\Users\\johnb\\Documents\\GitHub\\MatriculaUp\\src\\matriculaup\\main.py'],
    pathex=['C:\\Users\\johnb\\Documents\\GitHub\\MatriculaUp\\src'],
    binaries=[],
    datas=[('C:\\Users\\johnb\\Documents\\GitHub\\MatriculaUp\\input\\courses_2026-1.json', 'input'), ('C:\\Users\\johnb\\Documents\\GitHub\\MatriculaUp\\input\\curricula_economia2017.json', 'input')],
    hiddenimports=[],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=['pdfplumber', 'pandas', 'jupyter', 'notebook'],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='MatriculaUp',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
coll = COLLECT(
    exe,
    a.binaries,
    a.datas,
    strip=False,
    upx=True,
    upx_exclude=[],
    name='MatriculaUp',
)
