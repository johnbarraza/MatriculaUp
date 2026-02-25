# Plan 5.2 Summary: File Picker, Deserialization & State

- **Created Global State**: Designed `ScheduleState` in `lib/store/schedule_state.dart` with `ChangeNotifier` to hold the list of all courses and selected schedule elements.
- **Implemented File Picker & Load JSON**: Created `DataLoader.pickAndLoadCourses()` using `file_picker` and `dart:convert`.
- **Created Main Screen**: Implemented a responsive 30/70 split view in `lib/ui/pages/home_page.dart`. The left pane displays the loaded courses in a `ListView` or a 'Cargar Archivos JSON' button if empty. The right pane holds a placeholder for the timetable.
- **Wired Provider**: Injected `ScheduleState` into the widget tree in `lib/main.dart` at the top level.
- **Verification**: `flutter analyze` runs cleanly. The user can interact with the app via `flutter run -d windows`.
