# Test Matrix: Feature 01 — Onboarding Wizard & System Dependency Check

> **Related Spec:** [`docs/specs/01-onboarding.md`](file:///Users/putra/Development/Personal/Projects/Kuma/Repositories/Kuma/docs/specs/01-onboarding.md)  
> **Test Target Files:**  
> - `KumaTests/Features/Onboarding/OnboardingInitialStateTests.swift` (Kategori A: State Awal & Launch)  
> - `KumaTests/Features/Onboarding/OnboardingBinaryValidationTests.swift` (Kategori B: Validasi Binary & Custom Path)  
> - `KumaTests/Features/Onboarding/OnboardingConcurrencyAndMappingTests.swift` (Kategori C & D: Concurrency & Mapping)  
> - `KumaTests/Features/Onboarding/OnboardingFlowTests.swift` (Kategori E, F, G: Lifecycle, macOS Quirks & Settings)  
> - `KumaTests/Features/Onboarding/OnboardingVisualTests.swift` (Kategori H: Visual SwiftUI Hierarchy & Stepper)  
> - `KumaTests/Harness/OnboardingTestHarness.swift` (Shared Sandbox & Mock File Generator)

---

## Master Test Case Matrix (40 Scenarios)

### Kategori A: Initial State & Launch Variations
| ID | Nama Test Case | Deskripsi Skenario & Kondisi Batas | Expected Result | Status |
| :--- | :--- | :--- | :--- | :--- |
| **TC-A01** | `testInitialStateCleanInstall` | App launch pertama kali (`hasCompletedOnboarding == false`) | Phase `.onboarding`, `currentStep == 0`, `isScanning == false` | ✅ Passed (0.001s) |
| **TC-A02** | `testLaunchReturningUser` | App launch user lama (`hasCompletedOnboarding == true`) | Phase `.mainWorkspace`, Onboarding wizard ditekan/suppressed | ✅ Passed (0.001s) |
| **TC-A03** | `testCorruptedDefaultsFallback` | Key onboarding diisi data corrupt/non-boolean di storage | Fallback aman ke `.onboarding` tanpa fatal error/crash | ✅ Passed (0.001s) |
| **TC-A04** | `testSlowPreScanNavigation` | User buru-buru klik Continue ke Step 1 sebelum scan Step 0 selesai | Tidak freeze/crash, state dependency terisi saat scan resolve | ✅ Passed (0.247s) |

---

### Kategori B: Binary Validation & Custom Path Inputs
| ID | Nama Test Case | Deskripsi Skenario & Kondisi Batas | Expected Result | Status |
| :--- | :--- | :--- | :--- | :--- |
| **TC-B01** | `testFileNotFoundRejection` | User browse ke file yang tidak ada (`/bin/non_existent_cli`) | Return `false`, error message muncul, storage tidak berubah | ✅ Passed (0.003s) |
| **TC-B02** | `testDirectorySelectionRejection` | User memilih direktori folder (misal `/usr/local/bin`) bukan file | Ditolak (`notExecutable`), error "File is not an executable" | ✅ Passed (0.003s) |
| **TC-B03** | `testNonExecutableFileRejection` | User memilih file teks biasa (`chmod -x`) atau file kosong | Ditolak (`notExecutable`), error alert menyala di ViewModel | ✅ Passed (0.005s) |
| **TC-B04** | `testBinaryNameMismatchRejection` | User memilih binary `docker` pada field `kubectl` | Ditolak (`nameMismatch`), error message menyebutkan nama mismatch | ✅ Passed (0.005s) |
| **TC-B05** | `testTildePathExpansion` | User menginput path tilde (`~/bin/mytool`) | Tilde ter-expand ke home user asli dan diverifikasi | ✅ Passed (0.005s) |
| **TC-B06** | `testWhitespaceTrimmedPath` | Input path dengan spasi liar `"   /bin/zsh   "` | Spasi di-trim otomatis, validasi sukses, tersimpan bersih | ✅ Passed (0.003s) |
| **TC-B07** | `testClearingCustomPath` | User mengosongkan path (`""`) untuk reset default | Path direset, settings diset empty, auto re-scan ke PATH | ✅ Passed (0.005s) |
| **TC-B08** | `testKubeconfigYamlValidation` | User memilih file config `.yaml` untuk kubeconfig | Divalidasi sebagai file dokumen teks/YAML (bukan executable) | ✅ Passed (0.005s) |

---

### Kategori C: Concurrency, Debounce & Race Conditions
| ID | Nama Test Case | Deskripsi Skenario & Kondisi Batas | Expected Result | Status |
| :--- | :--- | :--- | :--- | :--- |
| **TC-C01** | `testRapidConsecutiveScans` | Tombol Re-scan diklik berulang kali secara paralel | Task lama dibatalkan (`isCancelled`), hanya hasil akhir tersimpan | ✅ Passed (0.039s) |
| **TC-C02** | `testPathOverrideDuringScan` | User override custom path saat background scan sedang berjalan | In-flight scan dibatalkan, scan baru jalan dengan path terbaru | ✅ Passed (0.092s) |
| **TC-C03** | `testRapidStepForwardSpam` | User spam klik tombol "Continue" puluhan kali | `currentStep` mentok di `3 (Ready)`, tidak pernah overflow | ✅ Passed (0.007s) |
| **TC-C04** | `testRapidStepBackwardSpam` | User spam klik tombol "Back" puluhan kali | `currentStep` mentok di `0 (Welcome)`, tidak pernah underflow | ✅ Passed (0.007s) |

---

### Kategori D: Dependency Status Mapping & Visual Segregation
| ID | Nama Test Case | Deskripsi Skenario & Kondisi Batas | Expected Result | Status |
| :--- | :--- | :--- | :--- | :--- |
| **TC-D01** | `testZeroDependenciesProgression` | Semua CLI tidak terinstall / Not Found di sistem | User tetap diizinkan klik Continue sampai selesai (Non-blocking) | ✅ Passed (0.007s) |
| **TC-D02** | `testPartialInstalledMapping` | Hanya sebagian CLI terinstall (misal Docker ada, Podman tidak) | Docker bertanda `isInstalled = true`, Podman `false` | ✅ Passed (0.038s) |
| **TC-D03** | `testEngineVsTunnelSegregation` | Pemisahan kategori dependency | `engineDependencies` tepat 4 item, `tunnelingDependencies` 2 item | ✅ Passed (0.038s) |
| **TC-D04** | `testIdempotentPreScan` | `scanDependenciesIfNeeded()` dipanggil berkali-kali tanpa force | Scan hanya dieksekusi 1 kali | ✅ Passed (0.038s) |

---

### Kategori E: Lifecycle Completion & Window Coordination
| ID | Nama Test Case | Deskripsi Skenario & Kondisi Batas | Expected Result | Status |
| :--- | :--- | :--- | :--- | :--- |
| **TC-E01** | `testCompleteOnboardingLifecycle` | User menyelesaikan Step 0 $\to$ Step 3 lalu klik "Get Started" | Flag tersimpan di UserDefaults, coordinator masuk `.mainWorkspace` | ✅ Passed (0.010s) |
| **TC-E02** | `testBackAndForthStateRetention` | User bolak-balik antar step (0 $\to$ 2 $\to$ 1 $\to$ 3) | Data scan dan path override tidak ter-reset/hilang di memory | ✅ Passed (0.010s) |
| **TC-E03** | `testResetToOnboarding` | Menjalankan `AppCoordinator.resetToOnboarding()` | Status kembali ke `.onboarding`, flag direset ke `false` | ✅ Passed (0.009s) |

---

### Kategori F: macOS System, Sandbox & Path Quirks
| ID | Nama Test Case | Deskripsi Skenario & Kondisi Batas | Expected Result | Status |
| :--- | :--- | :--- | :--- | :--- |
| **TC-F01** | `testHomebrewPathResolution` | Cek path standar macOS (`/opt/homebrew/bin` & `/usr/local/bin`) | Resolver memeriksa kedua lokasi fallback Homebrew | ✅ Passed (0.003s) |
| **TC-F02** | `testSymlinkResolution` | Validasi binary yang merupakan symlink valid | Mengikuti symlink dan me-resolve path asli file executable | ✅ Passed (0.009s) |
| **TC-F03** | `testBrokenSymlinkRejection` | Binary berupa symlink rusak (target file sudah terhapus) | Ditolak sebagai `fileNotFound`, tidak melempar uncaught error | ✅ Passed (0.009s) |
| **TC-F04** | `testKubeconfigEnvVarPrecedence` | Terdapat environment variable `$KUBECONFIG` aktif | Mendahulukan path dari `$KUBECONFIG` sebelum `~/.kube/config` | ✅ Passed (0.009s) |
| **TC-F05** | `testFallbackDirectoryCoverage` | PATH kosong saat launch GUI non-interactive | Tetap dapat mendeteksi binary di fallback directories standar | ✅ Passed (0.009s) |

---

### Kategori G: UI State & Settings Migration Integrity
| ID | Nama Test Case | Deskripsi Skenario & Kondisi Batas | Expected Result | Status |
| :--- | :--- | :--- | :--- | :--- |
| **TC-G01** | `testAlertDismissalClearsState` | User menutup popover/alert error validasi binary | `pathValidationError` kembali bernilai `nil` | ✅ Passed (0.009s) |
| **TC-G02** | `testPathWithSpecialCharacters` | Path file mengandung spasi atau karakter UTF-8 | Validasi string tidak rusak akibat percent-encoding | ✅ Passed (0.009s) |
| **TC-G03** | `testLegacyKeyMigrationFallback` | Value tersimpan di key lama `kuma.custom_kubectl_path` | `KumaSettingsKey.string()` berhasil membaca value lama | ✅ Passed (0.009s) |
| **TC-G04** | `testCanGoNextAndPrevProperties` | Pengecekan flag navigasi tombol di tiap step | `canGoNext` true di step 0-2, false di step 3; `canGoPrev` sebaliknya | ✅ Passed (0.009s) |
| **TC-G05** | `testTotalStepsConstant` | Pengecekan jumlah total step wizard | Nilai konstan tepat `4` | ✅ Passed (0.010s) |

---

### Kategori H: Visual SwiftUI View & Layout Inspection (Headless UI Hierarchy)
| ID | Nama Test Case | Deskripsi Skenario & Kondisi Batas | Expected Result | Status |
| :--- | :--- | :--- | :--- | :--- |
| **TC-H01** | `testWelcomeStepVisualHierarchy` | Render `WelcomeStepView` | Menampilkan Hero text judul, deskripsi subjudul, dan 3 feature tags (`Multi-Provider`, `Public Tunnels`, `Local-First`) | ✅ Passed (0.010s) |
| **TC-H02** | `testContainersStepVisualRowElements` | Render `ContainersAndClustersStepView` dengan mock data | Menampilkan judul step, tepat 4 `DependencyStatusRowView` cards, dan tombol Re-scan | ✅ Passed (0.009s) |
| **TC-H03** | `testPublicTunnelingStepVisualRowElements` | Render `PublicTunnelingStepView` dengan mock data | Menampilkan judul step, tepat 2 `DependencyStatusRowView` cards, dan tombol Re-scan | ✅ Passed (0.009s) |
| **TC-H04** | `testReadyStepVisualConfirmation` | Render `ReadyStepView` | Menampilkan icon checkmark hijau (`checkmark.circle.fill`), judul "You're all set.", dan subjudul konfirmasi | ✅ Passed (0.010s) |
| **TC-H05** | `testHeaderStepperPillDimensions` | Header Stepper bar rendering di tiap step | Tepat 4 capsule pills; pill aktif berukuran 20pt opacity tinggi, 3 pill lain 6pt opacity rendah | ✅ Passed (0.018s) |
| **TC-H06** | `testFooterButtonTitleReactivity` | Label tombol footer CTA di Step 0-2 vs Step 3 | Berlabel `"Continue"` di Step 0, 1, 2; Otomatis berganti label menjadi `"Get Started"` di Step 3 | ✅ Passed (0.010s) |
