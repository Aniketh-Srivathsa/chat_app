import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Ephemeral, authenticated key exchange for a single peer-to-peer chat.
/// The peer identity is trusted only after the users compare and accept the
/// displayed safety code out of band.
class SecureSessionService {
  static const _storage = FlutterSecureStorage();
  static final _ed25519 = Ed25519();
  static final _x25519 = X25519();
  static final _aes = AesGcm.with256bits();
  static final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 64);

  final String conversationId;
  final String sessionId;
  final String localUserId;
  final String peerUserId;
  SimpleKeyPair? _identity;
  SimpleKeyPair? _ephemeral;
  SecretKey? _sendKey;
  SecretKey? _receiveKey;
  String? _peerIdentity;
  String? peerSafetyCode;
  bool peerTrusted = false;

  SecureSessionService({
    required this.conversationId,
    required this.sessionId,
    required this.localUserId,
    required this.peerUserId,
  });

  bool get hasSession => _sendKey != null && _receiveKey != null;

  Future<void> initialize() async {
    final storageKey = 'identity-seed:$localUserId';
    final encoded = await _storage.read(key: storageKey);
    final seed = encoded == null ? null : base64Decode(encoded);
    _identity = seed == null
        ? await _ed25519.newKeyPair()
        : await _ed25519.newKeyPairFromSeed(seed);
    if (seed == null) {
      await _storage.write(
        key: storageKey,
        value: base64Encode(await _identity!.extractPrivateKeyBytes()),
      );
    }
    _ephemeral = await _x25519.newKeyPair();
  }

  Future<Map<String, dynamic>> createHello() async {
    if (_identity == null || _ephemeral == null) {
      throw StateError('Secure session is not initialized');
    }
    final identityPublic = await _identity!.extractPublicKey();
    final ephemeralPublic = await _ephemeral!.extractPublicKey();
    final unsigned = <String, dynamic>{
      'conversationId': conversationId,
      'sessionId': sessionId,
      'from': localUserId,
      'to': peerUserId,
      'identityKey': base64Encode(identityPublic.bytes),
      'ephemeralKey': base64Encode(ephemeralPublic.bytes),
    };
    final signature = await _ed25519.sign(
      utf8.encode(_canonical(unsigned)),
      keyPair: _identity!,
    );
    return {...unsigned, 'signature': base64Encode(signature.bytes)};
  }

  Future<String> acceptHello(Map<String, dynamic> hello) async {
    if (_identity == null || _ephemeral == null) {
      throw StateError('Secure session is not initialized');
    }
    if (hello['conversationId'] != conversationId ||
        hello['sessionId'] != sessionId ||
        hello['from'] != peerUserId ||
        hello['to'] != localUserId) {
      throw const FormatException('Key exchange does not match this chat');
    }

    final identityBytes = base64Decode(hello['identityKey'] as String);
    final encodedIdentity = base64Encode(identityBytes);
    final trustKey = 'trusted-peer:$localUserId:$peerUserId';
    final previouslyTrusted = await _storage.read(key: trustKey);
    if (previouslyTrusted != null && previouslyTrusted != encodedIdentity) {
      throw const FormatException(
          'Peer identity changed; verification required');
    }

    final unsigned = <String, dynamic>{
      'conversationId': hello['conversationId'],
      'sessionId': hello['sessionId'],
      'from': hello['from'],
      'to': hello['to'],
      'identityKey': hello['identityKey'],
      'ephemeralKey': hello['ephemeralKey'],
    };
    final identityPublic =
        SimplePublicKey(identityBytes, type: KeyPairType.ed25519);
    final signature = Signature(
      base64Decode(hello['signature'] as String),
      publicKey: identityPublic,
    );
    final valid = await _ed25519.verify(
      utf8.encode(_canonical(unsigned)),
      signature: signature,
    );
    if (!valid) throw const FormatException('Invalid peer identity signature');

    final remoteEphemeral = SimplePublicKey(
      base64Decode(hello['ephemeralKey'] as String),
      type: KeyPairType.x25519,
    );
    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: _ephemeral!,
      remotePublicKey: remoteEphemeral,
    );
    final localEphemeral = await _ephemeral!.extractPublicKey();
    final sortedEphemeral = [
      base64Encode(localEphemeral.bytes),
      hello['ephemeralKey'] as String
    ]..sort();
    final keyMaterial = await _hkdf.deriveKey(
      secretKey: sharedSecret,
      nonce: utf8.encode(conversationId),
      info: utf8.encode(
          'couple-chat-session-v1|$sessionId|${sortedEphemeral.join('|')}'),
    );
    final material = await keyMaterial.extractBytes();
    final orderedUsers = [localUserId, peerUserId]..sort();
    final firstDirection = material.sublist(0, 32);
    final secondDirection = material.sublist(32, 64);
    _sendKey = SecretKey(
        orderedUsers.first == localUserId ? firstDirection : secondDirection);
    _receiveKey = SecretKey(
        orderedUsers.first == localUserId ? secondDirection : firstDirection);

    _peerIdentity = encodedIdentity;
    peerTrusted = previouslyTrusted == encodedIdentity;
    peerSafetyCode =
        await _safetyCode(identityBytes, await _identity!.extractPublicKey());
    return peerSafetyCode!;
  }

  Future<void> trustPeer() async {
    final identity = _peerIdentity;
    if (identity == null) {
      throw StateError('Peer identity has not been exchanged');
    }
    await _storage.write(
      key: 'trusted-peer:$localUserId:$peerUserId',
      value: identity,
    );
    peerTrusted = true;
  }

  Future<String> encrypt(String plaintext) async {
    final key = _sendKey;
    if (key == null || !peerTrusted) {
      throw StateError('Secure peer is not verified');
    }
    final box = await _aes.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
      aad: utf8.encode('$conversationId|$localUserId|$peerUserId'),
    );
    return jsonEncode({
      'nonce': base64Encode(box.nonce),
      'cipherText': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    });
  }

  Future<String> decrypt(String encoded) async {
    final key = _receiveKey;
    if (key == null || !peerTrusted) {
      throw StateError('Secure peer is not verified');
    }
    final box = jsonDecode(encoded) as Map<String, dynamic>;
    final plaintext = await _aes.decrypt(
      SecretBox(
        base64Decode(box['cipherText'] as String),
        nonce: base64Decode(box['nonce'] as String),
        mac: Mac(base64Decode(box['mac'] as String)),
      ),
      secretKey: key,
      aad: utf8.encode('$conversationId|$peerUserId|$localUserId'),
    );
    return utf8.decode(plaintext);
  }

  static String _canonical(Map<String, dynamic> value) => jsonEncode(value);

  Future<String> _safetyCode(
      List<int> remoteIdentity, SimplePublicKey localIdentity) async {
    final pair = [
      base64Encode(remoteIdentity),
      base64Encode(localIdentity.bytes)
    ]..sort();
    final digest =
        await Sha256().hash(utf8.encode('$conversationId|${pair.join('|')}'));
    return digest.bytes
        .take(20)
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
  }
}
