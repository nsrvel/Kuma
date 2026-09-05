Sebelum mulai, tolong lakukan ini terlebih dahulu:
1. Audit kondisi arsitektur codebase Kuma saat ini (Domain, Core, Stores, dan Presentation).
2. Berikan daftar opsi fitur logis berikutnya yang paling prioritas berdasarkan roadmap Kuma, lalu tanyakan kepada saya fitur mana yang ingin dieksekusi sekarang.

Setelah saya memilih fiturnya, jalankan pipeline standar end-to-end tanpa jalan pintas:

### Phase 1: Audit & Feature Spec (`docs/specs/`)
- Buat file spesifikasi formal di `docs/specs/[0X-feature-name].md` mencakup:
  - High-Level Flow (Mermaid diagram).
  - Machine Deterministic State & Transition Matrix.
  - Invariant Rules (Kontrak baku / Non-negotiables).
  - Invariant Guardrails mapping ke target test suite.

### Phase 2: Comprehensive Test Matrix (`docs/testing/`) & Implementation Plan
- Rancang Test Matrix komprehensif di `docs/testing/[0X-feature-name]-test-matrix.md` (minimal 25–40 Test Cases terstruktur):
  - Kategori A: Initial State & Baseline Contracts.
  - Kategori B: Input/Form Validation, Crypto/Vault & Security.
  - Kategori C: Concurrency, Debounce, Cancellation, & Database Mutations (GRDB).
  - Kategori D: Runtime/Process State Integration (ProcessRegistry/Subprocesses).
  - Kategori E: Edge Cases, Error Handling, & macOS System Quirks.
  - Kategori F: Headless SwiftUI View Hierarchy & Accessibility HIG.
- **Wajib Buat `implementation_plan.md`**: Buat artifact Implementation Plan detail yang merinci file apa saja yang diubah/dibuat, arsitektur yang dipakai, dan strategi verifikasi.
- Minta konfirmasi/approval saya terhadap Spec, Test Matrix, dan Implementation Plan sebelum menulis kode implementasi/tes.

### Phase 3: Code Refactoring, Bug Fixing, Hardening & Test Implementation
- **Audit & Bersihkan Hal yang "Bobrok" (Zero Tech-Debt)**:
  - Wajib periksa dan langsung perbaiki semua kode usang / anti-pattern di fitur terkait.
  - Modernisasi URL path: ganti semua `.path` lama menjadi `.path(percentEncoded: false)` (macOS 14+).
  - Pastikan 100% kepatuhan **Swift 6 Strict Concurrency**: `@Sendable`, actor isolation (`@MainActor` vs `actor`), zero data-race, zero uncoordinated background Tasks pada synchronous lifecycle (misal: `applicationWillTerminate`).
  - Hapus semua `print()`, wajib gunakan `os.Logger`.
  - Pastikan modularitas View (< 150 baris per file) dan co-location repository protocol.
- **Test Implementation**:
  - Siapkan isolated Test Harness (mock in-memory DB, temp files, sandbox environment).
  - Tulis test suite komprehensif menggunakan modern Swift Testing framework (`@Suite`, `@Test`, `#expect`).
  - Wajib gunakan `@Suite(..., .serialized)` untuk tes yang menyentuh shared storage / defaults / DB untuk mencegah flakiness.

### Phase 4: Full Verification & 100% Pass
- Jalankan `xcodebuild -scheme Kuma -destination 'platform=macOS' test` sampai 100% SUCCEEDED (zero failure, zero flaky tests).
- Buat/update artifact `walkthrough.md` berisi rangkuman perubahan dan hasil testing.
- Pastikan seluruh dokumentasi spec dan matriks tersinkronisasi sempurna dengan implementasi final.

Silakan mulai dengan mengaudit codebase dan tanyakan fitur apa yang akan kita kerjakan!
