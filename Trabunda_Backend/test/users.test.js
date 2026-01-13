const request = require("supertest");
const jwt = require("jsonwebtoken");

jest.mock("../src/db", () => ({
  pool: {
    query: jest.fn(),
    getConnection: jest.fn(),
  },
}));

const { pool } = require("../src/db");

beforeAll(() => {
  process.env.JWT_SECRET = "test-secret";
  process.env.NODE_ENV = "test";
});

afterEach(() => {
  // Limpieza de fixtures simulados para evitar contaminación entre pruebas.
  pool.query.mockReset();
});

describe("Users routes", () => {
  test("GET /users/pickers requiere token", async () => {
    const app = require("../src/index");

    const response = await request(app).get("/users/pickers");

    expect(response.status).toBe(401);
  });

  test("GET /users/pickers permite acceso con rol ADMINISTRADOR", async () => {
    const token = jwt.sign(
      { sub: 10, username: "admin", roles: ["ADMINISTRADOR"] },
      process.env.JWT_SECRET,
      { expiresIn: "1h" }
    );

    // Fixture: usuarios con los roles solicitados.
    pool.query.mockResolvedValueOnce([
      [
        { id: 11, nombre: "Ana Planillera", role: "PLANILLERO" },
        { id: 12, nombre: "Luis Saneamiento", role: "SANEAMIENTO" },
      ],
    ]);

    const app = require("../src/index");
    const response = await request(app)
      .get("/users/pickers")
      .set("Authorization", `Bearer ${token}`);

    expect(response.status).toBe(200);
    expect(response.body).toHaveLength(2);
    expect(response.body[0].role).toBe("PLANILLERO");
  });
});
