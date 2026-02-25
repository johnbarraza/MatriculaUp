## Phase 8 Verification

### Must-Haves
- [x] Searching by a professor's name brings up their courses. — VERIFIED (`filteredCourses` now checks `s.docentes.any(...)`)
- [x] Conflicting sections have a disabled (greyed-out) Add button. — VERIFIED (`onPressed: (isSelected || hasConflict) ? null : ...`)
- [x] "Ocultar Cruces" toggle hides courses/sections that fully conflict. — VERIFIED (`SwitchListTile` + `visibleSections` filter)
- [x] Credit counter shows in the AppBar and blocks additions over the limit. — VERIFIED (`currentCredits` getter + exception in `addSection`)
- [x] Credit limit is editable. — VERIFIED (`AlertDialog` on AppBar badge tap)
- [x] Plan A / B / C are independently managed. — VERIFIED (`_schedules[3]` architecture in `ScheduleState`)

### Verdict: PASS
All requirements for Phase 8 (Advanced Filters & Constraints) are met.
