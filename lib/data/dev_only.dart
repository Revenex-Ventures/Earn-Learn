/// Marks a class as a temporary local-development implementation.
///
/// Local repositories exist so the app keeps working without Firebase during
/// Stage 1B. They are replaced by Firestore-backed repositories in Stage 2
/// and must never become the production path.
class DevOnly {
  const DevOnly([this.note]);

  final String? note;
}