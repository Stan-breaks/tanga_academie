# Known Gaps & Pending Work

Last updated: 2026-07-05

---

## Fixed (this session)

| # | File | What was broken | Fix |
|---|------|----------------|-----|
| 1 | `lib/screens/shared/profile_page.dart` | Guest users had no way to change app language | Added EN/FR language chips to not-logged-in state |
| 2 | `lib/screens/shared/course_details_page.dart:969` | Lesson tap in curriculum tab did nothing (`// TODO: Navigate to lesson`) | Wired to `LessonVideoPlayerPage` with next/prev; non-enrolled users get "enroll first" snackbar |
| 3 | `lib/screens/student/course_learn_page.dart` | Quiz pass didn't visually unlock next chapter — `onComplete` only refreshed video progress, not course structure | Added `_onLessonComplete` that re-fetches full course after lesson/quiz completion |
| 4 | `lib/screens/shared/course_details_page.dart` | After external payment browser closed, app still showed "Buy Now" — no access re-check on return | Added `WidgetsBindingObserver` with `_pendingPayment` flag; re-calls `_checkCourseAccess` on app resume |

---

## Pending

### High priority

**Reviews tab — read-only**
- File: `lib/screens/shared/course_details_page.dart` → `_buildReviewsTab`
- Shows rating summary and total review count, but students cannot submit a review.
- Backend endpoint needed: `POST /api/courses/:id/reviews`

**Login / Signup — no language picker**
- Files: `lib/screens/login_page.dart`, `lib/screens/signup_page.dart`
- Language can only be changed from the Profile tab (guest) or Settings (logged-in). First-time users on the login/signup screens cannot switch language before creating an account.
- Fix: add compact EN/FR toggle (same pattern as guest profile picker) to login and signup screens.

### Medium priority

**No push notifications**
- No FCM (Android) or APNS (iOS) integration anywhere in the codebase.
- Chat messages and announcements only surface when the app is open.
- Requires: FCM setup in `AndroidManifest.xml` + `AppDelegate.swift`, `firebase_messaging` package, backend webhook to send notifications on new messages/announcements.

**Post-payment: no in-app confirmation screen**
- File: `lib/screens/shared/course_details_page.dart` → `_launchPaymentGateway`
- Payment opens external browser (MaxiCash). On return, access is re-checked silently.
- No success/failure feedback screen shown to user after returning from payment gateway.
- Fix: show a dialog on resume explaining result ("Checking payment status...") while `_checkCourseAccess` runs.

**`pubspec.yaml` version bump uncommitted**
- `pubspec.yaml` has an unsaved version change sitting in the working tree since the last `feat: version update` commit.
- Run `git add pubspec.yaml && git commit`.

### Low priority

**Instructor — no Explore/course-browse tab**
- Instructors go directly to their dashboard; they cannot browse the course catalog.
- Student `ExplorePage` is shared — could be added as a 4th nav tab in `InstructorHomePage`.

**No pagination on Explore page**
- File: `lib/screens/shared/explore_page.dart`
- All courses and blogs are fetched in a single request. No "load more" or infinite scroll.
- Will degrade when course/blog count grows.

**Assignment submission — no file type validation**
- File: `lib/screens/student/assignment_submission_page.dart`
- File picker has no filter on accepted types or size limit before upload attempt.

---

## Architecture notes

- No state management library (Bloc/Riverpod/Provider). All screens use `StatefulWidget` + `FutureBuilder` / `setState`. Fine for current scale; becomes painful if screens need to share live state (e.g. chat badge count, enrollment status updates).
- `data_fetcher.dart` is a single flat file for all REST calls. Should be split by domain as it grows.
- Language is a global mutable variable (`currentLanguage` in `language_provider.dart`), not a `ChangeNotifier`. UI only updates on explicit `setState` — widgets that don't rebuild won't reflect a language change until navigated away and back.
