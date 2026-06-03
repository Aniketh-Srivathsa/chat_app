const WebSocket = require("ws");

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
          rooms[roomId] = [];
        }

        // Remove dead sockets first
        rooms[roomId] = rooms[roomId].filter(
          (client) =>
            client.readyState === WebSocket.OPEN
        );

        // Room limit = 2 users
        if (rooms[roomId].length >= 2) {
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

        if (!rooms[roomId].includes(ws)) {
          rooms[roomId].push(ws);
        }

        ws.roomId = roomId;

        console.log(
          `👤 Client joined room ${roomId} | Count: ${rooms[roomId].length}`
        );

        // Room ready when exactly 2 peers
        if (rooms[roomId].length === 2) {
          console.log(`✅ Room ${roomId} is READY`);

          rooms[roomId].forEach((client) => {
            if (
              client.readyState === WebSocket.OPEN
            ) {
              client.send(
                JSON.stringify({
                  type: "ready",
                  payload: {},
                })
              );
            }
          });
        }

        return;
      }

      // ================= RELAY =================

      if (
        ["offer", "answer", "ice"].includes(type)
      ) {
        const peers = rooms[roomId] || [];

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

    rooms[roomId] = rooms[roomId].filter(
      (client) => client !== ws
    );

    console.log(
      `🚪 Client left room ${roomId} | Remaining: ${rooms[roomId].length}`
    );

    if (rooms[roomId].length === 0) {
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