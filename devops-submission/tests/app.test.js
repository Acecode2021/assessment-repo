const request = require("supertest");
const app = require("../src/app");

describe("LocalBuka API", () => {
  test("GET /health returns ok", async () => {
    const res = await request(app).get("/health");

    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe("ok");
    expect(res.body.service).toBe("localbuka-api");
  });

  test("GET /api/v1/bukas returns a list", async () => {
    const res = await request(app).get("/api/v1/bukas");

    expect(res.statusCode).toBe(200);
    expect(Array.isArray(res.body.data)).toBe(true);
    expect(res.body.data.length).toBeGreaterThan(0);
  });

  test("GET /api/v1/bukas/:id returns one buka", async () => {
    const res = await request(app).get("/api/v1/bukas/1");

    expect(res.statusCode).toBe(200);
    expect(res.body.data.id).toBe(1);
    expect(res.body.data.name).toBe("Mama Ngozi Kitchen");
  });

  test("GET /api/v1/bukas/:id returns 404 for missing buka", async () => {
    const res = await request(app).get("/api/v1/bukas/999");

    expect(res.statusCode).toBe(404);
    expect(res.body.error).toBe("Buka not found");
  });

  test("Unknown route returns 404", async () => {
    const res = await request(app).get("/not-a-real-route");

    expect(res.statusCode).toBe(404);
    expect(res.body.error).toBe("Route not found");
  });
});