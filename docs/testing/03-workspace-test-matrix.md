# Test Matrix: Feature 03 — Workspace Management & Avatar Storage

> **Related Spec:** [`docs/specs/03-workspace.md`](file:///Users/putra/Development/Personal/Projects/Kuma/Repositories/Kuma/docs/specs/03-workspace.md)  
> **Test Target Files:**  
> - `KumaTests/Features/Workspace/WorkspaceInitialStateTests.swift` (Kategori A: Baseline Default Workspace & Init)  
> - `KumaTests/Features/Workspace/WorkspaceValidationAndSecurityTests.swift` (Kategori B: Name Validation, Downsampling & Security)  
> - `KumaTests/Features/Workspace/WorkspacePersistenceAndSyncTests.swift` (Kategori C: GRDB CRUD, Cascade, Ordering & Concurrency)  
> - `KumaTests/Features/Workspace/WorkspaceImageStoreLifecycleTests.swift` (Kategori D: Storage Directory, ImageIO, Caching & Deletion)  
> - `KumaTests/Features/Workspace/WorkspaceEdgeCasesAndErrorTests.swift` (Kategori E: Edge Cases, Quirks, Sole Workspace Protection)  
> - `KumaTests/Features/Workspace/WorkspaceVisualTests.swift` (Kategori F: Headless SwiftUI Hierarchy & HIG Accessibility)  
> - `KumaTests/Harness/WorkspaceTestHarness.swift` (Shared In-Memory SQLite & Temp Files Test Harness)  

---

## Master Test Case Matrix (35 Scenarios) — 100% Passed

### Kategori A: Initial State & Baseline Contracts (Defaults & Seed)
| ID | Nama Test Case | Deskripsi Skenario & Kondisi Batas | Expected Result | Status |
| :--- | :--- | :--- | :--- | :--- |
| **TC-A01** | `testFreshBootSeedsDefaultWorkspace` | Inisialisasi DB kosong, `WorkspaceStore` meload data | Otomatis dibuat default workspace dengan personalized name (`<User>'s Space`) & `sortOrder = 0` | ✅ Passed (0.085s) |
| **TC-A02** | `testDefaultWorkspacePersistsToDB` | Memeriksa tabel `workspace` SQLite setelah fresh boot | Record ditemukan di DB, `id` valid UUID, `createdAt` & `updatedAt` terisi | ✅ Passed (0.086s) |
| **TC-A03** | `testDefaultWorkspaceSelected` | Memeriksa `selectedWorkspaceId` pada fresh boot | `selectedWorkspaceId == defaultWorkspace.id`, `activeWorkspace != nil` | ✅ Passed (0.088s) |
| **TC-A04** | `testExistingWorkspacesLoadedInSortOrder` | DB sudah memiliki 3 workspace dengan `sortOrder` (0, 1, 2) | Workspaces ter-load dengan urutan asc yang tepat, count == 3 | ✅ Passed (0.087s) |
| **TC-A05** | `testPersistedSelectedWorkspaceRestored` | Key `kuma.selectedWorkspaceId.storage` tersimpan di UserDefaults | `selectedWorkspaceId` me-restore UUID yang tersimpan, bukan default pertama | ✅ Passed (0.098s) |
| **TC-A06** | `testCorruptedSavedWorkspaceIdFallsBackToFirst` | Key di UserDefaults menyimpan UUID yang sudah tidak ada di DB | Otomatis fallback ke `workspaces.first?.id` | ✅ Passed (0.094s) |

---

### Kategori B: Input/Form Validation, Crypto/Vault & Security
| ID | Nama Test Case | Deskripsi Skenario & Kondisi Batas | Expected Result | Status |
| :--- | :--- | :--- | :--- | :--- |
| **TC-B01** | `testWorkspaceNameTrimming` | Menambahkan workspace dengan leading/trailing whitespaces `"  Backend Team  "` | Disimpan sebagai `"Backend Team"` tanpa spasi liar | ✅ Passed (0.007s) |
| **TC-B02** | `testEmptyWorkspaceNameFallback` | Menambahkan workspace dengan nama kosong `""` atau hanya spasi `"   "` | Fallback otomatis ke `"New Workspace"` di store level | ✅ Passed (0.004s) |
| **TC-B03** | `testWorkspaceNameWithSpecialCharacters` | Menambahkan workspace dengan simbol & unicode `"🚀 Cluster #1 (Dev/Staging)"` | Tersimpan dan di-render sempurna tanpa encoding glitch | ✅ Passed (0.057s) |
| **TC-B04** | `testWorkspaceAvatarImageHardwareDownsampling` | User memilih gambar external berukuran besar (4K / 4096x4096px) | Disimpan di Application Support dengan resolusi downscaled max 512px, PNG atomic | ✅ Passed (0.022s) |
| **TC-B05** | `testWorkspaceAvatarPOSIXPermissions` | Gambar avatar disimpan ke dalam folder app support | File PNG memiliki hak akses POSIX yang aman dan valid | ✅ Passed (0.007s) |
| **TC-B06** | `testWorkspaceBase64ImageRoundtrip` | Konversi avatar workspace ke Base64 (untuk backup) lalu restore kembali | Data gambar identik, thumbnail dapat di-generate kembali | ✅ Passed (0.005s) |
| **TC-B07** | `testWorkspaceBase64InvalidDataRejection` | Decode string base64 yang korup / bukan gambar | Mengembalikan `nil`, tidak menimbulkan crash atau file kosong | ✅ Passed (0.001s) |

---

### Kategori C: Concurrency, Mutations & Database Mutations (GRDB)
| ID | Nama Test Case | Deskripsi Skenario & Kondisi Batas | Expected Result | Status |
| :--- | :--- | :--- | :--- | :--- |
| **TC-C01** | `testAddWorkspaceInsertsRecordAndSelects` | Menambahkan workspace baru lewat `addWorkspace(name:)` | Bertambah di array in-memory, tersimpan di SQLite, terpilih sebagai active | ✅ Passed (0.072s) |
| **TC-C02** | `testRenameWorkspaceUpdatesRecord` | Rename workspace `"Old Name"` $\to$ `"New Name"` | Nama terupdate di DB & memory, `updatedAt` ter-bump | ✅ Passed (0.073s) |
| **TC-C03** | `testDeleteWorkspaceRemovesRecord` | Menghapus workspace kedua dari daftar | Record terhapus dari SQLite, array berkurang, image terhapus | ✅ Passed (0.071s) |
| **TC-C04** | `testDeleteActiveWorkspaceFallsBack` | Menghapus workspace yang sedang aktif terpilih | `selectedWorkspaceId` otomatis pindah ke workspace pertama yang tersisa | ✅ Passed (0.010s) |
| **TC-C05** | `testDeleteWorkspaceCascadesToServices` | Menghapus workspace yang memiliki child services | GRDB cascade delete membersihkan seluruh service dan provider anak | ✅ Passed (0.074s) |
| **TC-C06** | `testMoveWorkspaceReordersSortOrder` | Swap posisi workspace index 0 dan index 2 | `sortOrder` ter-update di memory & SQLite secara batch `(0, 1, 2)` | ✅ Passed (0.094s) |
| **TC-C07** | `testConcurrentWorkspaceCreations` | Menjalankan pembuatan beberapa workspace secara paralel | Seluruh workspace tersimpan tanpa data race atau SQLite lock error | ✅ Passed (0.148s) |
| **TC-C08** | `testConcurrentWorkspaceReadsAndWrites` | Melakukan fetch bersamaan dengan mutasi rename dan move | Transaksi thread-safe via GRDB `DatabaseWriter`, tidak ada inkonsistensi | ✅ Passed (0.075s) |

---

### Kategori D: Storage Directory, ImageIO, Caching & Deletion
| ID | Nama Test Case | Deskripsi Skenario & Kondisi Batas | Expected Result | Status |
| :--- | :--- | :--- | :--- | :--- |
| **TC-D01** | `testImagesDirectoryCreation` | Memanggil `WorkspaceImageStore.imagesDirectoryURL()` saat folder belum ada | Folder `Kuma/Workspaces/Images` otomatis dibuat di Application Support | ✅ Passed (0.002s) |
| **TC-D02** | `testSaveWorkspaceImageCopiesManagedFile` | Menyimpan gambar dari file URL lokal | Disimpan sebagai `{workspaceID}.png` di direktori managed Kuma | ✅ Passed (0.005s) |
| **TC-D03** | `testThumbnailCachingWithNSCache` | Load thumbnail 2x berturut-turut untuk gambar yang sama | Load kedua disajikan dari `NSCache` memory cache (pointer equality) | ✅ Passed (0.008s) |
| **TC-D04** | `testClearMemoryCachePurgesThumbnails` | Memanggil `clearCache()` pada `WorkspaceImageStore` | Cache dikosongkan, pemanggilan berikutnya membaca ulang dari disk | ✅ Passed (0.005s) |
| **TC-D05** | `testDeleteImageRemovesFileAndCache` | Memanggil `deleteImage(for:)` | File PNG di disk terhapus dan cache entry di-invalidate | ✅ Passed (0.009s) |
| **TC-D06** | `testUpdatingWorkspaceWithNewAvatarDeletesOldFile` | User mengganti gambar avatar workspace dengan gambar baru | File gambar lama dihapus dari disk, file gambar baru tersimpan | ✅ Passed (0.008s) |

---

### Kategori E: Edge Cases, Quirks & Sole Workspace Protection
| ID | Nama Test Case | Deskripsi Skenario & Kondisi Batas | Expected Result | Status |
| :--- | :--- | :--- | :--- | :--- |
| **TC-E01** | `testSoleWorkspaceDeletionBlocked` | Mencoba menghapus satu-satunya workspace yang tersisa (`count == 1`) | Deletion ditolak / dicegah, workspace tidak berkurang | ✅ Passed (0.059s) |
| **TC-E02** | `testMissingImageFileFallbackToInitials` | `imagePath` tersimpan di DB namun filenya sudah hilang di disk | `thumbnail` mengembalikan `nil`, AvatarView fallback ke gradient initial | ✅ Passed (0.001s) |
| **TC-E03** | `testCorruptedImageFileHandling` | File di disk berisi file teks bukan format gambar | `thumbnail` mengembalikan `nil` tanpa crash | ✅ Passed (0.006s) |
| **TC-E04** | `testRapidWorkspaceSwitchingStress` | User berpindah antar workspace secara cepat puluhan kali | `selectedWorkspaceId` sinkron dengan UserDefaults tanpa deadlock | ✅ Passed (0.028s) |
| **TC-E05** | `testMoveWorkspaceOutOfBoundsIndexIgnored` | Memanggil `moveWorkspace(from: -1, to: 99)` pada array elemen | Ditolak secara aman tanpa index out of bounds panic | ✅ Passed (0.003s) |

---

### Kategori F: Headless SwiftUI View Hierarchy & HIG Accessibility
| ID | Nama Test Case | Deskripsi Skenario & Kondisi Batas | Expected Result | Status |
| :--- | :--- | :--- | :--- | :--- |
| **TC-F01** | `testSidebarWorkspaceRowAccessibility` | Headless render `SidebarWorkspaceRow` | Menyertakan label aksesibilitas nama workspace & trait `.isButton` | ✅ Passed (0.001s) |
| **TC-F02** | `testWorkspaceSwitcherPopoverInactiveShortcuts` | Render popover dengan 3 workspace | Inactive row menampilkan shortcut badge `⌘2`, `⌘3` | ✅ Passed (0.001s) |
| **TC-F03** | `testWorkspaceAvatarViewGradientGeneration` | Generate avatar tanpa gambar untuk 2 nama berbeda | Inisial huruf pertama akurat, deterministic gradient palette terpilih | ✅ Passed (0.001s) |
| **TC-F04** | `testWorkspaceFormSheetViewModeCreate` | Render `WorkspaceFormSheet` mode `.create` | Title "New Workspace", Danger Zone tidak muncul | ✅ Passed (0.001s) |
| **TC-F05** | `testWorkspaceFormSheetViewModeEditWithDangerZone` | Render `WorkspaceFormSheet` mode `.edit` dengan 2 workspace | Title "Workspace Settings", Danger Zone subview ter-render | ✅ Passed (0.001s) |
