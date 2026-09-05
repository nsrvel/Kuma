# Test Matrix: Feature 00 — App Foundation & Lifecycle

> **Related Spec:** [`docs/specs/00-app.md`](file:///Users/putra/Development/Personal/Projects/Kuma/Repositories/Kuma/docs/specs/00-app.md)  
> **Test Target Files:**  
> - `KumaTests/Features/App/SingleInstanceGuardTests.swift` (Kategori A: Single Instance Guard & Test Bypass)  
> - `KumaTests/Features/App/AppCoordinatorTests.swift` (Kategori B: App Coordinator, Phase Transitions & Storage Integrity)  
> - `KumaTests/Features/App/LifecycleTeardownTests.swift` (Kategori C: Lifecycle, Subprocess Kill & Buffer Teardown)  
> - `KumaTests/Features/App/AlertServiceTests.swift` (Kategori D: Alert Bus, Actions, Isolation & Single-Slot Modal)  
> - `KumaTests/Features/App/CryptoVaultTests.swift` (Kategori E: Vault Security, POSIX Permissions & AES-256-GCM)  
> - `KumaTests/Features/App/KumaSoundManagerTests.swift` (Kategori F: Audio Sync, Idempotency & Playback)  
> - `KumaTests/Features/App/KumaCommandsTests.swift` (Kategori G: Global Menu Commands, Notifications & Shortcuts)  
> - `KumaTests/Features/App/AppThemeAndNotificationTests.swift` (Kategori H: Theme Tokens & Foreground Notifications)  
> - `KumaTests/Harness/AppTestHarness.swift` (Shared Sandbox, Temp Directory & Vault Key Isolation)

---

## Master Test Case Matrix (39 Scenarios)

### Kategori A: Single Instance Guard & Test Bypass (`SingleInstanceGuardTests.swift`)
| ID | Nama Test Case | Deskripsi Skenario & Kondisi Batas | Expected Result | Invariant Target |
| :--- | :--- | :--- | :--- | :--- |
| **TC-A01** | `testTestEnvironmentBypass` | Menjalankan `activateExistingInstanceIfRunning()` di dalam test runner aktif (`XCTestCase` / env test). | Mengembalikan `false`, tidak menghentikan test runner. | `[INV-APP-01]` |
| **TC-A02** | `testSoleRunningInstanceReturnsFalse` | Mensimulasikan hanya 1 process running yang terdaftar dengan bundle ID Kuma. | Guard mengembalikan `false`, membolehkan launch normal berlanjut. | `[INV-APP-01]` |
| **TC-A03** | `testMissingBundleIdentifierFallback` | Pengecekan guard ketika `Bundle.main.bundleIdentifier` bernilai `nil`. | Fallback aman mengembalikan `false` tanpa fatal error/crash. | `[INV-APP-01]` |
| **TC-A04** | `testDuplicateInstanceActivatesExisting` | Mensimulasikan instance kedua dengan PID berbeda terdeteksi berjalan. | Guard mengembalikan `true`, memanggil `activate()` pada instance yang sudah ada. | `[INV-APP-01]` |

---

### Kategori B: App Coordinator, Phase Transitions & Storage Integrity (`AppCoordinatorTests.swift`)
| ID | Nama Test Case | Deskripsi Skenario & Kondisi Batas | Expected Result | Invariant Target |
| :--- | :--- | :--- | :--- | :--- |
| **TC-B01** | `testInitialPhaseFirstLaunchClean` | Inisialisasi `AppCoordinator()` tanpa argumen saat key onboarding belum pernah diset di `UserDefaults`. | `currentPhase == .onboarding`. | `[INV-APP-02]` |
| **TC-B02** | `testInitialPhaseReturningUser` | Inisialisasi `AppCoordinator()` saat key onboarding bernilai `true`. | `currentPhase == .mainWorkspace`. | `[INV-APP-02]` |
| **TC-B03** | `testExplicitInitialPhaseOverride` | Menginisialisasi `AppCoordinator(initialPhase: .onboarding)` saat key di `UserDefaults` bernilai `true`. | Parameter eksplisit meng-override storage (`currentPhase == .onboarding`). | `[INV-APP-02]` |
| **TC-B04** | `testTransitionToMainWorkspacePersistsTrue` | Memanggil `coordinator.transitionTo(.mainWorkspace)`. | `currentPhase == .mainWorkspace` dan `UserDefaults` tersimpan `true`. | `[INV-APP-02]` |
| **TC-B05** | `testTransitionToOnboardingPersistsFalse` | Memanggil `coordinator.transitionTo(.onboarding)`. | `currentPhase == .onboarding` dan `UserDefaults` tersimpan `false`. | `[INV-APP-02]` |
| **TC-B06** | `testResetToOnboardingConvenience` | Memanggil `coordinator.resetToOnboarding()`. | Menjalankan transisi ke `.onboarding` dan menyimpan `false` ke storage. | `[INV-APP-02]` |
| **TC-B07** | `testCorruptedDefaultsKeyFallback` | Storage diisi objek non-boolean atau data corrupted. | Fallback aman ke `false` $\to$ `.onboarding` tanpa fatal error. | `[INV-APP-02]` |

---

### Kategori C: Lifecycle, Subprocess Kill & Buffer Teardown (`LifecycleTeardownTests.swift`)
| ID | Nama Test Case | Deskripsi Skenario & Kondisi Batas | Expected Result | Invariant Target |
| :--- | :--- | :--- | :--- | :--- |
| **TC-C01** | `testProcessRegistryTerminateAllSpawns` | Daftarkan process dummy (misal: `sleep 60`) ke `ProcessRegistry`, lalu panggil `terminateAll()`. | Process di-kill deterministik, `isRunning == false`, dan unregistered dari registry. | `[INV-APP-03]` |
| **TC-C02** | `testProcessRegistryUnregistersExited` | Process child yang exit mandiri sebelum `terminateAll()` dipanggil. | Status di-update, tidak melempar error saat `terminateAll()` membersihkan list. | `[INV-APP-03]` |
| **TC-C03** | `testLogFileWriterFlushOnTerminate` | Tulis baris log ke buffer `LogFileWriter` lalu panggil `flushAll()`. | Semua buffer tertulis ke file disk dan handle tertutup tanpa byte tertinggal. | `[INV-APP-03]` |
| **TC-C04** | `testMultipleProcessesConcurrentKill` | Daftarkan beberapa process paralel (3+ dummy processes) dan terminate serentak. | Semua process terbunuh tanpa dead lock atau race condition di actor registry. | `[INV-APP-03]` |
| **TC-C05** | `testProcessRegistryTerminateAllIdempotency` | Panggil `terminateAll()` dua kali berurutan dengan task yang sudah mati. | Berjalan aman (idempoten), zero crash, zero memory leak. | `[INV-APP-03]` |

---

### Kategori D: Alert Bus, Actions, Isolation & Single-Slot Modal (`AlertServiceTests.swift`)
| ID | Nama Test Case | Deskripsi Skenario & Kondisi Batas | Expected Result | Invariant Target |
| :--- | :--- | :--- | :--- | :--- |
| **TC-D01** | `testInitialAlertStateNil` | Periksa `AlertService.shared.activeAlert` saat inisialisasi awal. | Bernilai `nil`. | `[INV-APP-04]` |
| **TC-D02** | `testPresentAlertSetsPayload` | Panggil `AlertService.shared.presentAlert(...)` dengan title, message, dan buttons. | `activeAlert` terisi dengan title, message, dan button roles yang sesuai. | `[INV-APP-04]` |
| **TC-D03** | `testDismissAlertClearsActiveAlert` | Panggil `AlertService.shared.dismissAlert()`. | `activeAlert` kembali menjadi `nil`. | `[INV-APP-04]` |
| **TC-D04** | `testAlertButtonRolesAndActionCallbacks` | Konfigurasi `.primary`, `.cancel`, dan `.destructive` button dengan callback closures. | Eksekusi closure berjalan pada `@MainActor` dan memicu action yang terpasang. | `[INV-APP-04]` |
| **TC-D05** | `testRapidConsecutiveAlertsReplacement` | Memanggil `presentAlert()` berturut-turut dengan 2 payload berbeda. | Payload kedua menggantikan payload pertama secara bersih (single-slot modal). | `[INV-APP-04]` |

---

### Kategori E: Vault Security, POSIX Permissions & AES-256-GCM (`CryptoVaultTests.swift`)
| ID | Nama Test Case | Deskripsi Skenario & Kondisi Batas | Expected Result | Invariant Target |
| :--- | :--- | :--- | :--- | :--- |
| **TC-E01** | `testMasterKeyAutoGeneration` | Panggil `getOrCreateMasterKey()` saat key file belum ada di disk sandbox. | File `master.key` terbuat dengan panjang tepat 32 bytes (256 bits). | `[INV-APP-05]` |
| **TC-E02** | `testMasterKeyPOSIXPermissions0600` | Periksa atribut POSIX permission pada file `master.key` yang terbuat. | Permission tepat `0o600` (hanya owner read/write) dan direktori induk `0o700`. | `[INV-APP-05]` |
| **TC-E03** | `testMasterKeyIdempotentRetrieval` | Panggil `getOrCreateMasterKey()` berkali-kali. | Key yang dikembalikan sama persis (cached / byte-identical), tidak me-regenerate. | `[INV-APP-05]` |
| **TC-E04** | `testAES256GCMEncryptDecryptRoundtrip` | Enkripsi string teks sensitif (misal: password SSH/token k8s) lalu dekripsi kembali. | String hasil dekripsi sama persis dengan plaintext awal. | `[INV-APP-05]` |
| **TC-E05** | `testEncryptedPayloadFormatStructure` | Periksa format string hasil enkripsi. | Berformat tiga bagian terpisah titik dua (`nonce:tag:ciphertext`). | `[INV-APP-05]` |
| **TC-E06** | `testCorruptedCiphertextDecryptionFails` | Coba dekripsi payload dengan tag atau ciphertext yang diubah/corrupt. | Melempar error `CryptoVaultError.payloadCorrupted` tanpa silent fail. | `[INV-APP-05]` |
| **TC-E07** | `testInvalidPayloadFormatRejection` | Coba dekripsi string acak tanpa format `nonce:tag:ciphertext`. | Melempar error `CryptoVaultError.invalidPayloadFormat`. | `[INV-APP-05]` |
| **TC-E08** | `testCorruptedMasterKeyFileTriggersSafeReplacement` | File `master.key` di disk berukuran salah (< 32 bytes). | Me-regenerate key 32-byte baru secara otomatis dan log warning tanpa crash. | `[INV-APP-05]` |
| **TC-E09** | `testEmptyStringAndMultilineEncryptionRoundtrip` | Enkripsi string kosong dan string multiline (misal private key RSA dengan `\n`). | Terenkripsi dan terdekripsi 100% identik tanpa truncation. | `[INV-APP-05]` |

---

### Kategori F: Audio Sync, Idempotency & Playback (`KumaSoundManagerTests.swift`)
| ID | Nama Test Case | Deskripsi Skenario & Kondisi Batas | Expected Result | Invariant Target |
| :--- | :--- | :--- | :--- | :--- |
| **TC-F01** | `testSyncSoundFileToUserLibrarySounds` | Panggil `syncCustomNotificationSoundToUserLibrary()` di sandbox environment. | File `kuma-alert.caf` tersalin ke direktori target `Library/Sounds/`. | `[INV-APP-06]` |
| **TC-F02** | `testSyncSoundIdempotentSkip` | Panggil `syncCustomNotificationSoundToUserLibrary()` saat file target sudah ada. | Melewati proses copy (skip disk write) tanpa error dan tanpa memodifikasi file. | `[INV-APP-06]` |
| **TC-F03** | `testPlaySoundGracefulFallbackWhenMissing` | Panggil `playNotificationSound()` saat resource bundle tidak tersedia. | Melakukan fallback ke `NSSound.beep()` tanpa crash. | `[INV-APP-06]` |

---

### Kategori G: Global Menu Commands, Notifications & Shortcuts (`KumaCommandsTests.swift`)
| ID | Nama Test Case | Deskripsi Skenario & Kondisi Batas | Expected Result | Invariant Target |
| :--- | :--- | :--- | :--- | :--- |
| **TC-G01** | `testSettingsMenuNotificationEmission` | Trigger action Settings di `KumaCommands`. | Mem-post notification `.kumaOpenSettings` ke default NotificationCenter. | `[INV-APP-07]` |
| **TC-G02** | `testFindMenuNotificationEmission` | Trigger action Find Services di `KumaCommands`. | Mem-post notification `.kumaFocusSearch` ke default NotificationCenter. | `[INV-APP-07]` |
| **TC-G03** | `testHelpMenuTriggersOnboardingResetAndNotification` | Trigger action Onboarding Guide di menu Help. | Memanggil `coordinator.resetToOnboarding()` dan mem-post `.kumaOpenOnboarding`. | `[INV-APP-07]` |
| **TC-G04** | `testWorkspacesMenuDynamicSelection` | Simulasikan pemilihan workspace via menu Workspaces (⌘1..⌘9). | Memanggil `workspaceStore.selectWorkspace(ws)` dan meng-update current workspace. | `[INV-APP-07]` |

---

### Kategori H: Theme Tokens & Foreground Notifications (`AppThemeAndNotificationTests.swift`)
| ID | Nama Test Case | Deskripsi Skenario & Kondisi Batas | Expected Result | Invariant Target |
| :--- | :--- | :--- | :--- | :--- |
| **TC-H01** | `testKumaThemeTokensContrastAndValidity` | Evaluasi token warna `surfaceBackground`, `cardBackground`, `textPrimary`, `statusOnline`, dll. | Seluruh color asset / dynamic semantic tokens dapat di-instantiate tanpa nil color space crash. | `[INV-APP-08]` |
| **TC-H02** | `testNotificationDelegateForegroundOptions` | Panggil delegate method `userNotificationCenter(_:willPresent:withCompletionHandler:)`. | Completion handler menerima opsi lengkap `[.banner, .sound, .badge]`. | `[INV-APP-09]` |

