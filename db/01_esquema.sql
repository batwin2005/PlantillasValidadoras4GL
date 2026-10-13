CREATE DATABASE banco WITH BUFFERED LOG;

CREATE TABLE cat_tipo_documento (codigo CHAR(5) PRIMARY KEY, descripcion VARCHAR(40) NOT NULL);
CREATE TABLE cat_genero (codigo CHAR(1) PRIMARY KEY, descripcion VARCHAR(20) NOT NULL);
CREATE TABLE cat_estado_civil (codigo CHAR(1) PRIMARY KEY, descripcion VARCHAR(20) NOT NULL);
CREATE TABLE cat_moneda (codigo CHAR(3) PRIMARY KEY, descripcion VARCHAR(30) NOT NULL, simbolo CHAR(3));
CREATE TABLE cat_tipo_cuenta (codigo CHAR(10) PRIMARY KEY, descripcion VARCHAR(40) NOT NULL);
CREATE TABLE cat_ciudad (codigo CHAR(5) PRIMARY KEY, descripcion VARCHAR(50) NOT NULL, pais CHAR(3) DEFAULT 'ARG');

CREATE TABLE banco_cliente (
    cliente_id SERIAL PRIMARY KEY,
    tipo_doc CHAR(5) NOT NULL REFERENCES cat_tipo_documento(codigo),
    num_doc VARCHAR(20) NOT NULL UNIQUE,
    apellidos VARCHAR(60) NOT NULL,
    nombres VARCHAR(60) NOT NULL,
    genero CHAR(1) NOT NULL REFERENCES cat_genero(codigo),
    fecha_nac DATE NOT NULL,
    anio_emision SMALLINT NOT NULL,
    telefono VARCHAR(20),
    celular VARCHAR(20),
    email VARCHAR(100) UNIQUE,
    estado_civil CHAR(1) REFERENCES cat_estado_civil(codigo),
    direccion VARCHAR(120),
    ciudad CHAR(5) REFERENCES cat_ciudad(codigo),
    pais CHAR(3) DEFAULT 'ARG',
    ocupacion VARCHAR(60),
    fecha_reg DATE DEFAULT TODAY,
    usuario_reg VARCHAR(30) DEFAULT USER
);

CREATE TABLE banco_cuenta (
    cuenta_id SERIAL PRIMARY KEY,
    cliente_id INTEGER NOT NULL REFERENCES banco_cliente(cliente_id),
    num_cuenta VARCHAR(25) NOT NULL UNIQUE,
    tipo_cuenta CHAR(10) NOT NULL REFERENCES cat_tipo_cuenta(codigo),
    moneda CHAR(3) NOT NULL REFERENCES cat_moneda(codigo),
    saldo DECIMAL(16,2) DEFAULT 0.00,
    fecha_apertura DATE DEFAULT TODAY,
    estado CHAR(1) DEFAULT 'A' CHECK (estado IN ('A','C','B'))
);

CREATE TABLE banco_movimiento (
    mov_id SERIAL PRIMARY KEY,
    cuenta_id INTEGER NOT NULL REFERENCES banco_cuenta(cuenta_id),
    fecha DATETIME YEAR TO SECOND DEFAULT CURRENT YEAR TO SECOND,
    tipo CHAR(1) NOT NULL CHECK (tipo IN ('D','C')),
    concepto VARCHAR(80),
    monto DECIMAL(16,2) NOT NULL,
    saldo_post DECIMAL(16,2) NOT NULL
);

CREATE VIEW vw_cliente_cuenta AS
SELECT c.cliente_id, c.tipo_doc, c.num_doc, c.apellidos, c.nombres,
       c.genero, c.fecha_nac, c.anio_emision, c.telefono, c.celular,
       c.email, c.estado_civil, c.direccion, c.ciudad, c.ocupacion,
       cu.cuenta_id, cu.num_cuenta, cu.tipo_cuenta, cu.moneda, cu.saldo,
       cu.fecha_apertura, cu.estado
FROM banco_cliente c
JOIN banco_cuenta cu ON cu.cliente_id = c.cliente_id;

CREATE TABLE cfg_plantilla (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(40) NOT NULL,
    hoja VARCHAR(40),
    columna_excel VARCHAR(5),
    encabezado VARCHAR(60) NOT NULL,
    campo_bd VARCHAR(60) NOT NULL,
    validador VARCHAR(30),
    obligatorio CHAR(1) DEFAULT 'N' CHECK (obligatorio IN ('S','N'))
);

-- NOTA: no hace falta crear índice sobre banco_cliente(num_doc) ni
-- banco_cuenta(cliente_id): el UNIQUE y las claves foráneas ya crean
-- índices implícitos (crear otro equivalente da error -350).
CREATE INDEX ix_banco_mov_cuenta_fecha ON banco_movimiento(cuenta_id, fecha);
