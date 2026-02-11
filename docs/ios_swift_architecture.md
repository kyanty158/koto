# KOTO iOS Native Rewrite Architecture

## Goals
- Recreate the Flutter MVP in a SwiftUI-first iOS 15+ app.
- Preserve “起動→入力1秒以内” and gesture-first workflows.
- Keep all data/notifications offline-first while leaving room for future Pro sync.

## Technology Selections
- **UI**: SwiftUI (iOS 15 deployment target) with UIKit bridges only where required (keyboard focus, haptics).
- **State**: ObservableObject + Environment injection. Lightweight store objects mirror Riverpod providers.
- **Persistence**: Core Data with NSPersistentCloudKitContainer disabled. `MemoEntity` stores:
  - `id:Int64`, `text:String`, `createdAt/updatedAt:Date`, `reminderAt:Date?`, `isDone:Bool`, `inlineTags:[String]` (transformable)  
  - Fetch request helpers supply `NSPredicate` for Basic vs Pro limits.
- **Notifications**: `UNUserNotificationCenter` with `UNNotificationAction` set (done / snooze / edit). Identifiers reuse `MemoEntity.id`.
- **Subscription Tier**: Local `SubscriptionManager` (enum: `.basic`, `.pro`). Basic restrictions implemented client-side:
  - Reminder cap (≤5 per calendar month)
  - List limited to 50 items
  - Search disabled
- **Undo**: `MemoUndoManager` wraps Core Data context + cached last-saved/deleted memo metadata.
- **Utilities**: `InlineTagExtractor` replicates Flutter regex logic.

## Module Layout
```
Sources/
  KotoApp/
    KotoApp.swift          // Entry point & scene setup
    AppEnvironment.swift   // Aggregates shared stores/services
  Data/
    PersistenceController.swift
    MemoEntity+CoreData.swift
    MemoRepository.swift
  Domain/
    MemoModel.swift
    ReminderPreset.swift
    SubscriptionManager.swift
    UndoManager.swift
  Services/
    NotificationService.swift
  Features/
    Write/
      WriteView.swift
      WriteViewModel.swift
    View/
      MemoListViewModel.swift
      MemoListView.swift
    Edit/
      EditView.swift
  Support/
    TwoFingerTapView.swift
    Color+Platform.swift
```

## Core Flows
- **Cold Launch**: `KotoApp` loads Core Data stack asynchronously, requests notification authorization, and shows WriteView once warm KPI ends.
- **Write**:
  1. TextEditor auto-focus via `FocusState` helpers.
  2. `DragGesture` determines direction thresholds: left→discard, down→save, right→open reminder rail.
  3. Reminder rail uses `ReminderPreset.all` for quick drop. Fast flick still resolves via last hover / cursor / default heuristics.
  4. Save delegates to `MemoRepository.save(text:reminder:)` which enforces reminder quotas (basic tier).
  5. Notification scheduled (if any) and tactile feedback triggered.
- **View**:
  - Fetch request segmented into upcoming reminders (max 6) and remaining history.
  - Search bar (Pro only) filters by full text or `#tag`.
  - Selection mode supports multi-delete with toolbar actions.
  - Free tier optionally shows house ad placeholder.
- **Edit**:
  - Presents sheet from list or notification action deep-link.
  - Allows toggling completion, editing text, rescheduling reminder.

## Future Extensions
- Swap Core Data transformable inline tags for dedicated child entity when/if syncing with Cloud Firestore.
- Introduce `MemoSyncService` hooking into Firebase once available.
- Consider SwiftData migration (iOS 17+) when raising deployment target.

## Build Artefacts
- Xcode project `KotoApp.xcodeproj` (to be generated) targeting iOS 15, Swift 5.10.
- Unit tests using `XCTest` for tag extraction and reminder quota logic.
