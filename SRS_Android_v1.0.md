# ConvertX Android — Software Requirements Specification
**Version:** 1.0  
**Date:** June 2026  
**Platform:** Android 8.0+ (API 26+)  
**Architecture:** Flutter 3 + Dart + ffmpeg_kit_flutter  
**Connectivity:** 100% Offline — no internet required

---

## 1. Introduction

### 1.1 Purpose
This SRS defines requirements for ConvertX Android — the native Android version of ConvertX. It is derived from the cross-platform ConvertX SRS v1.0 and constrains scope to Android-specific capabilities, constraints, and libraries.

### 1.2 Scope
ConvertX Android is a standalone APK/AAB distributed via the Google Play Store and direct sideload. It shares the same feature set and design language as the desktop version but uses Flutter + Dart as the only runtime (no Python engine, no Tauri). All conversion logic is implemented in pure Dart or via `ffmpeg_kit_flutter` for media.

### 1.3 Key Differences from Desktop Version

| Feature | Desktop | Android |
|---|---|---|
| Runtime | Python engine (Nuitka compiled) | Pure Dart + ffmpeg_kit_flutter |
| IPC | Newline-delimited JSON stdin/stdout | Dart Isolates |
| UI framework | React + TypeScript (Tauri webview) | Flutter + Material 3 |
| File access | Native OS paths | Android SAF (Uri-based) |
| Video→GIF | Supported (FFmpeg palette) | Not supported (APK size constraint) |
| SVG rasterisation | Supported (cairosvg) | Not supported |
| DOCX→PDF | Supported (python-docx + fpdf2) | Plain text → PDF only |
| Pipeline chaining | Supported (up to 6 steps) | Not supported (single-step only) |
| AI prompt layer | Optional (Ollama local) | Not supported |

---

## 2. Functional Requirements

### 2.1 Format Support Matrix (Android)

| Category | Input | Output | Library |
|---|---|---|---|
| Image | JPG, PNG, WebP, BMP, GIF, TIFF, HEIC | JPG, PNG, WebP, BMP, GIF, TIFF, PDF | `image` package + `pdf` package |
| Document | TXT, HTML, Markdown | PDF | `pdf` package |
| Spreadsheet | CSV | XLSX, JSON | `excel` package + `dart:convert` |
| Spreadsheet | XLSX | CSV, JSON | `excel` package |
| Data | JSON | CSV, YAML | `dart:convert` |
| Video | MP4, MKV, AVI, MOV, WebM | MP4, MKV, AVI, MOV, WebM, MP3, AAC, FLAC, WAV, OGG | `ffmpeg_kit_flutter_min` |
| Audio | MP3, AAC, FLAC, WAV, OGG | MP3, AAC, FLAC, WAV, OGG | `ffmpeg_kit_flutter_min` |

### 2.2 Input Validation (FR-001 to FR-005)
- **FR-AND-001**: Validate every input file by reading first 16 bytes (magic bytes) before conversion.
- **FR-AND-002**: Warn user if extension does not match detected MIME type. Allow proceeding.
- **FR-AND-003**: Reject zero-byte files with clear error message.
- **FR-AND-004**: Check available storage before conversion. Warn if < 90% free space would be consumed.
- **FR-AND-005**: Check available heap before processing files > 50 MB.

### 2.3 Conversion Processing (FR-006 to FR-013)
- **FR-AND-006**: Write all output to a uniquely named temp file first. Move to destination only after verifying size > 0.
- **FR-AND-007**: Support batch processing of multiple selected files with per-file progress.
- **FR-AND-008**: A failed file in a batch must not stop remaining files. Log error, skip, continue.
- **FR-AND-009**: All media conversion uses stream-based FFmpeg processing — files never fully loaded into RAM.
- **FR-AND-010**: Preserve EXIF metadata unless user explicitly opts to strip it.
- **FR-AND-011**: All conversion runs in a Dart `Isolate` — UI thread must never block (NFR-007).
- **FR-AND-012**: Purge all temp files on: job completion, job failure, app lifecycle `didChangeAppLifecycleState(detached)`.
- **FR-AND-013**: Output written to `/storage/emulated/0/Download/ConvertX/` or MediaStore (API 29+).

