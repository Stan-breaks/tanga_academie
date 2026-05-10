# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
flutter pub get          # install deps
flutter run              # run on device/emulator
flutter build apk        # Android APK
flutter build ipa        # iOS
flutter test             # run tests
flutter analyze          # static analysis
```

## Architecture

Multi-role e-learning platform (Student / Instructor / Admin) with real-time chat.

**Entry point:** `lib/main.dart` — initializes Hive, loads `.env`, checks auth token, routes to `HomePage` or login flow.

**Auth flow:** JWT stored in Hive via `lib/storage_service.dart`. Token checked on startup; if valid, user data loaded from `settingsBox` to determine role and render correct dashboard.

**API layer:** `lib/data_fetcher.dart` — single file for all REST calls. Uses `http` package with `Authorization: Bearer {token}` header. Base URL from `lib/api_config.dart` which reads `.env` `API_URL`.

**State management:** No Bloc/Riverpod/Provider. Screens use `StatefulWidget` + `FutureBuilder` / `setState`. Data is fetched on `initState` and stored in local variables.

**Services:** `lib/services/` — `ChatService` handles Socket.IO connection + HTTP chat endpoints. `BlogService`/`AdminBlogService` handle blog CRUD. All services exported via `services.dart` barrel.

**Routing:** Named routes defined in `MaterialApp` in `main.dart`. Most navigation uses `Navigator.push` directly rather than named routes.

**Localization:** `lib/core/language/language_provider.dart` — en/fr support. Language preference stored in Hive `settingsBox`. Translations in `lib/core/language/translations.dart`.

**Screen layout by role:**
- `lib/screens/student/` — student dashboards and course views
- `lib/screens/instructor/` — course creation, assignments, quizzes, progress tracking
- `lib/screens/admin/` — analytics, user management, blog management
- `lib/screens/shared/` — course details, explore, settings, chat, announcements (used across roles)

**Models:** `lib/models/` — `CourseData`, `ChatItem`, `Message`, `Blog`, `Contact`. Exported via `models.dart` barrel.

**Widgets:** `lib/widgets/` — reusable `BlogCard`, `ChatBubble`, `MessageInput`, `CourseCard`. Exported via `widgets.dart` barrel.

## Key dependencies

| Package | Purpose |
|---|---|
| `hive_flutter` | Local storage (auth token, settings, language) |
| `flutter_dotenv` | Load `.env` at runtime |
| `socket_io_client` | Real-time chat via WebSocket |
| `http` + `dio` | REST API calls |
| `video_player` + `chewie` | Video lesson playback |
| `vimeo_video_player` | Vimeo-hosted course videos |
| `webview_flutter` | Embedded web content |
| `fl_chart` | Admin analytics charts |
| `intl` | Date/number formatting |

## Environment

`.env` file required at project root:
```
API_URL=https://api.tangaacademie.com
```

Backend is a custom REST API — no Firebase. All endpoints under `/api/`.
