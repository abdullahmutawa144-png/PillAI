/// Where the app keeps its single JSON snapshot.
///
/// The store depends on this interface rather than a plugin so tests and
/// future encrypted storage can be swapped in without touching domain code.
abstract interface class StateStorage {
  Future<String?> read();

  Future<void> write(String snapshot);

  Future<void> clear();
}

/// Keeps the snapshot in memory. Used by tests and as a safe fallback when a
/// platform has no persistent storage.
class InMemoryStateStorage implements StateStorage {
  InMemoryStateStorage([this.snapshot]);

  String? snapshot;
  int writes = 0;

  @override
  Future<String?> read() async => snapshot;

  @override
  Future<void> write(String snapshot) async {
    writes++;
    this.snapshot = snapshot;
  }

  @override
  Future<void> clear() async => snapshot = null;
}
