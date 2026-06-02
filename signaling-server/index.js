const WebSocket = require("ws");

const PORT = process.env.PORT || 9090;
const wss = new WebSocket.Server({ port: PORT });

const rooms = {}; // roomId -> [client1, client2]

wss.on("connection", (ws) => {
  ws.on("message", (message) => {
    const data = JSON.parse(message);

    const { type, roomId, payload } = data;

    // Join room
    if (type === "join") {
      if (!rooms[roomId]) rooms[roomId] = [];
      rooms[roomId].push(ws);
      ws.roomId = roomId;

      console.log(`Client joined room: ${roomId}`);

      if (rooms[roomId].length === 2) {
        rooms[roomId].forEach((client) => {
          client.send(JSON.stringify({ type: "ready" }));
        });
      }
    }

    // Relay signaling messages
    if (["offer", "answer", "ice"].includes(type)) {
      const peers = rooms[roomId] || [];
      peers.forEach((client) => {
        if (client !== ws && client.readyState === WebSocket.OPEN) {
          client.send(JSON.stringify({ type, payload }));
        }
      });
    }
  });

  ws.on("close", () => {
    const roomId = ws.roomId;
    if (!roomId) return;

    rooms[roomId] = rooms[roomId].filter((client) => client !== ws);

    if (rooms[roomId].length === 0) {
      delete rooms[roomId];
    }

    console.log(`Client left room: ${roomId}`);
  });
});

console.log(`🚀 Signaling server running on port ${PORT}`);