### 2.4 Conversion History (FR-016 to FR-018)
- **FR-AND-014**: Log every conversion to SQLite: input name, input format, output format, settings JSON, timestamp, output size, duration ms, success flag.
- **FR-AND-015**: Display last 200 entries. Auto-prune older entries.
- **FR-AND-016**: Each history entry shows: file name, format pair, relative timestamp, duration, success/fail badge.

### 2.5 Presets (FR-019 to FR-021)
- **FR-AND-017**: Ship 5 built-in presets seeded on first launch:
  1. Web image (WebP 80%)
  2. Email PDF (A4)
  3. WhatsApp photo (JPG 85%, resize to 1600px width)
  4. Audio MP3 128kbps
  5. Lossless PNG
- **FR-AND-018**: Users can create, rename, and delete custom presets.
- **FR-AND-019**: Presets stored in SQLite `presets` table (same schema as desktop).

### 2.6 Output Naming (FR-025 to FR-026)
- **FR-AND-020**: Never overwrite existing files. Append `_(1)`, `_(2)` etc. on collision.
- **FR-AND-021**: Output filename = `{original_name_without_ext}.{output_format}`.

---

## 3. Non-Functional Requirements

### 3.1 Performance
| ID | Metric | Target |
|---|---|---|
| NFR-AND-001 | Cold start to interactive UI | < 2.5 seconds (Snapdragon 695) |
| NFR-AND-002 | Image conversion (12 MP JPG → PNG) | < 800 ms |
| NFR-AND-003 | UI frame rate during conversion | 60 fps (conversion in Isolate) |
| NFR-AND-004 | CSV → XLSX (10,000 rows) | < 2 seconds |
| NFR-AND-005 | Audio extract from 60s video | < 5 seconds |

### 3.2 Size Constraints
| Component | Limit | Strategy |
|---|---|---|
| ARM64 APK (Play Store download) | ≤ 12 MB | ffmpeg_kit_min, R8 shrinking, per-ABI splits |
| Universal APK (direct sideload) | ≤ 20 MB | R8 + split APKs |
| App Bundle (.aab) | ≤ 30 MB | Google handles per-device slicing |

### 3.3 Permissions (NFR-017)
Only request permissions actually needed:
- `READ_EXTERNAL_STORAGE` (API ≤ 32)
- `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`, `READ_MEDIA_AUDIO` (API 33+)
- `WRITE_EXTERNAL_STORAGE` (API ≤ 28)

No camera, microphone, location, contacts, or network permissions.

### 3.4 Reliability
- **NFR-AND-001**: Every converter wrapped in try/catch returning a typed `JobResult`.
- **NFR-AND-002**: Failed conversion never leaves partial output at destination path.
- **NFR-AND-003**: Handle Android low-memory kills — purge temp dir on next launch.
- **NFR-AND-004**: App must not crash on any supported Android version (8.0–15.0).

### 3.5 Privacy & Security
- No network permissions declared — cannot make internet connections.
- SQLite stores only filenames and metadata — never file contents.
- No analytics, no crash reporting, no telemetry.

---

## 4. Architecture

### 4.1 Layer Overview

```
┌─────────────────────────────────────────────────┐
│  Flutter UI Layer (Material 3)                  │
│  Screens: Convert · History · Presets · Settings│
└─────────────────┬───────────────────────────────┘
                  │ Dart function calls
┌─────────────────▼───────────────────────────────┐
│  Core Layer                                     │
│  dispatcher.dart · validator.dart               │
│  temp_manager.dart · result.dart                │
└───────┬─────────────────┬───────────────────────┘
        │                 │
┌───────▼──────┐  ┌───────▼──────────────────────┐
│ Dart         │  │ ffmpeg_kit_flutter_min        │
│ Converters   │  │ MediaConverter (video/audio)  │
│ image_conv.  │  │ Runs FFmpeg in native process │
│ doc_conv.    │  └──────────────────────────────┘
│ data_conv.   │
└──────────────┘
        │
┌───────▼──────────────────────────────────────────┐
│  Storage Layer                                   │
│  sqflite — history table + presets table         │
│  path_provider — app dirs                        │
│  file_picker — SAF file access                   │
└──────────────────────────────────────────────────┘
```

### 4.2 SQLite Schema

