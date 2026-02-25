import json
from dataclasses import dataclass
from typing import List, Dict, Any, Union

@dataclass
class CurriculumCourse:
    codigo: str
    nombre: str
    creditos: str
    tipo: str
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "CurriculumCourse":
        return cls(
            codigo=data["codigo"],
            nombre=data["nombre"],
            creditos=data["creditos"],
            tipo=data["tipo"]
        )

@dataclass
class CurriculumCycle:
    ciclo: Union[int, str]
    cursos: List[CurriculumCourse]
    nombre: str = "" # Some categories like "electivos" have names
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "CurriculumCycle":
        # Basic parsing
        c = cls(
            ciclo=data["ciclo"],
            cursos=[CurriculumCourse.from_dict(c) for c in data.get("cursos", [])],
            nombre=data.get("nombre", f"Ciclo {data['ciclo']}")
        )
        return c

@dataclass
class Curriculum:
    metadata: Dict[str, str]
    ciclos: List[CurriculumCycle]
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "Curriculum":
        return cls(
            metadata=data.get("metadata", {}),
            ciclos=[CurriculumCycle.from_dict(c) for c in data.get("ciclos", [])]
        )

def load_curriculum_from_json(path: str) -> Curriculum:
    with open(path, 'r', encoding='utf-8') as f:
        data = json.load(f)
        
    return Curriculum.from_dict(data)
