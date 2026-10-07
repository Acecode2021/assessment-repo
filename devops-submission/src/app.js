const express = require("express");
const bukas = require("./data/bukas");

const app = express();

app.use(express.json());

app.get("/health", (req, res) => {
  res.status(200).json({
    status: "ok",
    service: "localbuka-api",
    version: "1.0.1",
    timestamp: new Date().toISOString()
  });
});

app.get("/api/v1/bukas", (req, res) => {
  res.json({ data: bukas });
});

app.get("/api/v1/bukas/:id", (req, res) => {
  const id = Number(req.params.id);
  const buka = bukas.find((item) => item.id === id);

  if (!buka) {
    return res.status(404).json({ error: "Buka not found" });
  }

  res.json({ data: buka });
});

app.use((req, res) => {
  res.status(404).json({ error: "Route not found" });
});

module.exports = app;