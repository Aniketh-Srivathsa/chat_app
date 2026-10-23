# Couple Chat

Flutter peer-to-peer, one-to-one chat prototype for three local test identities: A, B, and C.

## Current design

- Each pair has a distinct direct conversation ID, such as `direct:A:C`.
- The Node WebSocket server keeps presence for a pair, relays WebRTC setup messages and public key-exchange messages, and creates a new session ID when both participants are present.
- Chat text is encrypted on the sender with a per-session AES-256-GCM key, sent as ciphertext over the WebRTC data channel, and decrypted on the receiver.
- Sent and received text is saved in an encrypted local Hive store and restored when the same identity reopens that conversation on the same device. The local history key is stored in platform secure storage.
- A persistent Ed25519 identity signs a fresh X25519 ephemeral key for each connection session. The shared secret is expanded into separate send and receive keys with HKDF-SHA256.
- The app displays a safety code derived from the two identity public keys. Each user must compare the code with their peer through a trusted channel and approve it before messages are sent or received. Trusted peer keys are stored locally.
- When a peer leaves, the server notifies the remaining participant. Signaling reconnects with backoff; when both peers are present again, the server issues a new session ID and both clients create a new WebRTC connection and exchange fresh ephemeral keys.

## Run locally

Start signaling from `signaling-server/` with `npm start`. The Flutter app currently points at the deployed signaling URL in `lib/core/app_config.dart`; change that value to your development server address when testing locally. Open the app on two devices, choose different identities, and open the same conversation. For example, A and C both open A ↔ C.

## Prototype boundaries

A/B/C are client-selected labels, not authenticated accounts. This prototype has no registration, trusted identity directory, offline delivery, cloud history sync, group chat, or per-message Double Ratchet. Conversation history is only available on the device that stored it; losing the platform secure-storage key makes that history unreadable. Its session keys are fresh on each connection, and manual safety-code comparison is required to defend the first identity exchange against a malicious signaling service. Do not describe this prototype as production-ready or equivalent to Signal/WhatsApp security without a protocol review and further hardening.
