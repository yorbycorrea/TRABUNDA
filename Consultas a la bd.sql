use trabunda_prod;
-- Listar todos los trabajadores activos
SELECT codigo, nombre_completo, dni FROM trabajadores WHERE activo = 1;

-- Ver los ultimos reportes creados
SELECT fecha, turno, tipo_reporte, estado FROM reportes ORDER BY creado_en DESC LIMIT 10;

-- Listar las areas que estan habilitadas para Apoyo por horas
SELECT nombre FROM areas WHERE es_apoyo_horas = 1 AND activo = 1;

-- Contar cuantos reportes hay por cada tipo 
SELECT tipo_reporte, COUNT(*) as total 
FROM reportes 
GROUP BY tipo_reporte;

-- Sumar el total de kilos producidos en una fecha especifica 
SELECT SUM(kilos) as total_kilos 
FROM cuadrillas 
JOIN reportes ON cuadrillas.reporte_id = reportes.id 
WHERE reportes.fecha = '2026-03-01';

-- Buscar trabajadores por nombre(buscador)
SELECT * FROM trabajadores WHERE nombre_completo LIKE '%YORBY%';

-- Reporte de Asistencia/Horas por Trabajador
SELECT L.trabajador_nombre, R.fecha, L.hora_inicio, L.hora_fin, L.horas
FROM lineas_reporte L
JOIN reportes R ON L.reporte_id = R.id
WHERE R.fecha BETWEEN '2026-03-01' AND '2026-03-02';

-- Saber que rol tiene cada usuario del sistema
SELECT U.username, R.codigo as rol
FROM users U
JOIN user_roles UR ON U.id = UR.user_id
JOIN roles R ON UR.role_id = R.id;

-- Filtrar por Usuario y por area  y por dia
SELECT lr.* FROM lineas_reporte lr JOIN reportes r ON lr.reporte_id = r.id WHERE r.fecha = '2026-03-03'   AND r.creado_por_nombre = 'Curay Floriano Luis Martin'   AND r.area = 'SANEAMIENTO';











