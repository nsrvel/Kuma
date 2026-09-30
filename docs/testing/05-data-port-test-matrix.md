# Test Matrix: Feature 05 — DataPort (Unified Scoped Architecture)

> **Related Spec:** [`docs/specs/05-data-port.md`](file:///Users/putra/Development/Personal/Projects/Kuma/Repositories/Kuma/docs/specs/05-data-port.md)  
> **Test Target Files:**  
> - `KumaTests/Features/DataPort/DataPortInitialStateTests.swift` (Kategori A: Baseline Structure, Polymorphic Parsing, Single-Service Wrap)  
> - `KumaTests/Features/DataPort/DataPortValidationAndSecurityTests.swift` (Kategori B: Scope Validation, Conflict Detection, Future Version Guard)  
> - `KumaTests/Features/DataPort/DataPortPersistenceAndSyncTests.swift` (Kategori C: Unified Scoped Export/Import, Re-ID Mapping, Memberships, Atomicity)  
> - `KumaTests/Features/DataPort/DataPortRuntimeAndResetTests.swift` (Kategori D: Storage Reset, ProcessRegistry Subprocess Termination, Workspace Isolation)  
> - `KumaTests/Features/DataPort/DataPortEdgeCasesAndErrorTests.swift` (Kategori E: Single-Service to Full Backup Conversion, Orphan Mappings, Missing Files)  
> - `KumaTests/Features/DataPort/DataPortVisualAndAccessibilityTests.swift` (Kategori F: Headless SwiftUI Master-Detail Sheets, Strict <150 Line Limits, HIG Accessibility)  
> - `KumaTests/Harness/DataPortTestHarness.swift` (Shared In-Memory SQLite & Temp Files Test Harness)  

---

## Master Test Case Matrix (36 Scenarios)

### Kategori A: Initial State & Baseline Contracts (Schema V1, Scopes & Wrap)
| ID | Nama Test Case | Deskripsi Skenario & Kondisi Batas | Expected Result |
| :--- | :--- | :--- | :--- |
| **TC-A01** | `testKumaBackupDefaultProperties` | Inisialisasi `DataPortService.KumaBackup` tanpa parameter eksplisit | `version == currentVersion`, `exportedAt` valid Date, workspaces & services kosong |
| **TC-A02** | `testKumaBackupDeterministicID` | Generate `.id` dari `KumaBackup` | Format `"{version}_{timestamp}_{count}"` stabil dan sendable |
| **TC-A03** | `testBackupDateStringFormatting` | Memeriksa format `DataPortService.backupDateString` | Format string `"yyyy-MM-dd"`, cocok dengan regex `^\d{4}-\d{2}-\d{2}$` |
| **TC-A04** | `testSingleServiceExportWrapToBackup` | Konversi `SingleServiceExport` menjadi `KumaBackup` via `wrapSingleService` | Menghasilkan `KumaBackup` valid dengan 1 service, providers & portMappings utuh |
| **TC-A05** | `testDataPortScopeDefinition` | Verifikasi enum `DataPortScope` (`.all`, `.workspace(id)`, `.service(id)`) | Equatable dan Sendable contracts terpenuhi |
| **TC-A06** | `testExportProviderCategoryMapping` | Verifikasi mapping seluruh enum string ke `ProviderCategory` | Seluruh string raw value ter-map ke category enum yang tepat tanpa crash |

---

### Kategori B: Input/Form Validation, Crypto/Vault & Security (Version Guard & Polymorphic Ingestion)
| ID | Nama Test Case | Deskripsi Skenario & Kondisi Batas | Expected Result |
| :--- | :--- | :--- | :--- |
| **TC-B01** | `testFutureVersionBackupRejection` | Decode JSON dengan `version: 999` (> `currentVersion`) | Throws `DataPortError.unsupportedFutureVersion(backupVersion: 999, currentVersion: 1)` |
| **TC-B02** | `testPolymorphicParserDetectsFullBackup` | Parse JSON data yang berisi full `KumaBackup` payload | Berhasil ter-decode sebagai `KumaBackup` tanpa error |
| **TC-B03** | `testPolymorphicParserDetectsSingleService` | Parse JSON data yang berisi `SingleServiceExport` payload | Berhasil ter-decode dan otomatis di-wrap menjadi `KumaBackup` |
| **TC-B04** | `testCorruptedJSONDecodingFailure` | Decode data acak non-JSON `"invalid binary noise"` | Throws decoding error standar Swift, tidak crash |
| **TC-B05** | `testNameConflictDetectionInWorkspaceImport` | Import backup ke target workspace yang sudah memiliki service bernama `"Frontend"` | Menandai `hasConflict = true`, menghasilkan renamed override `"Frontend (Imported)"` |
| **TC-B06** | `testCaseInsensitiveNameConflictDetection` | Nama service di backup `"frontend"`, target workspace memiliki `"FRONTEND"` | Terdeteksi sebagai conflict (case-insensitive), auto-rename diaplikasikan |

---

### Kategori C: Concurrency, Mutations & Database Mutations (Unified Relational Integrity)
| ID | Nama Test Case | Deskripsi Skenario & Kondisi Batas | Expected Result |
| :--- | :--- | :--- | :--- |
| **TC-C01** | `testExportAllPopulatesFullRelationalHierarchy` | Seed DB dengan workspace, group, service, provider, port mapping | `exportData(scope: .all)` mengembalikan backup lengkap dengan seluruh entitas dan relasi valid |
| **TC-C02** | `testExportWorkspaceScopesToWorkspaceID` | DB memiliki Workspace A dan Workspace B; panggil `exportData(scope: .workspace(A))` | Backup hanya berisi entitas milik Workspace A, zero leakage dari Workspace B |
| **TC-C03** | `testExportSingleServiceScopesToServiceID` | DB memiliki beberapa service; panggil `exportData(scope: .service(ID))` | Backup hanya berisi 1 service terpilih beserta providers dan port mappings-nya |
| **TC-C04** | `testImportAllRestoresCompleteGraph` | Import full backup ke DB kosong via `importData` | Seluruh workspace, group, service, provider, port mapping, dan membership tersimpan di SQLite |
| **TC-C05** | `testImportIntoWorkspaceReIDsAllEntities` | Import backup ke target workspace via strategi `.reassignIDs` | Seluruh service, provider, port mapping mendapat UUID baru, foreign keys ter-link sempurna |
| **TC-C06** | `testImportSelectiveImportsOnlyChosenWorkspacesAndServices` | Backup berisi 3 workspace & 10 service; pilih 1 workspace & 2 service | Hanya workspace dan service terpilih yang tersimpan ke SQLite |
| **TC-C07** | `testAtomicFileWriteOnExport` | Export data dan verifikasi atomic write options | File tertulis dengan atomic write protection, data utuh |
| **TC-C08** | `testImportRollbackOnDatabaseFailure` | Simulasi kegagalan constraint saat import | Transaksi SQLite me-rollback seluruh mutasi, database kembali ke state awal |
| **TC-C09** | `testEquivalenceAcrossAllEntryPoints` | Verifikasi kesetaraan struktur data antara export Settings, DnD drop parsing, Toolbar export, dan Copy Config | Entitas Service, Provider, dan Port Mappings terbukti identik di ke-4 entry point |
| **TC-C10** | `testCrossEntryPointRoundtrip` | Copy Config diekspor ke JSON, lalu di-paste/import ke workspace lain via `importData` | Menghasilkan records SQLite lengkap dan identik dengan hasil Full Restore |

---

### Kategori D: Runtime/Process State Integration (ProcessRegistry, Storage Reset & Lifecycle)
| ID | Nama Test Case | Deskripsi Skenario & Kondisi Batas | Expected Result |
| :--- | :--- | :--- | :--- |
| **TC-D01** | `testStorageResetTerminatesActiveProcesses` | Register running process di `ProcessRegistry`, lalu panggil `resetAllAppStorage()` | `ProcessRegistry.shared.terminateAll()` dipanggil, semua process berstatus terminated |
| **TC-D02** | `testStorageResetWipesSQLiteDatabaseRecords` | DB memiliki workspaces, services, providers; jalankan `resetAllAppStorage()` | SQLite user tables kosong, starter default workspace otomatis ter-seed kembali |
| **TC-D03** | `testStorageResetWipesUserDefaultsPreferences` | Atur preferensi custom, jalankan `resetAllAppStorage()` | Seluruh key preferensi dihapus dari UserDefaults |
| **TC-D04** | `testStorageResetClearsWorkspaceImageCacheAndFolder` | Simpan avatar gambar di `WorkspaceImageStore`, jalankan `resetAllAppStorage()` | Memory cache dikosongkan, folder gambar dibersihkan |
| **TC-D05** | `testConcurrentExportRequests` | Menjalankan 5 operasi export simultan di background | Thread safety GRDB `DatabaseWriter` terjamin, semua menghasilkan backup yang identik |

---

### Kategori E: Edge Cases, Error Handling & macOS System Quirks
| ID | Nama Test Case | Deskripsi Skenario & Kondisi Batas | Expected Result |
| :--- | :--- | :--- | :--- |
| **TC-E01** | `testExportNonExistentSingleServiceThrows404` | Panggil `exportData(scope: .service(fakeID))` dengan UUID yang tidak ada | Throws error 404 "Service not found" |
| **TC-E02** | `testImportBackupWithNullOptionalFields` | Backup V1 tidak memiliki field `groups` dan `workspaceImages` (`nil`) | Decode & import berhasil tanpa error, groups & images di-handle opsional |
| **TC-E03** | `testImportServiceWithoutProvidersOrPorts` | Service dalam backup tidak memiliki provider dan port mapping | Service tersimpan di SQLite dengan `activeProviderID == nil` secara aman |
| **TC-E04** | `testPortMappingProviderIDResolutionFallback` | Port mapping merujuk ke serviceID lama vs providerID | Resolver mendeteksi mapping yang tepat dan menyimpan relasi valid |
| **TC-E05** | `testComposeImageExtractionFromYamlConfig` | Provider Docker memiliki YAML dengan `image: "docker.io/library/redis:alpine"` | `resolvedTarget` mengekstrak image name bersih `"redis:alpine"` |
| **TC-E06** | `testClipboardJSONPasteVerification` | Verifikasi payload clipboard dari Copy Config dapat di-ingest via `parseAnyBackup` | Menghasilkan `KumaBackup` valid yang siap di-import langsung ke workspace |

---

### Kategori F: Headless SwiftUI View Hierarchy & Accessibility HIG
| ID | Nama Test Case | Deskripsi Skenario & Kondisi Batas | Expected Result |
| :--- | :--- | :--- | :--- |
| **TC-F01** | `testImportPreviewSheetFileLinesLimitStrict` | Audit baris kode `ImportPreviewSheet.swift` dan `WorkspaceImportPreviewSheet.swift` | Seluruh view modular < 150 baris kode |
| **TC-F02** | `testImportDetailInspectorPaneFileLinesLimitStrict` | Audit baris kode `ImportDetailInspectorPane.swift` dan extracted sub-views | Seluruh komponen inspector < 150 baris kode |
| **TC-F03** | `testImportPreviewHeaderViewRendering` | Headless render `ImportPreviewHeaderView` | Title, subtitle, icon, dan search field ter-render dengan HIG layout |
| **TC-F04** | `testImportPreviewFooterViewRendering` | Headless render `ImportPreviewFooterView` | Tombol Select All / Deselect All, selection count, Cancel, dan Import Selected ter-render valid |
| **TC-F05** | `testImportDetailInspectorPaneAccessibilityLabels` | Render inspector pane dengan provider Docker & port mappings | Card surfaces, status pills, dan labels memiliki accessibility traits yang tepat |
