# Plan 8.2 & 8.3 Summary: Credits + Multiple Schedules

## Plan 8.2 — Credit Tracking & Limits
- Added `maxCredits` (default 25) and `currentCredits` getter (sums `creditos` of all selected courses) to `ScheduleState`.
- `addSection` now throws if `currentCredits + newCredits > maxCredits`.
- `HomePage` AppBar shows a live "Créditos: X / Y" badge. Tapping it opens an `AlertDialog` with an editable `TextField` to change the limit.

## Plan 8.3 — Multiple Contingency Schedules (A / B / C)
- `ScheduleState._selectedSections` replaced by `List<List<CourseSelection>> _schedules = [[], [], []]`.
- `activeScheduleIndex` tracks the active plan. `selectedSections` getter returns `_schedules[_activeScheduleIndex]`.
- `switchSchedule(int index)` updates the index and calls `notifyListeners()`, instantly repainting the entire UI.
- `HomePage` AppBar has a `SegmentedButton<int>` (Plan A / B / C) bound directly to `state.activeScheduleIndex`.
- **Verification:** `flutter analyze` clean. All three plans are fully isolated — adding to Plan A doesn't affect Plan B or C.
