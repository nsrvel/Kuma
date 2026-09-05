# Test Matrix: Feature 04 — Sidebar Navigation & Service Groups

> **Related Spec:** [`docs/specs/04-sidebar.md`](file:///Users/putra/Development/Personal/Projects/Kuma/Repositories/Kuma/docs/specs/04-sidebar.md)  
> **Test Target Files:**  
> - `KumaTests/Features/Sidebar/SidebarInitialStateTests.swift` (Kategori A: Baseline Structure, Stable UUIDs, Default Expansion)  
> - `KumaTests/Features/Sidebar/SidebarValidationAndSecurityTests.swift` (Kategori B: Group Name Sanitization, Boundary Limits, Drag Payload)  
> - `KumaTests/Features/Sidebar/SidebarPersistenceAndReorderTests.swift` (Kategori C: GRDB CRUD, Workspace Scoping, SortOrder, Concurrency)  
> - `KumaTests/Features/Sidebar/SidebarRuntimeAndNotificationTests.swift` (Kategori D: NotificationCenter Bus, Workspace Reload, Optimistic State)  
> - `KumaTests/Features/Sidebar/SidebarEdgeCasesAndErrorTests.swift` (Kategori E: Rapid Keyboard Traversal, Missing/Corrupt Data, Selection Fallback)  
> - `KumaTests/Features/Sidebar/SidebarVisualAndAccessibilityTests.swift` (Kategori F: Headless SwiftUI Hierarchy, Line Limits <150, HIG & VoiceOver)  
> - `KumaTests/Harness/SidebarTestHarness.swift` (Shared In-Memory SQLite & Test Harness for Sidebar/Groups)  

---

## Master Test Case Matrix (35 Scenarios)

### Kategori A: Initial State & Baseline Contracts (Fixed Nodes, Stable UUIDs, Defaults)
| ID | Nama Test Case | Deskripsi Skenario & Kondisi Batas | Expected Result | Status |
| :--- | :--- | :--- | :--- | :--- |
| **TC-A01** | `testSidebarDefaultEntriesStructure` | Inisialisasi `SidebarViewModel.makeDefault()` tanpa argumen | Menghasilkan 4 top-level entries: `all-services`, `starred-services`, `live-logs`, dan `groups` | ⏳ Pending Approval |
| **TC-A02** | `testFixedNodesDeterministicUUIDs` | Memeriksa id dari fixed entries `all-services`, `starred-services`, `live-logs`, `groups` | Sesuai dengan hasil hash `UUID.stable(key)` dan konsisten di seluruh sesi | ⏳ Pending Approval |
| **TC-A03** | `testDefaultSelectedNodeIsAllServices` | Fresh instance `SidebarViewModel` | `selectedID == UUID.stable("all-services")` | ⏳ Pending Approval |
| **TC-A04** | `testGroupsHeaderExpandedByDefault` | Fresh instance `SidebarViewModel` | `expandedIDs` memuat `.stable("groups")`, `isExpanded(.stable("groups")) == true` | ⏳ Pending Approval |
| **TC-A05** | `testFlattenedRowsCountOnFreshBoot` | Cek `flattenedRows` pada fresh boot tanpa groups di database | Terdiri dari 4 row item: 3 fixed navigable rows + 1 empty placeholder row di bawah groups header | ⏳ Pending Approval |
| **TC-A06** | `testInitialEditingGroupIDIsNil` | Inisialisasi default ViewModel | `editingGroupID == nil`, tidak ada row yang berada dalam mode inline edit | ⏳ Pending Approval |

---

### Kategori B: Input/Form Validation, Crypto/Vault & Security (Name Sanitization & Boundary Limits)
| ID | Nama Test Case | Deskripsi Skenario & Kondisi Batas | Expected Result | Status |
| :--- | :--- | :--- | :--- | :--- |
| **TC-B01** | `testGroupNameTrimmingWhitespaces` | User rename group dengan whitespace berlebih `"   Production Cluster   "` | Nama tersimpan dan ter-update bersih sebagai `"Production Cluster"` | ⏳ Pending Approval |
| **TC-B02** | `testEmptyGroupNameFallbackToUntitled` | User rename group dengan string kosong `""` atau hanya spasi `"    "` | Otomatis fallback ke `"Untitled Group"`, tidak crash dan tidak tersimpan string kosong | ⏳ Pending Approval |
| **TC-B03** | `testGroupNameWithSpecialCharactersAndEmoji` | Menambahkan group bernama `"⚡ Cloudflare Tunnels (Staging/v2)"` | Nama tersimpan akurat, UTF-8 unicode encoding utuh tanpa glitch | ⏳ Pending Approval |
| **TC-B04** | `testGroupNameBoundaryLength` | Input nama group sangat panjang (>255 karakter) | Disimpan dengan aman, View merender dengan `.lineLimit(1)` dan `.truncationMode(.tail)` | ⏳ Pending Approval |
| **TC-B05** | `testDragDropPayloadUUIDValidation` | Simulasi drag item string bukan format UUID (misal: `"malformed-data"`) | Payload ditolak secara aman, `onReorder` tidak dieksekusi, tidak ada mutasi state | ⏳ Pending Approval |
| **TC-B06** | `testGroupMembershipJoinTableIntegrity` | Menghubungkan service ke group via `service_group_membership` | Relasi Many-to-Many valid, record `(serviceID, groupID)` tersimpan di SQLite | ⏳ Pending Approval |

---

### Kategori C: Concurrency, Mutations & Database Mutations (GRDB & Reordering)
| ID | Nama Test Case | Deskripsi Skenario & Kondisi Batas | Expected Result | Status |
| :--- | :--- | :--- | :--- | :--- |
| **TC-C01** | `testAddGroupOptimisticAndPersisted` | User klik Add Group pada workspace tertentu | Array `groups` in-memory bertambah (0ms), `sortOrder` terisi `max + 1`, tersimpan di SQLite `service_group` | ⏳ Pending Approval |
| **TC-C02** | `testRenameGroupUpdatesDatabaseRecord` | Rename group ID tertentu dari `"Old"` $\to$ `"New"` | Nama terupdate di in-memory dan record SQLite `service_group.name`, `updatedAt` ter-bump | ⏳ Pending Approval |
| **TC-C03** | `testDeleteGroupRemovesDatabaseRecord` | Menghapus group ID tertentu | Record terhapus dari SQLite `service_group` | ⏳ Pending Approval |
| **TC-C04** | `testDeleteGroupPreservesWorkspaceServices` | Menghapus group yang memiliki beberapa service di dalamnya | Record `service` tetap utuh di SQLite, relasi group menjadi `nil` atau membership terhapus tanpa menghapus service | ⏳ Pending Approval |
| **TC-C05** | `testWorkspaceScopedGroupsIsolation` | Workspace A memiliki 2 groups, Workspace B memiliki 1 group | `fetchAll(workspaceID: A)` hanya menghasilkan 2 groups milik A, tidak ada leakage group B | ⏳ Pending Approval |
| **TC-C06** | `testMoveGroupsUpdatesSortOrdersBatch` | Reorder groups index 0 ke index 2 | Seluruh groups memiliki `sortOrder` berurutan `0, 1, 2` di memory dan SQLite | ⏳ Pending Approval |
| **TC-C07** | `testConcurrentGroupCreations` | Menjalankan pembuatan beberapa groups secara concurrent Task | Tidak terjadi SQLite lock contention atau data race, seluruh group tersimpan | ⏳ Pending Approval |
| **TC-C08** | `testConcurrentReadAndReorderTransactions` | Fetch all groups bersamaan dengan operasi reorder batch | GRDB `DatabaseWriter` mengeksekusi dengan isolasi serial, konsistensi data terjaga | ⏳ Pending Approval |

---

### Kategori D: Runtime/Process State Integration (NotificationCenter & Workspace Switch)
| ID | Nama Test Case | Deskripsi Skenario & Kondisi Batas | Expected Result | Status |
| :--- | :--- | :--- | :--- | :--- |
| **TC-D01** | `testNotificationPostedOnGroupAdd` | Memanggil `addGroup(workspaceID:)` | `NotificationCenter.default` menerima event `.kumaGroupsUpdated` dengan group ID sebagai payload | ⏳ Pending Approval |
| **TC-D02** | `testNotificationPostedOnGroupRename` | Memanggil `renameGroup(id:newName:)` | `NotificationCenter.default` menerima event `.kumaGroupsUpdated` | ⏳ Pending Approval |
| **TC-D03** | `testNotificationPostedOnGroupDelete` | Memanggil `deleteGroup(id:)` | `NotificationCenter.default` menerima event `.kumaGroupsUpdated` | ⏳ Pending Approval |
| **TC-D04** | `testNotificationPostedOnGroupReorder` | Memanggil `moveGroups(fromOffsets:toOffset:)` | `NotificationCenter.default` menerima event `.kumaGroupsUpdated` | ⏳ Pending Approval |
| **TC-D05** | `testWorkspaceSwitchTriggersReload` | Workspace aktif berganti dari Workspace A ke Workspace B | `loadGroups(workspaceID: B)` dipanggil, entries dan flattenedRows ter-rebuild dengan groups B | ⏳ Pending Approval |
| **TC-D06** | `testNewServiceButtonEmitsNotification` | User tap `SidebarNewServiceButton` | Notifikasi `.kumaCreateServiceRequested` terpancar ke sistem | ⏳ Pending Approval |

---

### Kategori E: Edge Cases, Error Handling & macOS System Quirks (Keyboard & Fallback)
| ID | Nama Test Case | Deskripsi Skenario & Kondisi Batas | Expected Result | Status |
| :--- | :--- | :--- | :--- | :--- |
| **TC-E01** | `testDeleteActiveSelectedGroupFallsBackToAllServices` | Group yang sedang aktif terpilih dihapus oleh user | `selectedID` otomatis fallback ke `UUID.stable("all-services")`, tidak nil/orphan | ⏳ Pending Approval |
| **TC-E02** | `testKeyboardArrowDownNavigation` | Menekan panah `Down` saat di row 0 (`all-services`) | `selectedID` berpindah ke row berikutnya (`starred-services`) | ⏳ Pending Approval |
| **TC-E03** | `testKeyboardArrowUpNavigation` | Menekan panah `Up` saat di row 1 | `selectedID` berpindah kembali ke row sebelumnya (`all-services`) | ⏳ Pending Approval |
| **TC-E04** | `testKeyboardArrowBoundariesClamp` | Menekan `Up` di row paling atas atau `Down` di row paling bawah | Selection tidak index-out-of-bounds, tetap di elemen batas | ⏳ Pending Approval |
| **TC-E05** | `testKeyboardArrowLeftCollapsesGroup` | Selection berada di node group yang expanded, user tekan panah `Left` | Node ter-collapse, `expandedIDs` tidak lagi memuat id node tersebut | ⏳ Pending Approval |
| **TC-E06** | `testKeyboardArrowRightExpandsGroup` | Selection berada di node group yang collapsed, user tekan panah `Right` | Node ter-expand, `expandedIDs` memuat id node tersebut | ⏳ Pending Approval |
| **TC-E07** | `testMoveGroupOutOfBoundsIgnored` | Memanggil `moveGroupUp` pada index 0 atau `moveGroupDown` pada index terakhir | Method guard return early, array tidak berubah dan tidak throw exception | ⏳ Pending Approval |

---

### Kategori F: Headless SwiftUI View Hierarchy & Accessibility HIG
| ID | Nama Test Case | Deskripsi Skenario & Kondisi Batas | Expected Result | Status |
| :--- | :--- | :--- | :--- | :--- |
| **TC-F01** | `testSidebarViewHierarchyModularity` | Headless render `SidebarView` | View hierarchy ter-render valid dengan subview modularitas lengkap (<150 baris per file) | ⏳ Pending Approval |
| **TC-F02** | `testSidebarRowViewAccessibilityTraits` | Render `SidebarRowView` untuk node biasa dan header | Node biasa memiliki trait `.isButton`, header memiliki trait `.isHeader` | ⏳ Pending Approval |
| **TC-F03** | `testSidebarActionButtonsAccessibility` | Render `SidebarActionButton` dan chevron | Tombol memiliki accessibility label/tooltip (`"New Group"`, `"Expand"`, `"Collapse"`) | ⏳ Pending Approval |
| **TC-F04** | `testSidebarEmptyPlaceholderRender` | Render `SidebarEmptyPlaceholderRow` | Menampilkan italic caption placeholder dengan indent yang proporsional | ⏳ Pending Approval |
| **TC-F05** | `testSidebarFooterButtonsAccessibility` | Render footer buttons (`Settings` & `Help`) | Tombol footer memiliki tooltips & accessibility labels yang jelas | ⏳ Pending Approval |
