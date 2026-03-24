# utils/paths.py
from pathlib import Path

def get_project_root():
    current = Path.cwd()
    
    while not (current / "data").exists():
        if current.parent == current:
            raise FileNotFoundError("Project root not found")
        current = current.parent
    
    return current

PROJECT_ROOT = get_project_root()
DATA_DIR = PROJECT_ROOT / "data"