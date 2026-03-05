use trabunda_prod;

-- Ver solo trabajadores inactivos
SELECT codigo, nombre_completo, dni
FROM trabajadores
WHERE activo = 0;

-- Contar cuantos mujeres y hombres existen
SELECT sexo, COUNT(*) as cantidad
FROM trabajadores
GROUP BY sexo;

-- Listar trabajadores creados recientemente (Para validar ingresos de la ultima semana)
SELECT * FROM trabajadores
WHERE creado_en >= DATE_SUB(NOW(), INTERVAL 7 DAY);

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

-- Filtrar que turnos se estan registrando mas reportes
SELECT 
    turno, 
    COUNT(*) AS cantidad_reportes,
    AVG(CASE WHEN tipo_reporte = 'TRABAJO_AVANCE' THEN 1 ELSE 0 END) as frecuencia_avance
FROM reportes
GROUP BY turno;

-- Verificar que reportes han sido cerrados a tiempo 
SELECT 
    creado_por_nombre, 
    fecha, 
    vence_en, 
    cerrado_en,
    TIMEDIFF(cerrado_en, vence_en) AS retraso
FROM reportes
WHERE estado = 'CERRADO' AND cerrado_en > vence_en;

-- Verificar que usuarios han estado activos recientemente en el sistema
SELECT 
    u.nombre, 
    rt.last_used_at, 
    rt.expires_at
FROM users u
JOIN refresh_tokens rt ON u.id = rt.user_id
WHERE rt.revoked_at IS NULL
ORDER BY rt.last_used_at DESC;

-- Verificar el tiempo de trabajo de los trabajadores , por ahora se coloca 8 horas
SELECT 
    trabajador_nombre, 
    fecha, 
    SUM(horas) AS total_dia
FROM lineas_reporte lr
JOIN reportes r ON lr.reporte_id = r.id
GROUP BY trabajador_nombre, fecha
HAVING total_dia > 8;


-- Verificar que areas necesita mas apoyos 
SELECT 
    area_nombre, 
    COUNT(*) AS veces_solicitado,
    SUM(horas) AS total_horas_apoyo
FROM lineas_reporte
WHERE area_nombre IS NOT NULL
GROUP BY area_nombre
ORDER BY total_horas_apoyo DESC;


-- Resumen de conteo rapido por dia
SELECT 
    a.nombre AS nombre_area, 
    SUM(crd.cantidad) AS total_unidades
FROM conteo_rapido_detalle crd
JOIN areas a ON crd.area_id = a.id
JOIN reportes r ON crd.reporte_id = r.id
WHERE r.fecha = '2026-03-03'
GROUP BY a.nombre
ORDER BY total_unidades DESC;

-- Para detectar si hay trabajadores que tienen reportes de horas pero no tienen registros de producción (o viceversa)
SELECT 
    t.nombre_completo, 
    r.fecha,
    lr.horas AS horas_pagadas,
    IFNULL(SUM(tat.kg), 0) AS kilos_producidos
FROM trabajadores t
JOIN lineas_reporte lr ON t.codigo = lr.trabajador_codigo
JOIN reportes r ON lr.reporte_id = r.id
LEFT JOIN trabajo_avance_trabajadores tat ON t.codigo = tat.trabajador_codigo
GROUP BY t.nombre_completo, r.fecha, lr.horas
HAVING kilos_producidos = 0 AND horas_pagadas > 0;

-- Ver el flujo de Conteo rapido para el tiurnjo dia y noche
SELECT 
    r.fecha,
    r.turno,
    a.nombre AS area,
    SUM(crd.cantidad) AS cantidad_total
FROM reportes r
JOIN conteo_rapido_detalle crd ON r.id = crd.reporte_id
JOIN areas a ON crd.area_id = a.id
WHERE r.tipo_reporte = 'CONTEO_RAPIDO'
GROUP BY r.fecha, r.turno, a.nombre
ORDER BY r.fecha DESC, r.turno ASC;


-- Ver el tiempo de tiempo que le quedan a los tokens para expirar
SELECT 
    u.nombre, 
    rt.created_at AS inicio_sesion,
    rt.expires_at AS expira_en,
    TIMESTAMPDIFF(HOUR, NOW(), rt.expires_at) AS horas_restantes
FROM users u
JOIN refresh_tokens rt ON u.id = rt.user_id
WHERE rt.revoked_at IS NULL 
  AND rt.expires_at > NOW()
ORDER BY expira_en ASC;