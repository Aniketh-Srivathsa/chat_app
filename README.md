# P2P Real-Time Chat App

> A peer-to-peer real-time messaging application built with **Flutter and WebRTC**, using a lightweight **WebSocket signaling server** to establish connections between devices.

This project explores **real-time communication, peer-to-peer networking, WebRTC signaling, and cross-platform Flutter development**.

---

## 🚀 Features

- 💬 Real-time peer-to-peer messaging
- 🔗 WebRTC-based communication
- ⚡ WebSocket-based signaling
- 📱 Android ↔ Android communication
- 🖥️ Android ↔ Windows communication
- 🔄 Connection and reconnection handling
- 🌐 Cross-platform Flutter application
- 🔐 Peer-to-peer communication after connection establishment

---

## 🏗️ Architecture

```text
             ┌──────────────────────┐
             │   Flutter Client A   │
             │      (Android)       │
             └──────────┬───────────┘
                        │
                        │ WebSocket
                        ▼
             ┌──────────────────────┐
             │   Signaling Server   │
             │      (Node.js)       │
             └──────────┬───────────┘
                        │
                        │ WebSocket
                        ▼
             ┌──────────────────────┐
             │   Flutter Client B   │
             │  (Android / Windows) │
             └──────────────────────┘

    After connection establishment:

   Client A ◄──── WebRTC P2P ────► Client B
```

The signaling server is responsible for exchanging the information required to establish the WebRTC connection.

Once the peer connection is established, communication takes place directly between the connected clients.

---

## 🛠️ Tech Stack

### Frontend

- **Flutter**
- **Dart**

### Real-Time Communication

- **WebRTC**
- **WebSockets**

### Signaling Server

- **Node.js**
- **ws** WebSocket library

### Networking

- **WebRTC ICE**
- **STUN servers**

### Deployment

- **Render**

---

## 📂 Project Structure

```text
chat_app/
│
├── lib/
│   └── ...
│
├── assets/
├── android/
├── windows/
├── pubspec.yaml
└── README.md
```

> The project structure may evolve as development continues.

---

## ⚙️ Getting Started

### Prerequisites

Make sure you have the following installed:

- Flutter SDK
- Dart SDK
- Android Studio / Android SDK
- Git

Verify your Flutter installation:

```bash
flutter doctor
```

### 1. Clone the Repository

```bash
git clone https://github.com/Aniketh-Srivathsa/chat_app.git
cd chat_app
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Run the Application

For Android:

```bash
flutter run
```

For Windows:

```bash
flutter run -d windows
```

---

## 🌐 Signaling Server

The application uses a WebSocket signaling server to exchange the information required for establishing a WebRTC peer connection.

The signaling server is built using:

- Node.js
- `ws` WebSocket library

The server is deployed using **Render**.

The signaling server is responsible for:

- Establishing communication between peers
- Exchanging WebRTC offers
- Exchanging WebRTC answers
- Relaying ICE candidates

Once the WebRTC peer connection is established, messages are exchanged directly between the connected clients.

---

## 🔌 How WebRTC Connection Works

The connection follows a typical WebRTC signaling flow:

```text
Client A
   │
   │ Create Offer
   ▼
Signaling Server
   │
   │ Forward Offer
   ▼
Client B
   │
   │ Create Answer
   ▼
Signaling Server
   │
   │ Forward Answer
   ▼
Client A
   │
   │ ICE Candidate Exchange
   ▼
WebRTC Connection
   │
   ▼
P2P Communication
```

### Connection Process

1. Client A creates a WebRTC offer.
2. The offer is sent to the signaling server.
3. The signaling server forwards the offer to Client B.
4. Client B creates an answer.
5. The answer is sent back through the signaling server.
6. ICE candidates are exchanged between the clients.
7. A WebRTC peer connection is established.
8. Messages can then be exchanged through the peer connection.

STUN servers are used to assist WebRTC in discovering suitable network addresses during connection establishment.

---

## 🧪 Tested Communication

The application has been tested across the following environments:

|   Connection      |   Status   |
|-------------------|------------|
| Android ↔ Android | ✅ Tested |
| Android ↔ Windows | ✅ Tested |

Connection and reconnection behavior have also been tested during development.

---

## 🗺️ Roadmap

The project is being developed incrementally.

### v0.2.0 — WebRTC

- [x] WebRTC connection
- [x] WebSocket signaling
- [x] Android ↔ Android communication
- [x] Android ↔ Windows communication
- [x] Connection recovery

### v0.3.0 — Profiles & Contacts

- [ ] User profiles
- [ ] Contact management
- [ ] Improved chat UI

### v0.4.0 — Persistent Chat

- [ ] Local message storage
- [ ] Hive integration
- [ ] Persistent chat history

### v0.5.0 — Presence & Messaging Features

- [ ] Online/offline presence
- [ ] Typing indicators
- [ ] Read receipts

### v0.6.0 — Media Sharing

- [ ] Image sharing
- [ ] File sharing
- [ ] Media transfer over WebRTC

---

## 🎯 What I Learned

Working on this project helped me explore and understand:

- WebRTC peer-to-peer communication
- WebSocket signaling
- WebRTC offer/answer exchange
- ICE candidate exchange
- STUN servers
- Real-time application architecture
- Connection and reconnection handling
- Cross-platform Flutter development
- Debugging network communication across multiple devices

---

## 📌 Current Status

**Version:** `v0.2.0`

The core peer-to-peer messaging functionality is working and has been validated across Android and Windows environments.

The project is currently being extended toward:

- User profiles
- Contact management
- Persistent chat history
- Presence indicators
- Typing indicators
- Read receipts
- Media sharing

---

## 👨‍💻 Author

**Aniketh Srivathsa**

Computer Science Engineering Student

**Interests:**  
Software Development • AI/ML • Full-Stack Development • Problem Solving

-----
