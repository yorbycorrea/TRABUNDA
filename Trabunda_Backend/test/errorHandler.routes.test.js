const request = require("supertest");

jest.mock("../src/db", () => ({
  pool: {
    query: jest.fn(),
  },
}));

const { pool } = require("../src/db");
const app = require("../src/app");

describe("errorHandler en rutas de areas", () => {
  beforeEach(() => {
    pool.query.mockReset();
  });

  it("devuelve 400 con mensaje distintivo cuando se fuerza error de parámetros", async () => {
    const error = new Error("areas-parametro-invalido-distintivo");
    error.status = 400;
    pool.query.mockRejectedValueOnce(error);

    const response = await request(app).get("/areas");

    expect(response.status).toBe(400);
    expect(response.body).toEqual({
      error: "areas-parametro-invalido-distintivo",
    });
  });

  it("devuelve 500 con prefijo de error interno cuando falla la consulta", async () => {
    pool.query.mockRejectedValueOnce(new Error("areas-falla-db-distintiva"));

    const response = await request(app).get("/areas?tipo=APOYO_HORAS");

    expect(response.status).toBe(500);
    expect(response.body).toEqual({
      error: "Error interno del servidor: areas-falla-db-distintiva",
    });
  });
});
