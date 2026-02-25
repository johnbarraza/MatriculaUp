import sys
from pathlib import Path

# Add project root to sys.path to allow running directly from src folder
project_root = str(Path(__file__).parent.parent.parent.absolute())
if project_root not in sys.path:
    sys.path.insert(0, project_root)
    
if getattr(sys, 'frozen', False):
    # If the application is run as a bundle, the PyInstaller bootloader
    # extends the sys module by a flag frozen=True and sets the app 
    # path into variable _MEIPASS'.
    base_path = Path(sys._MEIPASS)
else:
    base_path = Path(project_root)

from PySide6.QtWidgets import QApplication
from matriculaup.models.course import load_from_json
from matriculaup.store.persistence import PersistenceManager
from matriculaup.ui.app_window import AppWindow
from matriculaup.models.curriculum import load_curriculum_from_json

def main():
    app = QApplication(sys.path)
    
    # 1. Load Data
    json_path = base_path / "input" / "courses_2026-1.json"
    print(f"Loading data from {json_path}")
    
    try:
        courses = load_from_json(str(json_path))
        print(f"Loaded {len(courses)} courses.")
    except Exception as e:
        print(f"Error loading courses JSON: {e}")
        courses = []
        
    curriculum_path = base_path / "input" / "curricula_economia2017.json"
    print(f"Loading curriculum from {curriculum_path}")
    curriculum = None
    try:
        curriculum = load_curriculum_from_json(str(curriculum_path))
        print(f"Loaded Curriculum: {curriculum.metadata.get('carrera')}")
    except Exception as e:
        print(f"Error loading curriculum JSON: {e}")
        
    # 2. Setup Persistence
    pm = PersistenceManager()
    saved_schedule = pm.load_schedule()
    print(f"Loaded saved schedule with {len(saved_schedule)} items.")
    
    # 3. Start UI
    window = AppWindow(courses=courses, schedule_data=saved_schedule, curriculum=curriculum)
    window.show()
    
    sys.exit(app.exec())

if __name__ == "__main__":
    main()
