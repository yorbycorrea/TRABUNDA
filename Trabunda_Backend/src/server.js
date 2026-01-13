const app = require("./index");

const PORT = process.env.PORT || 3000;

app.listen(PORT, "0.0.0.0", () => {
  //console.log(`Servidor TRABUNDA escuchando en http:// 192.168.60.102:${PORT}`);
  console.log(`Servidor TRABUNDA escuchando en http:// 172.16.1.207:${PORT}`);
});
module.exports = app;
