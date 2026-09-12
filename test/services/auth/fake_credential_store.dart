import 'package:pilipalaz/services/auth/credential_store.dart';
import 'package:pilipalaz/services/auth/stored_session.dart';

final class MemoryCredentialStore implements CredentialStore {
  StoredSession? storedSession;
  String? installId;
  final List<String> operations = <String>[];

  CredentialStoreFailure? readSessionFailure;
  CredentialStoreFailure? writeSessionFailure;
  CredentialStoreFailure? deleteSessionFailure;
  CredentialStoreFailure? readInstallIdFailure;
  CredentialStoreFailure? writeInstallIdFailure;

  @override
  Future<void> deleteSession() async {
    operations.add('deleteSession');
    final failure = deleteSessionFailure;
    if (failure != null) {
      throw failure;
    }
    storedSession = null;
  }

  @override
  Future<String?> readInstallId() async {
    operations.add('readInstallId');
    final failure = readInstallIdFailure;
    if (failure != null) {
      throw failure;
    }
    return installId;
  }

  @override
  Future<StoredSession?> readSession() async {
    operations.add('readSession');
    final failure = readSessionFailure;
    if (failure != null) {
      throw failure;
    }
    return storedSession;
  }

  @override
  Future<void> writeInstallId(String value) async {
    operations.add('writeInstallId');
    final failure = writeInstallIdFailure;
    if (failure != null) {
      throw failure;
    }
    installId = value;
  }

  @override
  Future<void> writeSession(StoredSession session) async {
    operations.add('writeSession');
    final failure = writeSessionFailure;
    if (failure != null) {
      throw failure;
    }
    storedSession = session;
  }
}
