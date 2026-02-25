import PyInstaller.__main__
from pathlib import Path
import os

def build_exe():
    project_root = Path(__file__).parent.parent.absolute()
    main_script = project_root / "src" / "matriculaup" / "main.py"
    
    # Path outputs for bundled files
    input_courses = project_root / "input" / "courses_2026-1.json"
    input_curriculum = project_root / "input" / "curricula_economia2017.json"

    # Convert paths to string for PyInstaller
    add_data_courses = f"{input_courses}{os.pathsep}input"
    add_data_curriculum = f"{input_curriculum}{os.pathsep}input"

    print("Building PyInstaller Executable...")
    PyInstaller.__main__.run([
        str(main_script),
        '--name=MatriculaUp',
        '--onedir',
        '--windowed',
        '--noconfirm',
        f'--add-data={add_data_courses}',
        f'--add-data={add_data_curriculum}',
        f'--paths={project_root / "src"}',
        '--exclude-module=pdfplumber',
        '--exclude-module=pandas',
        '--exclude-module=jupyter',
        '--exclude-module=notebook',
    ])
    print("Build complete. Output in dist/MatriculaUp")

if __name__ == "__main__":
    build_exe()
