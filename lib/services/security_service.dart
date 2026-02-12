import 'dart:math';
import 'dart:typed_data';

import 'package:basic_utils/basic_utils.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart' as pc;

class SecurityService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Storage keys
  static const String _privateKeyStorageKey = 'private_key';
  static const String _publicKeyStorageKey = 'public_key';

  // Generate RSA Key Pair (2048 bit)
  Future<void> generateAndStoreKeys() async {
    // Check if keys already exist
    final existingPrivate = await _storage.read(key: _privateKeyStorageKey);
    if (existingPrivate != null) return;

    // Generate Secure Random
    final secureRandom = pc.FortunaRandom();
    final seedSource = Random.secure();
    final seeds = List<int>.generate(32, (_) => seedSource.nextInt(255));
    secureRandom.seed(pc.KeyParameter(Uint8List.fromList(seeds)));

    final keyGen = pc.RSAKeyGenerator()
      ..init(
        pc.ParametersWithRandom(
          pc.RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
          secureRandom,
        ),
      );

    final pair = keyGen.generateKeyPair();
    final public = pair.publicKey as pc.RSAPublicKey;
    final private = pair.privateKey as pc.RSAPrivateKey;

    final pemPublic = CryptoUtils.encodeRSAPublicKeyToPem(public);
    final pemPrivate = CryptoUtils.encodeRSAPrivateKeyToPem(private);

    await _storage.write(key: _publicKeyStorageKey, value: pemPublic);
    await _storage.write(key: _privateKeyStorageKey, value: pemPrivate);
  }

  Future<String?> getPublicKey() async {
    return await _storage.read(key: _publicKeyStorageKey);
  }

  // Hybrid Encryption: Encrypt message with AES, then encrypt AES key with RSA for BOTH sender and recipient
  Future<Map<String, dynamic>> encryptMessage(
    String plainText,
    String myUid,
    String myPublicKeyPem,
    String otherUid,
    String otherPublicKeyPem,
  ) async {
    final myPublicKey = CryptoUtils.rsaPublicKeyFromPem(myPublicKeyPem);
    final otherPublicKey = CryptoUtils.rsaPublicKeyFromPem(otherPublicKeyPem);

    // 1. Generate random AES key and IV
    final aesKey = encrypt.Key.fromSecureRandom(32);
    final iv = encrypt.IV.fromSecureRandom(16);
    final aesEncrypter = encrypt.Encrypter(encrypt.AES(aesKey));

    // 2. Encrypt content with AES
    final encryptedContent = aesEncrypter.encrypt(plainText, iv: iv);

    // 3. Encrypt AES key using Public Keys (RSA)
    final rsaEncrypterMe = encrypt.Encrypter(
      encrypt.RSA(publicKey: myPublicKey),
    );
    final encryptedAesKeyMe = rsaEncrypterMe.encrypt(aesKey.base64);

    final rsaEncrypterOther = encrypt.Encrypter(
      encrypt.RSA(publicKey: otherPublicKey),
    );
    final encryptedAesKeyOther = rsaEncrypterOther.encrypt(aesKey.base64);

    return {
      'content': encryptedContent.base64,
      'iv': iv.base64,
      'keys': {
        myUid: encryptedAesKeyMe.base64,
        otherUid: encryptedAesKeyOther.base64,
      },
    };
  }

  Future<String> decryptMessage(
    String encryptedContentBase64,
    String encryptedKeyBase64,
    String ivBase64,
  ) async {
    // 1. Load my Private Key
    final privateKeyPem = await _storage.read(key: _privateKeyStorageKey);
    if (privateKeyPem == null) throw Exception('Private key not found');

    final privateKey = CryptoUtils.rsaPrivateKeyFromPem(privateKeyPem);

    // 2. Decrypt AES Key using my Private Key (RSA)
    final rsaEncrypter = encrypt.Encrypter(encrypt.RSA(privateKey: privateKey));
    final decryptedAesKeyBase64 = rsaEncrypter.decrypt64(encryptedKeyBase64);
    final aesKey = encrypt.Key.fromBase64(decryptedAesKeyBase64);

    // 3. Decrypt Content using AES Key
    final iv = encrypt.IV.fromBase64(ivBase64);
    final aesEncrypter = encrypt.Encrypter(encrypt.AES(aesKey));

    return aesEncrypter.decrypt64(encryptedContentBase64, iv: iv);
  }
}
