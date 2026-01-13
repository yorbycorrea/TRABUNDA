const request = require("supertest");
const app = require("../src/index");

describe("GET /health", () => {
  it("responde con status 200 y payload esperado", async () => {
    const response = await request(app).get("/health");

    expect(response.status).toBe(200);
    expect(response.body).toMatchObject({
      ok: true,
    });
    expect(typeof response.body.message).toBe("string");
    expect(response.body.message.length).toBeGreaterThan(0);
  });
});
