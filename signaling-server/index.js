const WebSocket = require("ws");
const { randomUUID } = require("crypto");

const PORT = process.env.PORT || 9090;

const wss = new WebSocket.Server({ port: PORT });

const rooms = {};

console.log(`🚀 Signaling server running on port ${PORT}`);

// ================= HEARTBEAT =================

function heartbeat() {
  this.isAlive = true;
}

const interval = setInterval(() => {
  wss.clients.forEach((ws) => {
    if (ws.isAlive === false) {
      console.log("💀 Removing dead websocket");
      return ws.terminate();
    }

    ws.isAlive = false;
    ws.ping();
  });
}, 30000);

// ================= CONNECTION =================

wss.on("connection", (ws) => {
  console.log("🔗 New client connected");

  ws.isAlive = true;
  ws.on("pong", heartbeat);

  // ================= MESSAGE =================

  ws.on("message", (message) => {
    try {
      const data = JSON.parse(message);

      const { type, roomId, payload } = data;

      console.log(
        `📨 Received: ${type} | Room: ${roomId || "none"}`
      );

      // ================= JOIN ROOM =================

      if (type === "join") {
        if (!roomId) return;

        if (!rooms[roomId]) {
          rooms[roomId] = { peers: [], sessionId: null };
        }
        const room = rooms[roomId];
        ws.userId = data.userId;

        // One active device per prototype identity. Replace a stale socket
        // when that participant reconnects instead of leaving the room full.
        for (const previous of room.peers) {
          if (previous !== ws && previous.userId === ws.userId) {
            room.peers = room.peers.filter((peer) => peer !== previous);
            previous.replaced = true;
            previous.close();
          }
        }

        // Remove dead sockets first
        room.peers = room.peers.filter(
          (client) =>
            client.readyState === WebSocket.OPEN
        );

        // Room limit = 2 users
        if (room.peers.length >= 2 && !room.peers.includes(ws)) {
          console.log(
            `⚠️ Room ${roomId} already full`
          );

          ws.send(
            JSON.stringify({
              type: "room_full",
              payload: {},
            })
          );

          return;
        }

        if (!room.peers.includes(ws)) {
          room.peers.push(ws);
        }

        ws.roomId = roomId;

        console.log(
          `👤 ${ws.userId || "client"} joined room ${roomId} | Count: ${room.peers.length}`
        );

        // Room ready when exactly 2 peers
        if (room.peers.length === 2) {
          console.log(`✅ Room ${roomId} is READY`);
          room.sessionId = randomUUID();
          room.peers.forEach((client) => {
            if (
              client.readyState === WebSocket.OPEN
            ) {
              client.send(
                JSON.stringify({
                  type: "ready",
                  payload: {
                    sessionId: room.sessionId,
                    participants: room.peers.map((peer) => peer.userId),
                  },
                })
              );
            }
          });
        }

        return;
      }

      // ================= RELAY =================

      if (
        ["offer", "answer", "ice", "key_hello"].includes(type)
      ) {
        const room = rooms[roomId];
        if (!room || !data.sessionId || data.sessionId !== room.sessionId) return;
        const peers = room.peers;

        console.log(
          `🔄 Relaying ${type} to ${
            Math.max(peers.length - 1, 0)
          } peer(s)`
        );

        peers.forEach((client) => {
          if (
            client !== ws &&
            client.readyState === WebSocket.OPEN
          ) {
            client.send(
              JSON.stringify({
                type,
                payload,
                  sessionId: data.sessionId,
              })
            );
          }
        });

        return;
      }
    } catch (e) {
      console.error(
        "❌ Message parsing error:",
        e
      );
    }
  });

  // ================= DISCONNECT =================

  ws.on("close", () => {
    console.log("🔌 Client disconnected");

    const roomId = ws.roomId;

    if (!roomId || !rooms[roomId]) {
      return;
    }

    const room = rooms[roomId];
    room.peers = room.peers.filter(
      (client) => client !== ws
    );
    if (!ws.replaced) room.sessionId = null;

    console.log(
      `🚪 ${ws.userId || "client"} left room ${roomId} | Remaining: ${room.peers.length}`
    );

    if (!ws.replaced) {
      room.peers.forEach((client) => {
        if (client.readyState === WebSocket.OPEN) {
          client.send(JSON.stringify({ type: "peer_left", payload: { userId: ws.userId } }));
        }
      });
    }

    if (room.peers.length === 0) {
      delete rooms[roomId];

      console.log(
        `🗑️ Deleted empty room ${roomId}`
      );
    }
  });

  // ================= ERROR =================

  ws.on("error", (err) => {
    console.error(
      "❌ WebSocket error:",
      err
    );
  });
});

// ================= SERVER SHUTDOWN =================

wss.on("close", () => {
  clearInterval(interval);
});