```sql
CREATE TABLE history (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  created_at   TEXT NOT NULL,
  input_name   TEXT NOT NULL,
  input_format TEXT NOT NULL,
  output_format TEXT NOT NULL,
  settings_json TEXT NOT NULL,
  output_size  INTEGER,
  duration_ms  INTEGER,
  success      INTEGER NOT NULL DEFAULT 0,
  error_message TEXT
);

CREATE TABLE presets (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  name       TEXT NOT NULL UNIQUE,
  is_builtin INTEGER NOT NULL DEFAULT 0,
  config_json TEXT NOT NULL
);
```

### 4.3 Conversion Routing

```
Input MIME + Output Format
         │
         ▼
    Is MIME image/* AND output in {jpg,png,webp,bmp,gif,tiff,pdf}?
    → ImageConverter (Dart image package + pdf package)

    Is MIME text/* or application/json AND output in {pdf,html}?
    → DocConverter (pdf package)

    Is MIME text/csv or application/json or application/vnd.*spreadsheet AND output in {xlsx,csv,json}?
    → DataConverter (excel package + dart:convert)

    Is MIME video/* or audio/* AND output in {mp4,mkv,mp3,aac,flac,wav,ogg,...}?
    → MediaConverter (ffmpeg_kit_flutter_min)

    Otherwise → Error: no converter available
```

---

## 5. UI Specification

### 5.1 Navigation
Bottom NavigationBar (Material 3) with 4 tabs:
1. **Convert** — file picker, format selector, compression options, progress
2. **History** — list of last 200 conversions with success/fail badges
3. **Presets** — built-in and user presets; tap to apply
4. **Settings** — clear history, app info, privacy notice

### 5.2 Convert Screen States

| State | UI |
|---|---|
| Empty | Upload icon, "Select Files" FilledButton, format hint text |
| Files selected | File cards with name + extension badge; format dropdown; options chips; Convert button |
| Converting | Per-file LinearProgressIndicator; "Converting…" button state |
| Done | Success/error per file; "Open file" icon button on success |

### 5.3 Compression Options (shown as ActionChips)

| Format | Options Exposed |
|---|---|
| JPG/WebP | Quality slider (10–100%, default 85%) |
| PNG | Compression level (0–9, default 6) |
| MP4/MKV/WebM | Quality preset (High/Balanced/Small) |
| MP3/AAC/OGG | Audio bitrate (64k/128k/192k/320k) |
| Any image | Resize W×H + keep-aspect toggle |

### 5.4 Accessibility (UX-001 to UX-004)
- All interactive elements have `Semantics` labels.
- Error states use icon + color + text (never color alone).
- Minimum touch target: 48×48 dp (Material 3 standard).
- No forced light/dark — follows system theme.

---

## 6. Build & CI

### 6.1 Build Commands
```bash
# Install deps
flutter pub get

# Run tests
flutter test

# Build split APKs (arm64, armeabi-v7a, x86_64)
flutter build apk --release --split-per-abi

# Build App Bundle for Play Store
flutter build appbundle --release
```

### 6.2 GitHub Actions
CI runs on every push to `main`:
1. Setup Java 17 + Flutter stable
2. `flutter pub get`
3. `flutter test`
4. `flutter analyze --fatal-infos`
5. `flutter build apk --release --split-per-abi`
6. `flutter build appbundle --release`
7. Assert all APKs ≤ 20 MB
8. Upload APKs + AAB as artifacts

### 6.3 Size Budget

| ABI | Expected APK Size | Limit |
|---|---|---|
| arm64-v8a | ~14–18 MB (ffmpeg_kit dominates) | 20 MB |
| armeabi-v7a | ~13–17 MB | 20 MB |
| x86_64 | ~14–18 MB | 20 MB |

> Note: `ffmpeg_kit_flutter_min` (~10–12 MB native libs) is the dominant size factor.
> The `_min` variant excludes GPL codecs. If AAC/MP3 encoding is not needed,
> `ffmpeg_kit_flutter_audio` could reduce size further.

---

## 7. Testing Strategy

### 7.1 Unit Tests
Every converter class has unit tests covering:
- Valid input → expected output format
- Zero-byte input → typed error, no output file
- Corrupt input → typed error, no partial output
- Options: quality, resize, bitrate applied correctly

### 7.2 Integration Tests
Full flow: pick file → select format → convert → verify output exists and size > 0.

### 7.3 Size Regression
CI asserts all split APKs ≤ 20 MB on every build.

---

## 8. Revision History

| Version | Date | Description |
|---|---|---|
| 1.0 | June 2026 | Initial Android SRS derived from ConvertX SRS v1.0 |
