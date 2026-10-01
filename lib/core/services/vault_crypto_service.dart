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
    final now = DateTime.now();
    final dateStr = '${now.year}_${now.month.toString().padLeft(2, '0')}_${now.day.toString().padLeft(2, '0')}';
    final outFile = File('${tempDir.path}/datavault_backup_$dateStr.vault');
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
  //  Password hashing (secret menu)
  // ──────────────────────────────────────────────

  /// Salted PBKDF2 hash of [password], as "base64(salt):base64(hash)". Only the hash is stored, so
  /// the password itself can't be read back from the device.
  Future<String> hashPassword(String password) async {
    final rng = Random.secure();
    final salt = Uint8List.fromList(List.generate(_saltLength, (_) => rng.nextInt(256)));
    final hash = await (await _deriveKey(password, salt)).extractBytes();
    return '${base64.encode(salt)}:${base64.encode(hash)}';
  }

  /// Checks [password] against a [hashPassword] result, in constant time.
  Future<bool> verifyPassword(String password, String stored) async {
    try {
      final parts = stored.split(':');
      if (parts.length != 2) return false;
      final salt = Uint8List.fromList(base64.decode(parts[0]));
      final expected = base64.decode(parts[1]);
      final actual = await (await _deriveKey(password, salt)).extractBytes();
      if (actual.length != expected.length) return false;
      var diff = 0;
      for (var i = 0; i < actual.length; i++) {
        diff |= actual[i] ^ expected[i];
      }
      return diff == 0;
    } catch (_) {
      return false;
    }
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
