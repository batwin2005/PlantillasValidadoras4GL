DATABASE banco;

-- ============================================================
-- Tabla de bancos (múltiples bancos con estilos)
-- NOTA: el resto de tablas y catálogos ya las crea 01_esquema.sql.
-- Este archivo solo añade lo que falta, para poder ejecutar los dos
-- scripts en el orden documentado en README (01 -> 02 -> 03 ...).
-- ============================================================
CREATE TABLE banco (
    codigo VARCHAR(20) PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    color_hex VARCHAR(7) DEFAULT '#003366',
    logo_path VARCHAR(200),
    activo CHAR(1) DEFAULT 'S' CHECK (activo IN ('S','N'))
);
