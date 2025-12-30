# Journal Backup Feature

## Overview
The Secret Journal now includes an optional cloud backup feature that automatically syncs journal entries to Firebase Firestore when enabled.

## Architecture

### Data Layer
- **`journal_entry.dart`**: Model representing a journal entry with id, content, and timestamps
- **`journal_repository.dart`**: Handles all Firestore operations (save, delete, fetch, sync)
- **`journal_backup_service.dart`**: Manages backup settings and coordinates local/cloud storage

### Presentation Layer
- **`secret_journal.dart`**: Main journal page with backup integration
- **`journal_settings.dart`**: Settings page for managing backup preferences
- **`edit_journal_entry.dart`**: Entry editing page

## Firebase Structure

```
journal/
  └── {userId}/
      └── entries/
          └── {entryId}/
              ├── id: string
              ├── content: string
              ├── createdAt: timestamp
              └── updatedAt: timestamp
```

## Features

### 1. Cloud Backup Toggle
- Enable/disable backup in settings
- When enabled, automatically syncs all existing entries
- When disabled, entries remain local only

### 2. Automatic Sync
- Every write operation (add/update) automatically saves to cloud if backup is enabled
- Delete operations also sync to cloud
- Undo functionality works with cloud sync

### 3. Manual Operations
- **Sync Now**: Manually upload all local entries to cloud
- **Restore from Cloud**: Download and merge cloud entries with local

### 4. Data Safety
- Local-first approach: entries always saved locally first
- Cloud sync happens asynchronously
- Merge strategy prevents data loss during restore
- Each entry has unique UUID for tracking

## Best Practices Implemented

1. **Security**
   - User-scoped data: entries stored under `journal/{userId}/`
   - Firebase security rules should restrict access to authenticated users only
   - Only the entry owner can read/write their entries

2. **Performance**
   - Batch operations for bulk syncing
   - Async operations don't block UI
   - Local storage for instant access

3. **User Experience**
   - Clear feedback for all operations
   - Loading states during sync
   - Confirmation dialogs for destructive actions
   - Undo support for deletions

4. **Data Integrity**
   - Timestamps for created/updated tracking
   - UUID-based entry identification
   - Metadata stored locally for offline support

## Usage

### For Users
1. Open Secret Journal
2. Tap settings icon in app bar
3. Enable "Cloud Backup" toggle
4. Entries will automatically sync on every save

### For Developers
```dart
// Initialize backup service
final backupService = JournalBackupService();

// Check if backup is enabled
final isEnabled = await backupService.isBackupEnabled();

// Save an entry (auto-syncs if backup enabled)
await backupService.saveEntry('My journal entry');

// Delete an entry
await backupService.deleteEntry('entry content');

// Manual sync
await backupService.syncAllEntries();

// Restore from cloud
await backupService.restoreFromCloud();
```

## Firebase Security Rules

Add these rules to your Firestore:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /journal/{userId}/entries/{entryId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## Future Enhancements
- Conflict resolution for simultaneous edits
- Encryption at rest
- Export/import functionality
- Search and filtering
- Rich text formatting
- Attachment support
