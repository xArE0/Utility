import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cryptography/cryptography.dart';
import 'package:path_provider/path_provider.dart';

/// Centralises all crypto operations for the Data Vault.
///
/// • DB-level : generates / retrieves the SQLCipher password (stored in the
///              Android Keystore via flutter_secure_storage).
/// • Export   : AES-256-GCM encrypts vault data with a user-chosen password
///              (PBKDF2 key derivation).
/// • Import   : reverses the export flow.
class VaultCryptoService {
  VaultCryptoService._();
  static final VaultCryptoService instance = VaultCryptoService._();

  static const _keyStorageKey = 'vault_db_encryption_key';
  static const _migratedFlag = 'vault_migrated_to_encrypted';

  // 16-byte salt  +  12-byte nonce  =  28-byte header before ciphertext
  static const _saltLength = 16;
  static const _nonceLength = 12;
  static const _pbkdf2Iterations = 100000;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // ──────────────────────────────────────────────
  //  SQLCipher password (Android Keystore-backed)
  // ──────────────────────────────────────────────

  /// Returns the 32-byte hex-encoded password used by SQLCipher.
  /// Creates one on first call and persists it in the Keystore.
  Future<String> getOrCreateDbPassword() async {
    String? existing = await _secureStorage.read(key: _keyStorageKey);
    if (existing != null && existing.isNotEmpty) return existing;

    // Generate a cryptographically secure 32-byte key, hex-encode it
    final rng = Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    final password = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    await _secureStorage.write(key: _keyStorageKey, value: password);
    return password;
  }

  /// Whether the one-time migration from unencrypted → encrypted has run.
  Future<bool> isMigrated() async {
    final flag = await _secureStorage.read(key: _migratedFlag);
    return flag == 'true';
  }

  /// Mark migration as complete.
  Future<void> markMigrated() async {
    await _secureStorage.write(key: _migratedFlag, value: 'true');
  }

  /// Reset the migration flag (used after importing a plain DB that needs
  /// re-encryption on next app launch).
  Future<void> resetMigrationFlag() async {
    await _secureStorage.delete(key: _migratedFlag);
  }

  // ──────────────────────────────────────────────
  //  Export encryption  (user-password based)
  // ──────────────────────────────────────────────

  /// Encrypts [plainBytes] with AES-256-GCM using a key derived from
  /// [userPassword] via PBKDF2.
  ///
  /// File layout: `[16-byte salt][12-byte nonce][ciphertext+mac]`
  Future<Uint8List> encryptBytes(Uint8List plainBytes, String userPassword) async {
    final rng = Random.secure();
    final salt = Uint8List.fromList(List.generate(_saltLength, (_) => rng.nextInt(256)));
    final nonce = Uint8List.fromList(List.generate(_nonceLength, (_) => rng.nextInt(256)));

    final secretKey = await _deriveKey(userPassword, salt);

    final algorithm = AesGcm.with256bits();
    final secretBox = await algorithm.encrypt(
      plainBytes,
      secretKey: secretKey,
      nonce: nonce,
    );

    // Concatenate: salt + nonce + (ciphertext + mac)
    final output = BytesBuilder();
    output.add(salt);
    output.add(nonce);
    output.add(secretBox.concatenation(nonce: false));
    return output.toBytes();
  }

  /// Decrypts data produced by [encryptBytes].
  Future<Uint8List> decryptBytes(Uint8List encryptedData, String userPassword) async {
    if (encryptedData.length < _saltLength + _nonceLength + 16) {
      throw const FormatException('Encrypted data is too short or corrupted.');
    }

    final salt = Uint8List.sublistView(encryptedData, 0, _saltLength);
    final nonce = Uint8List.sublistView(encryptedData, _saltLength, _saltLength + _nonceLength);
    final ciphertextAndMac = Uint8List.sublistView(encryptedData, _saltLength + _nonceLength);

    final secretKey = await _deriveKey(userPassword, salt);

    final algorithm = AesGcm.with256bits();
    final secretBox = SecretBox.fromConcatenation(
      ciphertextAndMac,
      nonceLength: 0,
      macLength: 16,
    );

    final decrypted = await algorithm.decrypt(
      SecretBox(secretBox.cipherText, nonce: nonce, mac: secretBox.mac),
      secretKey: secretKey,
    );
    return Uint8List.fromList(decrypted);
  }

  /// Encrypts vault data (as JSON string) into a `.vault` file.
  Future<File> encryptVaultExport(String jsonData, String userPassword) async {
    final plainBytes = Uint8List.fromList(utf8.encode(jsonData));
    final encrypted = await encryptBytes(plainBytes, userPassword);

    final tempDir = await getTemporaryDirectory();
    final outFile = File('${tempDir.path}/datavault_backup.vault');
    await outFile.writeAsBytes(encrypted, flush: true);
    return outFile;
  }

  /// Decrypts a `.vault` file and returns the JSON string.
  Future<String> decryptVaultImport(File vaultFile, String userPassword) async {
    final encryptedBytes = await vaultFile.readAsBytes();
    final decrypted = await decryptBytes(Uint8List.fromList(encryptedBytes), userPassword);
    return utf8.decode(decrypted);
  }

  // ──────────────────────────────────────────────
  //  Internal
  // ──────────────────────────────────────────────

  Future<SecretKey> _deriveKey(String password, Uint8List salt) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _pbkdf2Iterations,
      bits: 256,
    );
    return pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
  }
}
