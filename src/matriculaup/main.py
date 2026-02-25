import sys
from pathlib import Path

# Add project root to sys.path to allow running directly from src folder
project_root = str(Path(__file__).parent.parent.parent.absolute())
if project_root not in sys.path:
    sys.path.insert(0, project_root)

from PySide6.QtWidgets import QApplication
from src.matriculaup.models.course import load_from_json
from src.matriculaup.store.persistence import PersistenceManager
from src.matriculaup.ui.app_window import AppWindow

def main():
    app = QApplication(sys.path)
    
    # 1. Load Data
    json_path = Path(project_root) / "input" / "courses_2026-1.json"
    print(f"Loading data from {json_path}")
    
    try:
        courses = load_from_json(str(json_path))
        print(f"Loaded {len(courses)} courses.")
    except Exception as e:
        print(f"Error loading courses JSON: {e}")
        courses = []
        
    # 2. Setup Persistence
    pm = PersistenceManager()
    saved_schedule = pm.load_schedule()
    print(f"Loaded saved schedule with {len(saved_schedule)} items.")
    
    # 3. Start UI
    window = AppWindow(courses=courses, schedule_data=saved_schedule)
    window.show()
    
    sys.exit(app.exec())

if __name__ == "__main__":
    main()
