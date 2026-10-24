# GenZoo Student Portal (Flutter & Firebase)

A comprehensive, production-ready Android student portal application designed with Flutter and Firebase (Cloud Firestore, Firebase Storage, and Firebase Authentication).

---

## 🌟 Key Features

1. **Role-Based Authentication**:
   - Secure sign-in and registration via **Firebase Authentication**.
   - Dual-role system (**Admin** vs **Student**) + **Guest Mode** for immediate frictionless browsing.
   - Live role badges in the top AppBar (`ADMIN`, `STUDENT`, `GUEST`).

2. **Announcements / College News**:
   - Real-time Firestore stream of college updates.
   - Pinned high-priority announcements and category filtering (`Urgent`, `Academic`, `Exams`, `Activities`).
   - Admin controls to publish and remove announcements.

3. **Study Materials Hub**:
   - Organized by **Academic Year** (Freshman to Senior) and **Semester**.
   - Search across subjects, topics, and descriptions.
   - Support for PDF, Word, PowerPoint, and ZIP files.
   - Download counter and direct file launch via `url_launcher`.
   - **Admin Upload Screen**: Powered by `file_picker` with real-time Firebase Storage upload progress.

4. **Azkar, Tasbeeh & Quran**:
   - Azkar organized in tabs: study duas, morning, evening, after prayer, sleep & waking, general duas (59 items with counters).
   - **Electronic tasbeeh**: choose a dhikr and a target (33 / 99 / 100 / 1000 / open), haptic feedback, rounds and lifetime totals saved on the device.
   - **Quran**: surah index with search, Uthmani text loaded from the public alquran.cloud API, adjustable font size, "continue reading", and a one-tap download for offline reading.

5. **Essential Info & Flexible GPA Calculator**:
   - **Official Platforms**: Quick links to university SIS, Moodle/LMS, timetables, and library.
   - **Pluggable GPA Engine**: Built using the **Strategy Pattern** (`Standard4ScaleStrategy`, `Standard5ScaleStrategy`, `CustomUniversityScaleStrategy`).
   - Supports **Semester GPA**, **Cumulative CGPA** (with prior history), quality points, and honors standing badges.

6. **Admin Management Dashboard**:
   - Protected route accessible only to authenticated admins.
   - Metrics overview (announcements, files, links).
   - Fast shortcuts to publish news, upload materials, and update official links.

---

## 📁 Project Architecture & Folder Organization

```text
lib/
├── core/
│   ├── constants/
│   │   ├── app_colors.dart         # Color palette (Light & Dark theme)
│   │   ├── app_constants.dart      # Collections, academic years, semesters
│   │   └── app_theme.dart          # Material 3 typography & card styling
│   ├── services/
│   │   ├── auth_service.dart       # Firebase Authentication & user profiles
│   │   ├── firestore_service.dart  # Firestore streams for news, materials, links
│   │   ├── storage_service.dart    # Firebase Storage upload/delete with file_picker
│   │   └── url_service.dart        # Safe link launcher
│   └── utils/
│       └── gpa_calculator_engine.dart # Strategy pattern for GPA & CGPA calculation
├── models/
│   ├── user_model.dart             # AppUser model with role parsing
│   ├── news_model.dart             # NewsItem model
│   ├── material_model.dart         # StudyMaterial model with file metadata
│   ├── azkar_model.dart            # AzkarItem model + authentic study duas
│   ├── quick_link_model.dart       # QuickLink model with default university portals
│   └── gpa_model.dart              # CourseEntry & GpaCalculationResult
├── providers/
│   ├── auth_provider.dart          # UserAuthProvider (sign in, sign up, guest)
│   ├── news_provider.dart          # NewsProvider (stream, filter, add, delete)
│   ├── materials_provider.dart     # MaterialsProvider (filtering, progress tracking)
│   └── gpa_provider.dart           # GpaProvider (dynamic course list, scale switcher)
├── screens/
│   ├── splash_screen.dart          # Animated startup screen
│   ├── auth/
│   │   └── login_screen.dart       # Modern Sign In / Register / Guest screen
│   ├── main_navigation_screen.dart # Core bottom NavigationBar shell
│   ├── home/
│   │   ├── home_screen.dart        # Announcements feed & filters
│   │   └── add_edit_news_dialog.dart # Admin dialog to post announcements
│   ├── materials/
│   │   ├── materials_screen.dart   # Searchable material catalog
│   │   └── upload_material_screen.dart # File picker & Storage upload screen
│   ├── azkar/
│   │   └── azkar_screen.dart       # Calm Azkar & Study Duas view
│   ├── essential_info/
│   │   ├── essential_info_screen.dart # University portals & GPA hub
│   │   └── gpa_calculator_screen.dart # Interactive GPA / CGPA calculator
│   └── admin/
│       └── admin_dashboard_screen.dart # Role-secured administrative console
├── widgets/
│   └── custom_widgets.dart         # RoleBadge, EmptyStateView, chips
└── main.dart                       # App entrypoint & MultiProvider setup
```

---

## ⚙️ Android Configuration (`AndroidManifest.xml`)

Ensure your `android/app/src/main/AndroidManifest.xml` includes these permissions and intent queries for `url_launcher` and file operations:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>

    <queries>
        <!-- For url_launcher to open web links in external browser -->
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="https" />
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="http" />
        </intent>
    </queries>
</manifest>
```

---

## 🔒 Security Rules (Included in Root)

- `firestore.rules`: Configured with role-based document access (`isAdmin()` check).
- `storage.rules`: Grants read access to students, restricts uploads to admins, and enforces a 50MB file size ceiling.

---

## 🚀 Build & Run (الخطوات)

1. Install Flutter (stable) + Android Studio. In the project folder run: `flutter pub get`
2. Firebase project **genzoo-app** (package `com.gamal.genzoo`) — in the console enable:
   - Authentication → Email/Password
   - Firestore Database (no Storage needed - files are added as Google Drive links, 100% free)
3. Publish the security rules: paste `firestore.rules` into the Firebase console (Firestore -> Rules).
4. Build: `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk`
   (or push to GitHub: the workflow in `.github/workflows/build-apk.yml` builds the APK for you).
5. **Making an admin:** register normally in the app, then in Firestore open `users/<uid>` and change `role` from `student` to `admin`.
   (Self-registration as admin was removed — the rules block it.)

## 🔔 الإشعارات (مجانية وتلقائية)
التطبيق يشترك تلقائيًا في topic باسم `news`. عند نشر خبر من التطبيق يُحفظ بـ `notified: false`، ثم يرسله الـ workflow `genzoo-notifications.yml` (الملف `scripts/send_notifications.py`) بأولوية عالية ويحوّل العلامة إلى `true`.

**لضمان وصول الإشعار خلال دقيقة** (جدولة GitHub قد تتأخر ساعات): أنشئ مهمة في https://cron-job.org (مجانية) كل دقيقة:
- URL: `https://api.github.com/repos/gamalzakareya6-star/GenZoo-app/actions/workflows/genzoo-notifications.yml/dispatches`
- Method: `POST`، Body: `{"ref":"main"}`
- Headers: `Authorization: Bearer <TOKEN>` و `Accept: application/vnd.github+json`
- الـ TOKEN: Fine-grained token لهذا المستودع فقط بصلاحية **Actions: Read and write**.

الأخبار المنشورة قبل هذا التحديث (بدون حقل `notified`) لا يُرسل لها إشعار.
