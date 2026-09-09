# Test Matrix: Feature 06 — Services (Deck, Inspector, Execution & Management)

> **Related Spec:** [`docs/specs/06-services.md`](file:///Users/putra/Development/Personal/Projects/Kuma/Repositories/Kuma/docs/specs/06-services.md)  
> **Target Test Suites:**  
> - `KumaTests/Features/Services/ServicesInitialStateTests.swift` (Kategori A: Baseline Contracts, Projections, Enums)  
> - `KumaTests/Features/Services/ServicesValidationAndSecurityTests.swift` (Kategori B: CryptoVault Encryption, Form Validation, Port Ranges)  
> - `KumaTests/Features/Services/ServicesPersistenceAndSyncTests.swift` (Kategori C: Unified Single-Source State, Deck↔Inspector Sync, DB Transactions)  
> - `KumaTests/Features/Services/ServicesRuntimeAndExecutionTests.swift` (Kategori D: Process Lifecycle, PGID Isolation, Runner Execution, Stop Notifications)  
> - `KumaTests/Features/Services/ServicesEdgeCasesAndErrorTests.swift` (Kategori E: Rapid Keystrokes, Auto-Save Flush on Disappear, Port Collision, Stream Flooding)  
> - `KumaTests/Features/Services/ServicesVisualAndAccessibilityTests.swift` (Kategori F: Headless SwiftUI Decomposed Views, Strict <150 Line Limit, HIG Accessibility Labels)  
> - `KumaTests/Harness/ServicesTestHarness.swift` (Shared In-Memory SQLite V1-V4 Schema, Mock Runner & Sandboxed Process Test Harness)

---

## Master Test Case Matrix (36 Scenarios)

### Kategori A: Initial State & Baseline Contracts (Models, Projections & Enums)
| ID | Nama Test Case | Deskripsi Skenario & Kondisi Batas | Expected Result |
| :--- | :--- | :--- | :--- |
| **TC-A01** | `testServiceEntityDefaultProperties` | Inisialisasi model `Service` baru | Default `isDisabled = false`, `isStarred = false`, `groupIDs.isEmpty = true`, valid UUID |
| **TC-A02** | `testProviderEntityResolvedTarget` | Hitung `resolvedTarget` untuk berbagai jenis `ProviderCategory` (K8s pod, Docker compose, Shell, SSH) | String target deskriptif yang tepat dan non-empty |
| **TC-A03** | `testServiceExecutionStateDiscreteTransitions` | Verifikasi state enum `ServiceExecutionState` (`.idle`, `.starting`, `.running(pid)`, `.stopping`, `.crashed(code)`, `.failed(reason)`) | Discrete enum transitions tanpa multi-boolean flags |
| **TC-A04** | `testServiceCardSnapshotProjectionIntegrity` | Proyeksikan Service + Providers + Port Mappings ke `ServiceCardSnapshot` | Model snapshot ringan (~64B), tidak membawa credential atau raw yaml |
| **TC-A05** | `testProviderCategoryDomainPurity` | Verifikasi `ProviderCategory` di layer Domain | Tidak ada ketergantungan `import SwiftUI` pada Domain enum |
| **TC-A06** | `testServicePortMappingValidation` | Port mapping dengan port valid (1-65535) | Parsing protocol TCP/UDP dan mapping port konsisten |

---

### Kategori B: Input/Form Validation, Crypto/Vault & Security (Credential Encryption & Port Ranges)
| ID | Nama Test Case | Deskripsi Skenario & Kondisi Batas | Expected Result |
| :--- | :--- | :--- | :--- |
| **TC-B01** | `testSSHPasswordEncryptedInDatabase` | Simpan provider SSH dengan password via `ServiceRepository` | Nilai di kolom SQLite `sshPassword` terenkripsi (bukan plaintext), roundtrip decode berhasil terdekripsi |
| **TC-B02** | `testNgrokTokenEncryptedInDatabase` | Simpan provider Tunnel dengan ngrok auth token via `ServiceRepository` | Nilai di kolom SQLite `ngrokAuthToken` terenkripsi AES-GCM via `CryptoVault` |
| **TC-B03** | `testCustomKubeConfigPathPersistence` | Simpan provider K8s dengan custom kubeconfig path | Path tersimpan di SQLite (skema V4) dan tidak hilang saat reload |
| **TC-B04** | `testInvalidPortMappingRejection` | Input port di luar rentang valid (misal 0, 70000, negatif) | Error validasi tertolak sebelum persisted ke DB |
| **TC-B05** | `testServiceNameEmptyValidation` | Validasi form create service dengan nama kosong atau hanya spasi | Menolak pembuatan service, mengembalikan error `invalidConfiguration` |
| **TC-B06** | `testDataPortExportCredentialEncryption` | Export service yang memiliki password/token ke backup JSON | Credential tidak bocor dalam plaintext pada file JSON backup |

---

### Kategori C: Concurrency, Mutations & Database Integrity (Deck ↔ Inspector State Sync)
| ID | Nama Test Case | Deskripsi Skenario & Kondisi Batas | Expected Result |
| :--- | :--- | :--- | :--- |
| **TC-C01** | `testSingleQueryServiceDetailFetch` | Panggil `fetchServiceDetail(id:)` dari Inspector ViewModel | Mengembalikan Service, Providers, dan Port Mappings dalam 1 single read transaction |
| **TC-C02** | `testGranularSingleSnapshotFetch` | Panggil `fetchSnapshot(serviceID:)` setelah single update | Hanya me-load 1 snapshot tanpa query ulang seluruh workspace |
| **TC-C03** | `testInspectorAutoSaveCommitDebounce` | User mengetik field di Inspector berturut-turut | Hanya 1 kali write transaction ke SQLite yang dieksekusi setelah debounce selesai |
| **TC-C04** | `testDeckInspectorSharedStateSync` | Update provider atau nama service di Inspector | Perubahan langsung terrefleksi di Deck tanpa full workspace reload |
| **TC-C05** | `testInspectorListensToDeckDeletion` | Service yang sedang dibuka di Inspector dihapus dari Deck context menu | Inspector menangani event deletion secara anggun (close drawer / clear state) |
| **TC-C06** | `testInspectorListensToDeckProviderSwitch` | Switch provider aktif dari Deck card context menu | Inspector merefresh state provider aktif tanpa perlu ditutup dan dibuka ulang |
| **TC-C07** | `testDuplicateServiceAtomicIntegrity` | Duplikasi service yang memiliki multiple providers dan ports | Semua relasi terduplikasi sempurna dalam 1 write transaction dengan UUID baru |
| **TC-C08** | `testToggleStarredOptimisticSync` | Toggle star pada service | State lokal dan SQLite tersinkronisasi tanpa UI flicker atau overwrite race |

---

### Kategori D: Runtime/Process State Integration (ProcessRegistry, POSIX Safety & Runners)
| ID | Nama Test Case | Deskripsi Skenario & Kondisi Batas | Expected Result |
| :--- | :--- | :--- | :--- |
| **TC-D01** | `testProcessGroupSetpgidBeforeRun` | Spawn subprocess via `ProcessRegistry` | Child process terdaftar di isolated process group (PGID) dengan aman |
| **TC-D02** | `testStopServiceKeepsPipesOpenUntilExit` | Hentikan service yang sedang running via `stop(serviceID:)` | Pipes tetap terbuka saat SIGINT dikirim, tidak memicu `SIGPIPE` pada child process |
| **TC-D03** | `testStopServiceDispatchesStateChangedNotification` | Panggil `stop(serviceID:)` sampai subprocess exit | Notifikasi `.kumaServiceStateChanged` dengan state `.idle` / `.stopped` terkirim ke seluruh app |
| **TC-D04** | `testBatchProcessStatusLookup` | Query status proses untuk 50 serviceIDs sekaligus | Mengembalikan status dalam 1 single actor call tanpa serial loop |
| **TC-D05** | `testServiceExecutionEngineDockerYamlWrite` | Jalankan Docker provider yang memiliki `yamlConfig` | File compose sementara dibuat dan flag `-f` disematkan dengan benar |
| **TC-D06** | `testServiceExecutionEngineSSHKeyFlag` | Jalankan SSH provider yang memiliki `sshKeyPath` | Argumen `-i <keyPath>` disertakan dalam command ssh |

---

### Kategori E: Edge Cases, Error Handling & System Quirks
| ID | Nama Test Case | Deskripsi Skenario & Kondisi Batas | Expected Result |
| :--- | :--- | :--- | :--- |
| **TC-E01** | `testInspectorAutoSaveFlushedOnDisappear` | Edit field di Inspector lalu segera trigger `onDisappear` (<300ms) | Perubahan langsung di-flush dan ter-commit ke database, tidak hilang |
| **TC-E02** | `testInspectorClearLogsScopedToServiceID` | Klik tombol trash logs di Inspector | Hanya log milik service aktif yang dihapus, log service lain tetap utuh |
| **TC-E03** | `testRapidLogStreamDoesNotHitchMainActor` | Stream 2,000 log lines dalam 1 detik | Log di-coalesce/batch ke MainActor tanpa task flooding atau UI freeze |
| **TC-E04** | `testLogAggregatorRingBufferBoundedMemory` | Stream log melebihi `maxEntries` (2,000 baris) | Memory bounded, operasi pembuangan log lama efisien ($O(1)$) tanpa array shift overhead |
| **TC-E05** | `testZeroEffortWhenIdle` | App dalam kondisi idle tanpa service running | Zero active polling tasks, zero CPU wakeups |
| **TC-E06** | `testNonBlockingProcessWaitInAsyncEngine` | Jalankan resolving pod / dynamic check di background | Tidak memblokir thread worker kooperatif Swift Concurrency |

---

### Kategori F: Headless SwiftUI View Hierarchy, Modularitas & HIG Accessibility
| ID | Nama Test Case | Deskripsi Skenario & Kondisi Batas | Expected Result |
| :--- | :--- | :--- | :--- |
| **TC-F01** | `testAllServicesViewsUnder150Lines` | Audit baris kode seluruh view files di fitur Services | 100% file view Services memiliki baris kode <= 150 baris |
| **TC-F02** | `testAllServicesViewsHavePreviews` | Verifikasi keberadaan `#Preview` pada seluruh SwiftUI views | Semua views memiliki block `#Preview` yang dapat di-render tanpa crash |
| **TC-F03** | `testIconOnlyButtonsHaveAccessibilityLabels` | Audit tombol icon-only di Toolbar, Card, Table, dan Inspector | Seluruh tombol icon-only memiliki `.accessibilityLabel(...)` |
| **TC-F04** | `testServicesDeckViewHierarchyRendering` | Render headless `ServicesDeckView` dalam state empty dan filled | Hirarki view terbangun dengan bersih tanpa layout recursion |
| **TC-F05** | `testServiceInspectorViewHierarchyRendering` | Render headless `ServiceInspectorView` dengan data mock | Form sections ter-render lengkap dengan interaksi keyboard HIG |
| **TC-F06** | `testCreateServiceSheetStepNavigation` | Render headless `CreateServiceSheet` dan navigasi antar step | Navigasi step 1 (Provider) ke step 2 (Details) mulus |
