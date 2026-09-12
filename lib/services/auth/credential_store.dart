import 'stored_session.dart';

abstract interface class CredentialStore {
  Future<StoredSession?> readSession();

  Future<void> writeSession(StoredSession session);

  Future<void> deleteSession();

  Future<String?> readInstallId();

  Future<void> writeInstallId(String value);
}

enum CredentialStoreFailureKind {
  unavailable,
  corrupt,
  writeFailed,
  deleteFailed,
}

final class CredentialStoreFailure implements Exception {
  const CredentialStoreFailure(this.kind);

  final CredentialStoreFailureKind kind;

  String get message => switch (kind) {
    CredentialStoreFailureKind.unavailable =>
      'Secure credential storage is unavailable.',
    CredentialStoreFailureKind.corrupt => 'Secure credential data is invalid.',
    CredentialStoreFailureKind.writeFailed =>
      'Secure credential data could not be saved.',
    CredentialStoreFailureKind.deleteFailed =>
      'Secure credential data could not be deleted.',
  };

  @override
  String toString() => 'CredentialStoreFailure(kind: ${kind.name})';
}
