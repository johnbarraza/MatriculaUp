import json
from dataclasses import dataclass
from typing import List, Optional, Dict, Any
from enum import Enum

class SessionType(Enum):
    CLASE = "CLASE"
    PRACTICA = "PRÁCTICA"
    LABORATORIO = "LABORATORIO"
    FINAL = "FINAL"
    PARCIAL = "PARCIAL"
    CANCELADA = "CANCELADA"
    PRACDIRIGIDA = "PRACDIRIGIDA"
    PRACCALIFICADA = "PRACCALIFICADA"
    EXSUSTITUTORIO = "EXSUSTITUTORIO"
    EXREZAGADO = "EXREZAGADO"

    @classmethod
    def from_string(cls, name: str) -> "SessionType":
        try:
            return cls(name.upper())
        except ValueError:
            # Fallback for unexpected values
            print(f"Warning: Unknown session type '{name}'")
            return cls.CLASE

@dataclass
class Session:
    tipo: SessionType
    dia: str
    hora_inicio: str
    hora_fin: str
    aula: str
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "Session":
        return cls(
            tipo=SessionType.from_string(data["tipo"]),
            dia=data["dia"],
            hora_inicio=data["hora_inicio"],
            hora_fin=data["hora_fin"],
            aula=data["aula"]
        )

@dataclass
class Section:
    seccion: str
    docentes: List[str]
    observaciones: str
    sesiones: List[Session]

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "Section":
        return cls(
            seccion=data["seccion"],
            docentes=data.get("docentes", []),
            observaciones=data.get("observaciones", ""),
            sesiones=[Session.from_dict(s) for s in data.get("sesiones", [])]
        )

@dataclass
class Course:
    codigo: str
    nombre: str
    creditos: str
    prerequisitos: Optional[Dict[str, Any]]
    secciones: List[Section]
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "Course":
        return cls(
            codigo=data["codigo"],
            nombre=data["nombre"],
            creditos=data["creditos"],
            prerequisitos=data.get("prerequisitos"),
            secciones=[Section.from_dict(s) for s in data.get("secciones", [])]
        )

def load_from_json(path: str) -> List[Course]:
    with open(path, 'r', encoding='utf-8') as f:
        data = json.load(f)
        
    return [Course.from_dict(c) for c in data.get("cursos", [])]
