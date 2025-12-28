import 'package:encrypt/encrypt.dart';

class EncryptionHelper {
  // 32 bytes = AES-256
  static final _key = Key.fromUtf8(
    '12345678901234567890123456789012',
  );

  // 16 bytes IV — MUST be explicit & identical on both devices
  static final _iv = IV.fromUtf8(
    '1234567890123456',
  );

  static final _encrypter = Encrypter(
    AES(_key, mode: AESMode.cbc),
  );

  static String encryptText(String plainText) {
    return _encrypter.encrypt(plainText, iv: _iv).base64;
  }

  static String decryptText(String encryptedText) {
    return _encrypter.decrypt64(encryptedText, iv: _iv);
  }
}
