# Test Matrix: Feature 02 — Settings & Preferences

> **Related Spec:** [`docs/specs/02-settings.md`](file:///Users/putra/Development/Personal/Projects/Kuma/Repositories/Kuma/docs/specs/02-settings.md)  
> **Test Target Files:**  
> - `KumaTests/Features/Settings/SettingsInitialStateTests.swift` (Kategori A: Baseline Defaults & Init)  
> - `KumaTests/Features/Settings/SettingsValidationAndSecurityTests.swift` (Kategori B: Validasi Path & File Security)  
> - `KumaTests/Features/Settings/SettingsPersistenceAndSyncTests.swift` (Kategori C: Concurrency, Mutations & Legacy Fallbacks)  
> - `KumaTests/Features/Settings/SettingsSystemIntegrationTests.swift` (Kategori D: Appearance & OS Integration)  
> - `KumaTests/Features/Settings/SettingsDataPortLifecycleTests.swift` (Kategori E: Backup, Selective Import & Wipe Storage)  
> - `KumaTests/Features/Settings/SettingsVisualTests.swift` (Kategori F: Headless SwiftUI Hierarchy & HIG Accessibility)  
> - `KumaTests/Harness/SettingsTestHarness.swift` (Shared Mock Sandbox & File Environment)

---

## Master Test Case Matrix (35 Scenarios)

### Kategori A: Initial State & Baseline Contracts (Defaults)
| ID | Nama Test Case | Deskripsi Skenario & Kondisi Batas | Expected Result | Status |
| :--- | :--- | :--- | :--- | :--- |
| **TC-A01** | `testDefaultGeneralSettings` | Fresh install tanpa preexisting UserDefaults keys | `launchAtLogin == false`, `autoResumeServices == true`, `confirmBeforeQuit == true` | ✅ Passed (0.002s) |
| **TC-A02** | `testDefaultAppearance` | Fresh install tanpa key appearance tersimpan | `appearance == .system`, title "System Default" | ✅ Passed (0.001s) |
| **TC-A03** | `testDefaultEnginePaths` | Fresh install path binary custom kosong | `customKubectlPath`, `customDockerPath`, `customPodmanPath` bernilai `""` | ✅ Passed (0.002s) |
| **TC-A04** | `testDefaultShellOption` | Inisialisasi default shell | `defaultShell == "/bin/zsh"` | ✅ Passed (0.002s) |
| **TC-A05** | `testDefaultNotificationSettings` | Fresh install nilai default notifikasi & keamanan | `notifyOnCrash == true`, `notifyOnHealthFailure == true`, `warnOnPortCollision == true` | ✅ Passed (0.002s) |
| **TC-A06** | `testDefaultLogRetention` | Fresh install default log retention | `logRetentionLimit == .fiftyMB` (50 MB), `clearLogsOnSwitch == false` | ✅ Passed (0.018s) |

---

### Kategori B: Input/Form Validation, Crypto/Vault & Security
| ID | Nama Test Case | Deskripsi Skenario & Kondisi Batas | Expected Result | Status |
| :--- | :--- | :--- | :--- | :--- |
| **TC-B01** | `testKubectlValidExecutable` | User memilih file executable kubectl yang sah (`0755`) | Validasi `isValid == true`, `errorMessage == nil` | ✅ Passed (0.002s) |
| **TC-B02** | `testKubectlNonExecutableRejection` | User memilih file teks biasa (`0644`) untuk kubectl | Ditolak `notExecutable`, `isValid == false` | ✅ Passed (0.002s) |
| **TC-B03** | `testKubectlBinaryMismatchRejection`| User memilih binary docker pada field kubectl | Ditolak `nameMismatch`, `isValid == false` | ✅ Passed (0.003s) |
| **TC-B04** | `testDockerValidExecutable` | User memilih binary docker executable yang sah | Validasi `isValid == true`, status badge installed | ✅ Passed (0.002s) |
| **TC-B05** | `testPodmanValidExecutable` | User memilih binary podman executable yang sah | Validasi `isValid == true`, status badge installed | ✅ Passed (0.002s) |
| **TC-B06** | `testCloudflaredValidExecutable` | User memilih binary cloudflared executable yang sah | Validasi `isValid == true`, status badge installed | ✅ Passed (0.002s) |
| **TC-B07** | `testNgrokValidExecutable` | User memilih binary ngrok executable yang sah | Validasi `isValid == true`, status badge installed | ✅ Passed (0.034s) |
| **TC-B08** | `testKubeconfigValidFile` | User memilih file yaml kubeconfig yang ada | Validasi sukses, tidak ada pesan error | ✅ Passed (0.002s) |
| **TC-B09** | `testKubeconfigMissingFileRejection`| User menginput path file kubeconfig yang tidak ada | Menampilkan error "Configuration file does not exist" | ✅ Passed (0.003s) |
| **TC-B10** | `testTildePathExpansionInSettings` | User memasukkan path dengan tilde `~/bin/kubectl` | Tilde ter-expand dengan benar ke home directory pengguna | ✅ Passed (0.001s) |

---

### Kategori C: Concurrency, Mutations & Legacy Fallbacks
| ID | Nama Test Case | Deskripsi Skenario & Kondisi Batas | Expected Result | Status |
| :--- | :--- | :--- | :--- | :--- |
| **TC-C01** | `testPropertyMutationPersistsToUserDefaults` | Mutasi `autoResumeServices` dari `true` ke `false` | Nilai di `UserDefaults` langsung ter-update secara synchronous | ✅ Passed (0.003s) |
| **TC-C02** | `testLegacyKubectlPathFallback` | Primary key kosong, namun terdapat legacy key `kuma.custom_kubectl_path` | `KumaSettingsKey.string` me-resolve nilai legacy key dengan sukses | ✅ Passed (0.024s) |
| **TC-C03** | `testLegacyDockerPathFallback` | Primary key kosong, namun terdapat legacy key `kuma.custom_docker_path` | `KumaSettingsKey.string` me-resolve nilai legacy key dengan sukses | ✅ Passed (0.033s) |
| **TC-C04** | `testLegacyCloudflaredPathFallback` | Primary key kosong, terdapat legacy key `kuma.custom_cloudflared_path` | `KumaSettingsKey.string` me-resolve nilai legacy key dengan sukses | ✅ Passed (0.021s) |
| **TC-C05** | `testPrimaryKeyOverridesLegacyKey` | Kedua key (modern & legacy) sama-sama terisi | Nilai modern key yang diutamakan | ✅ Passed (0.013s) |
| **TC-C06** | `testConcurrentSettingsUpdates` | Menjalankan mutasi setting paralel dari beberapa Task `@MainActor` | State tetap konsisten tanpa data race (Swift 6 strict concurrency) | ✅ Passed (0.006s) |

---

### Kategori D: Runtime & OS System Integration
| ID | Nama Test Case | Deskripsi Skenario & Kondisi Batas | Expected Result | Status |
| :--- | :--- | :--- | :--- | :--- |
| **TC-D01** | `testAppearanceSwitchToDark` | Ubah appearance ke `.dark` | `viewModel.appearance == .dark`, `NSApp.appearance` diset `.darkAqua` | ✅ Passed (0.037s) |
| **TC-D02** | `testAppearanceSwitchToLight` | Ubah appearance ke `.light` | `viewModel.appearance == .light`, `NSApp.appearance` diset `.aqua` | ✅ Passed (0.027s) |
| **TC-D03** | `testAppearanceSwitchToSystem` | Ubah appearance ke `.system` | `viewModel.appearance == .system`, `NSApp.appearance` diset `nil` | ✅ Passed (0.033s) |
| **TC-D04** | `testNotificationPermissionDeniedFallback`| Permission notifikasi ditolak oleh OS | `notifyOnCrash` direset ke `false` tanpa crash | ✅ Passed (0.010s) |
| **TC-D05** | `testLaunchAtLoginToggleSafeExecution`| Toggle launch at login di sandbox test | Menjalankan `SMAppService` API dengan penanganan error terisolasi | ✅ Passed (0.015s) |

---

### Kategori E: DataPort Lifecycle, Export/Import & Reset
| ID | Nama Test Case | Deskripsi Skenario & Kondisi Batas | Expected Result | Status |
| :--- | :--- | :--- | :--- | :--- |
| **TC-E01** | `testExportBackupGeneratesValidJSON`| Export database records ke format JSON | Menghasilkan JSON data valid dengan version `DataPortService.currentVersion` | ✅ Passed (0.001s) |
| **TC-E02** | `testImportValidBackupRestoresData` | Decode backup JSON yang valid | Data model `KumaBackup` ter-decode sempurna | ✅ Passed (0.001s) |
| **TC-E03** | `testImportFutureVersionThrowsError` | Mencoba import JSON dengan version lebih baru dari app | Melempar `DataPortError.unsupportedFutureVersion` | ✅ Passed (0.001s) |
| **TC-E04** | `testFactoryResetWipesDefaultsAndDB`| Memanggil `DataPortService.resetAllAppStorage()` | UserDefaults bersih, DB di-wipe, ProcessRegistry di-terminate | ✅ Passed (0.014s) |
| **TC-E05** | `testSelectiveImportFilteredRestore` | Import backup dengan seleksi workspace tertentu saja | Hanya workspace terpilih yang dipulihkan | ✅ Passed (0.001s) |

---

### Kategori F: Headless SwiftUI View Hierarchy & Accessibility HIG
| ID | Nama Test Case | Deskripsi Skenario & Kondisi Batas | Expected Result | Status |
| :--- | :--- | :--- | :--- | :--- |
| **TC-F01** | `testSettingsViewRendersAllSections` | Inisialisasi `SettingsView` dengan viewModel & store | View ter-render tanpa layout crash | ✅ Passed (0.004s) |
| **TC-F02** | `testAppearanceCardSelectionAnimation`| Render `AppearanceCard` untuk ketiga mode tema | Memiliki identitas namespace matched geometry dan accessibility labels | ✅ Passed (0.003s) |
| **TC-F03** | `testBinaryStatusBadgeRendering` | Render `BinaryStatusBadge(isInstalled: true/false)` | Menampilkan icon checkmark hijau saat true, xmark abu-abu saat false | ✅ Passed (0.001s) |
| **TC-F04** | `testDangerZoneConfirmationVisibility` | Pemicu tombol "Reset All Data" | Menampilkan dialog konfirmasi destruktif 2-langkah | ✅ Passed (0.012s) |
| **TC-F05** | `testCLIToolsSectionAutoDetectPaths` | Trigger `.task { await refreshDefaultPaths() }` | Mendeteksi default binary path dari EnvironmentPathResolver | ✅ Passed (0.015s) |
