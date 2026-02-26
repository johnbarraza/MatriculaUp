"""build_release.py — Genera builds Windows de MatriculaUp (installer + portable).

Uso:
    python scripts/build_release.py [--version 1.4]

Requisitos:
    - Flutter en PATH
    - Inno Setup 6 instalado en C:\\Program Files (x86)\\Inno Setup 6\\ISCC.exe
      (solo para el installer; el portable no lo requiere)
"""

from __future__ import annotations

import argparse
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT        = Path(__file__).resolve().parent.parent
APP_DIR     = ROOT / "matriculaup_app"
RELEASE_DIR = APP_DIR / "build" / "windows" / "x64" / "runner" / "Release"
DIST_DIR    = ROOT / "dist"
INPUT_DIR   = ROOT / "input"
ISS_FILE    = ROOT / "installer" / "MatriculaUp.iss"

ISCC_PATHS = [
    Path(r"C:\Program Files (x86)\Inno Setup 6\ISCC.exe"),
    Path(r"C:\Program Files\Inno Setup 6\ISCC.exe"),
]

JSON_FILES = [
    "courses_2026-1_v1.json",
    "efe_courses_2026-1_v1.json",
]


def flutter_build() -> None:
    print("\n[1/3] Flutter build windows --release ...")
    result = subprocess.run(
        ["flutter", "build", "windows", "--release"],
        cwd=str(APP_DIR),
        capture_output=False,
    )
    if result.returncode != 0:
        print("ERROR: Flutter build falló.")
        sys.exit(1)
    print("  Flutter build OK")


def make_portable(version: str) -> Path:
    print(f"\n[2/3] Creando portable ZIP v{version} ...")
    out = DIST_DIR / f"MatriculaUp_v{version}_Portable.zip"
    DIST_DIR.mkdir(exist_ok=True)

    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
        for f in RELEASE_DIR.rglob("*"):
            if f.is_file():
                zf.write(f, Path("MatriculaUp") / f.relative_to(RELEASE_DIR))
        for name in JSON_FILES:
            src = INPUT_DIR / name
            if src.exists():
                zf.write(src, Path("MatriculaUp") / name)

    size_mb = out.stat().st_size / 1024 / 1024
    print(f"  {out.name}  ({size_mb:.1f} MB)")
    return out


def make_installer(version: str) -> None:
    print(f"\n[3/3] Compilando installer Inno Setup v{version} ...")
    iscc = next((p for p in ISCC_PATHS if p.exists()), None)
    if iscc is None:
        print("  AVISO: Inno Setup no encontrado. Descárgalo de https://jrsoftware.org/isdl.php")
        print("  Luego ejecuta manualmente:")
        print(f'    "{ISCC_PATHS[0]}" "{ISS_FILE}"')
        return

    result = subprocess.run([str(iscc), str(ISS_FILE)], capture_output=False)
    if result.returncode != 0:
        print("  ERROR: Inno Setup falló.")
    else:
        installer = DIST_DIR / f"MatriculaUp_v{version}_Setup.exe"
        if installer.exists():
            size_mb = installer.stat().st_size / 1024 / 1024
            print(f"  {installer.name}  ({size_mb:.1f} MB)")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", default="1.4", help="Número de versión (default: 1.4)")
    parser.add_argument("--skip-flutter", action="store_true", help="Omite flutter build (usa binario existente)")
    args = parser.parse_args()

    print(f"=== MatriculaUp Build v{args.version} ===")
    if not args.skip_flutter:
        flutter_build()
    make_portable(args.version)
    make_installer(args.version)
    print("\n[OK] Builds en dist/")


if __name__ == "__main__":
    main()
