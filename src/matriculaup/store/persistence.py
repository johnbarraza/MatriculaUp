import json
import os
from pathlib import Path
from typing import List

class PersistenceManager:
    """Manages saving and loading user's schedule to the local AppData/Home directory."""
    
    def __init__(self, override_path: str = None):
        if override_path:
            self.file_path = Path(override_path)
        else:
            # Use ~/.matriculaup/schedule.json as the default storage location
            # This maps to C:/Users/User/.matriculaup/ on Windows and ~/.matriculaup on Unix
            self.app_dir = Path.home() / ".matriculaup"
            self.app_dir.mkdir(parents=True, exist_ok=True)
            self.file_path = self.app_dir / "schedule.json"
            
    def save_schedule(self, section_codes: List[str]) -> bool:
        """Saves a list of selected section codes to disk."""
        try:
            with open(self.file_path, 'w', encoding='utf-8') as f:
                json.dump({"selected_sections": section_codes}, f, indent=2)
            return True
        except Exception as e:
            print(f"Error saving schedule: {e}")
            return False

    def load_schedule(self) -> List[str]:
        """Loads the list of selected section codes from disk. Returns empty list if not found."""
        if not self.file_path.exists():
            return []
            
        try:
            with open(self.file_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
                return data.get("selected_sections", [])
        except Exception as e:
            print(f"Error loading schedule: {e}")
            return []
