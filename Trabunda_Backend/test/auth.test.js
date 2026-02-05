const request = require("supertest"); // permite hacer request http falsas con la app sin levantas puertos
const jwt = require("jsonwebtoken");
const bcrypt = require("bcryptjs");

jest.mock("../src/db", () => ({
  pool: {
    query: jest.fn(),
    getConnection: jest.fn(),
  },
}));

const { pool } = require("../src/db");

beforeAll(() => {
  process.env.JWT_SECRET = "test-secret";
  process.env.JWT_EXPIRES_IN = "1h";
  process.env.NODE_ENV = "test";
});

afterEach(() => {
  // Limpieza de fixtures simulados: restablecemos los mocks para evitar fugas entre tests.
  pool.query.mockReset();
  pool.getConnection.mockReset();
});

describe("Auth routes", () => {
  test("POST /auth/login devuelve token y refresh token con credenciales correctas", async () => {
    const passwordHash = await bcrypt.hash("correct-password", 10);

    // Fixture de datos: usuario activo + roles + inserción de refresh token.
    pool.query
      .mockResolvedValueOnce([
        [
          {
            id: 1,
            username: "demo",
            password_hash: passwordHash,
            nombre: "Demo User",
            activo: 1,
          },
        ],
      ])
      .mockResolvedValueOnce([[{ codigo: "ADMINISTRADOR" }]])
      .mockResolvedValueOnce([{}]);

    const app = require("../src/index");
    const response = await request(app)
      .post("/auth/login")
      .send({ username: "demo", password: "correct-password" });

    expect(response.status).toBe(200);
    expect(response.body.token).toBeTruthy();
    expect(response.body.refreshToken).toBeTruthy();

    const payload = jwt.verify(response.body.token, process.env.JWT_SECRET);
    expect(payload.username).toBe("demo");
    expect(payload.roles).toContain("ADMINISTRADOR");
  });

  test("POST /auth/login rechaza credenciales incorrectas", async () => {
    const passwordHash = await bcrypt.hash("correct-password", 10);

    // Fixture: el usuario existe pero la contraseña no coincide.
    pool.query.mockResolvedValueOnce([
      [
        {
          id: 2,
          username: "demo",
          password_hash: passwordHash,
          nombre: "Demo User",
          activo: 1,
        },
      ],
    ]);

    const app = require("../src/index");
    const response = await request(app)
      .post("/auth/login")
      .send({ username: "demo", password: "wrong-password" });

    expect(response.status).toBe(401);
    expect(response.body.error).toBe("Credenciales inválidas");
  });

  test("GET /auth/me requiere token válido", async () => {
    const app = require("../src/index");

    const missingTokenResponse = await request(app).get("/auth/me");
    expect(missingTokenResponse.status).toBe(401);

    const token = jwt.sign(
      { sub: 3, username: "demo", roles: ["ADMINISTRADOR"] },
      process.env.JWT_SECRET,
      { expiresIn: "1h" }
    );

    // Fixture: datos del usuario y roles.
    pool.query
      .mockResolvedValueOnce([
        [{ id: 3, username: "demo", nombre: "Demo User" }],
      ])
      .mockResolvedValueOnce([[{ codigo: "ADMINISTRADOR" }]]);

    const okResponse = await request(app)
      .get("/auth/me")
      .set("Authorization", `Bearer ${token}`);

    expect(okResponse.status).toBe(200);
    expect(okResponse.body.user.username).toBe("demo");
  });

   test("POST /auth/register permite crear usuario con rol ADMINISTRADOR", async () => {
    const token = jwt.sign(
      { sub: 1, username: "admin", roles: ["ADMINISTRADOR"] },
      process.env.JWT_SECRET,
      { expiresIn: "1h" }
    );

    const connection = {
      beginTransaction: jest.fn().mockResolvedValue(undefined),
      query: jest
        .fn()
        .mockResolvedValueOnce([[]])
        .mockResolvedValueOnce([{ insertId: 99 }])
        .mockResolvedValueOnce([[{ id: 2 }]])
        .mockResolvedValueOnce([{}]),
      commit: jest.fn().mockResolvedValue(undefined),
      rollback: jest.fn().mockResolvedValue(undefined),
      release: jest.fn(),
    };

    pool.getConnection.mockResolvedValueOnce(connection);

    const app = require("../src/index");
    const response = await request(app)
      .post("/auth/register")
      .set("Authorization", `Bearer ${token}`)
      .send({
        username: "nuevo_user",
        password: "123456",
        nombre: "Nuevo Usuario",
        roles: ["PLANILLERO"],
      });

    expect(response.status).toBe(200);
    expect(response.body.user_id).toBe(99);
    expect(connection.beginTransaction).toHaveBeenCalled();
    expect(connection.commit).toHaveBeenCalled();
  });

  test("POST /auth/register deniega acceso a usuario sin rol ADMINISTRADOR", async () => {
    const token = jwt.sign(
      { sub: 2, username: "planillero", roles: ["PLANILLERO"] },
      process.env.JWT_SECRET,
      { expiresIn: "1h" }
    );

    const app = require("../src/index");
    const response = await request(app)
      .post("/auth/register")
      .set("Authorization", `Bearer ${token}`)
      .send({
        username: "otro_user",






        
        password: "123456",
        nombre: "Otro Usuario",
      });

    expect(response.status).toBe(403);
  });}

  
);
