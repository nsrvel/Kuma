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

### Phase 2: Comprehensive Test Matrix (`docs/testing/`)
- Rancang Test Matrix komprehensif di `docs/testing/[0X-feature-name]-test-matrix.md` (minimal 25–40 Test Cases terstruktur):
  - Kategori A: Initial State & Baseline Contracts.
  - Kategori B: Input/Form Validation, Crypto/Vault & Security.
  - Kategori C: Concurrency, Debounce, Cancellation, & Database Mutations (GRDB).
  - Kategori D: Runtime/Process State Integration (ProcessRegistry/Subprocesses).
  - Kategori E: Edge Cases, Error Handling, & macOS System Quirks.
  - Kategori F: Headless SwiftUI View Hierarchy & Accessibility HIG.
- Minta konfirmasi/approval saya terhadap Spec & Test Matrix sebelum menulis kode.

### Phase 3: Test Implementation & Hardening
- Siapkan isolated Test Harness (mock in-memory DB, temp files, sandbox environment).
- Tulis test suite menggunakan modern Swift Testing framework (`@Suite`, `@Test`, `#expect`), gunakan `@Suite(..., .serialized)` untuk tes yang menyentuh shared storage/DB.
- Patuhi aturan arsitektur Kuma:
  - Swift 6 Strict Concurrency (`@MainActor`, `@Sendable`, zero data race).
  - View modular (< 150 baris per file).
  - Zero `print()` (wajib gunakan `os.Logger`).
  - Co-location repository protocol & implementation.

### Phase 4: Full Verification & 100% Pass
- Jalankan `xcodebuild -scheme Kuma -destination 'platform=macOS' test` sampai 100% SUCCEEDED (zero failure, zero flaky tests).
- Pastikan seluruh dokumentasi spec dan matriks tersinkronisasi sempurna dengan implementasi final.

Silakan mulai dengan mengaudit codebase dan tanyakan fitur apa yang akan kita kerjakan!
