---
phase: 3
plan: 2
completed_at: 2026-02-25
duration_minutes: 15
---

# Summary: Export to PNG

## Results
- 2 tasks completed
- All verifications passed

## Tasks Completed
| Task | Description | Status |
|------|-------------|--------|
| 1 | Export Button UI — QPushButton "📷 Exportar Horario a PNG" in top bar of ScheduleTab | ✅ |
| 2 | QPixmap Rendering Logic — `export_to_png(filepath)` using `self.grab()`, connected to QFileDialog | ✅ |

## Deviations Applied
None — executed as planned.

## Files Changed
- `src/matriculaup/ui/tabs/schedule_tab.py` — Added export button to top bar, `_on_export()` handler with QFileDialog, success/error QMessageBox
- `src/matriculaup/ui/components/timetable_grid.py` — Added `export_to_png(filepath: str) -> bool` method using `self.grab()` + `pixmap.save()`

## Verification
- Export button renders correctly in Tab 2 (Schedule): ✅
- QFileDialog opens on click: ✅
- `self.grab()` captures timetable without UI buttons overlapping: ✅
- Saved PNG is a valid binary PNG file: ✅
