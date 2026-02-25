from abc import ABC, abstractmethod
from pathlib import Path
import json
import logging

logger = logging.getLogger(__name__)


class BaseExtractor(ABC):
    def __init__(self, pdf_path: str, output_dir: str = "input"):
        self.pdf_path = Path(pdf_path)
        self.output_dir = Path(output_dir)
        self.warnings = []
        self.error_count = 0
        self.total_rows = 0

    @abstractmethod
    def extract(self) -> dict:
        pass

    @abstractmethod
    def output_filename(self) -> str:
        pass

    def save(self, data: dict) -> Path:
        self.output_dir.mkdir(exist_ok=True)
        out = self.output_dir / self.output_filename()
        with open(out, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        return out

    def error_rate(self) -> float:
        if self.total_rows == 0:
            return 0.0
        return self.error_count / self.total_rows
