from typing import List, Tuple
from datetime import datetime

from src.matriculaup.models.course import Session, Section, Course

class ConflictDetector:
    def __init__(self):
        pass

    @staticmethod
    def _parse_time(time_str: str) -> int:
        """Parse HH:MM into total minutes since midnight for easy comparison."""
        t = datetime.strptime(time_str, "%H:%M")
        return t.hour * 60 + t.minute

    @classmethod
    def sessions_overlap(cls, s1: Session, s2: Session) -> bool:
        """Returns True if Session 1 and Session 2 overlap in time on the same day."""
        if s1.dia != s2.dia:
            return False
            
        start1 = cls._parse_time(s1.hora_inicio)
        end1 = cls._parse_time(s1.hora_fin)
        start2 = cls._parse_time(s2.hora_inicio)
        end2 = cls._parse_time(s2.hora_fin)
        
        # Overlap condition:
        # One session starts strictly before the other ends, AND
        # The other session starts strictly before the first ends.
        return max(start1, start2) < min(end1, end2)

    @classmethod
    def find_conflicts(cls, selected_pairs: List[Tuple[Course, Section]]) -> List[Tuple[Course, Course]]:
        """
        Given a list of (Course, Section) tuples, find all conflicting course pairs.
        Returns a list of (Course1, Course2) that have at least one overlapping session.
        """
        conflicts = []
        n = len(selected_pairs)
        
        for i in range(n):
            course1, section1 = selected_pairs[i]
            for j in range(i + 1, n):
                course2, section2 = selected_pairs[j]
                
                # Check for overlaps between any session of s1 and any session of s2
                overlap_found = False
                for sess1 in section1.sesiones:
                    for sess2 in section2.sesiones:
                        if cls.sessions_overlap(sess1, sess2):
                            conflicts.append((course1, course2))
                            overlap_found = True
                            break
                    if overlap_found:
                        break
                        
        return conflicts
