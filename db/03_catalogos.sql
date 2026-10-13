DATABASE banco;

-- ============================================================
-- BANCOS COLOMBIANOS
-- ============================================================
INSERT INTO banco (codigo, nombre, color_hex) VALUES ('bancolombia', 'Bancolombia', '#003366');
INSERT INTO banco (codigo, nombre, color_hex) VALUES ('bancolombia_pymes', 'Bancolombia PyMEs', '#003366');
INSERT INTO banco (codigo, nombre, color_hex) VALUES ('davivienda', 'Davivienda', '#CC0000');
INSERT INTO banco (codigo, nombre, color_hex) VALUES ('bogota', 'Banco de Bogotá', '#003366');
INSERT INTO banco (codigo, nombre, color_hex) VALUES ('bbva', 'BBVA Colombia', '#004481');
INSERT INTO banco (codigo, nombre, color_hex) VALUES ('occidente', 'Banco de Occidente', '#0066B3');
INSERT INTO banco (codigo, nombre, color_hex) VALUES ('popular', 'Banco Popular', '#CC0000');
INSERT INTO banco (codigo, nombre, color_hex) VALUES ('avvillas', 'AV Villas', '#FF6600');
INSERT INTO banco (codigo, nombre, color_hex) VALUES ('caja_social', 'Caja Social', '#006633');
INSERT INTO banco (codigo, nombre, color_hex) VALUES ('agrario', 'Banco Agrario', '#006633');
INSERT INTO banco (codigo, nombre, color_hex) VALUES ('itau', 'Itaú Colombia', '#FF6600');
INSERT INTO banco (codigo, nombre, color_hex) VALUES ('scotiabank', 'Scotiabank Colpatria', '#FF0000');
INSERT INTO banco (codigo, nombre, color_hex) VALUES ('falabella', 'Banco Falabella', '#CC0000');
INSERT INTO banco (codigo, nombre, color_hex) VALUES ('pichincha', 'Banco Pichincha', '#003366');

-- ============================================================
-- TIPOS DE DOCUMENTO COLOMBIANOS
-- ============================================================
DELETE FROM cat_tipo_documento;
INSERT INTO cat_tipo_documento (codigo, descripcion) VALUES ('CC', 'Cédula de Ciudadanía');
INSERT INTO cat_tipo_documento (codigo, descripcion) VALUES ('CE', 'Cédula de Extranjería');
INSERT INTO cat_tipo_documento (codigo, descripcion) VALUES ('TI', 'Tarjeta de Identidad');
INSERT INTO cat_tipo_documento (codigo, descripcion) VALUES ('NIT', 'Número de Identificación Tributaria');
INSERT INTO cat_tipo_documento (codigo, descripcion) VALUES ('PA', 'Pasaporte');
INSERT INTO cat_tipo_documento (codigo, descripcion) VALUES ('RC', 'Registro Civil');
INSERT INTO cat_tipo_documento (codigo, descripcion) VALUES ('AS', 'Adulto Sin Identificación');
INSERT INTO cat_tipo_documento (codigo, descripcion) VALUES ('MS', 'Menor Sin Identificación');
INSERT INTO cat_tipo_documento (codigo, descripcion) VALUES ('NU', 'Número Único de Identificación');
INSERT INTO cat_tipo_documento (codigo, descripcion) VALUES ('CD', 'Carné Diplomático');

-- ============================================================
-- GÉNERO
-- ============================================================
DELETE FROM cat_genero;
INSERT INTO cat_genero (codigo, descripcion) VALUES ('M', 'Masculino');
INSERT INTO cat_genero (codigo, descripcion) VALUES ('F', 'Femenino');
INSERT INTO cat_genero (codigo, descripcion) VALUES ('X', 'No binario / Otro');

-- ============================================================
-- ESTADO CIVIL (COLOMBIA)
-- ============================================================
DELETE FROM cat_estado_civil;
INSERT INTO cat_estado_civil (codigo, descripcion) VALUES ('S', 'Soltero/a');
INSERT INTO cat_estado_civil (codigo, descripcion) VALUES ('C', 'Casado/a');
INSERT INTO cat_estado_civil (codigo, descripcion) VALUES ('D', 'Divorciado/a');
INSERT INTO cat_estado_civil (codigo, descripcion) VALUES ('V', 'Viudo/a');
INSERT INTO cat_estado_civil (codigo, descripcion) VALUES ('U', 'Unión Marital de Hecho');
INSERT INTO cat_estado_civil (codigo, descripcion) VALUES ('S', 'Separado/a');

-- ============================================================
-- MONEDA - COLOMBIA
-- ============================================================
DELETE FROM cat_moneda;
INSERT INTO cat_moneda (codigo, descripcion, simbolo) VALUES ('COP', 'Peso Colombiano', '$');
INSERT INTO cat_moneda (codigo, descripcion, simbolo) VALUES ('USD', 'Dólar Estadounidense', 'US$');
INSERT INTO cat_moneda (codigo, descripcion, simbolo) VALUES ('EUR', 'Euro', 'EUR');

-- ============================================================
-- TIPOS DE CUENTA COLOMBIA
-- ============================================================
DELETE FROM cat_tipo_cuenta;
INSERT INTO cat_tipo_cuenta (codigo, descripcion) VALUES ('AHO', 'Cuenta de Ahorros');
INSERT INTO cat_tipo_cuenta (codigo, descripcion) VALUES ('CTE', 'Cuenta Corriente');
INSERT INTO cat_tipo_cuenta (codigo, descripcion) VALUES ('CTA', 'Cuenta de Ahorro Programado');
INSERT INTO cat_tipo_cuenta (codigo, descripcion) VALUES ('PLA', 'CDT / Plazo Fijo');
INSERT INTO cat_tipo_cuenta (codigo, descripcion) VALUES ('INV', 'Cuenta de Inversión');
INSERT INTO cat_tipo_cuenta (codigo, descripcion) VALUES ('NOM', 'Cuenta Nómina');
INSERT INTO cat_tipo_cuenta (codigo, descripcion) VALUES ('EMP', 'Cuenta Empresarial');
INSERT INTO cat_tipo_cuenta (codigo, descripcion) VALUES ('SIM', 'Cuenta Simplificada');
INSERT INTO cat_tipo_cuenta (codigo, descripcion) VALUES ('MEN', 'Cuenta de Menores');
INSERT INTO cat_tipo_cuenta (codigo, descripcion) VALUES ('JUV', 'Cuenta Joven');

-- ============================================================
-- DEPARTAMENTOS Y CIUDADES DE COLOMBIA
-- ============================================================
DELETE FROM cat_ciudad;
-- Bogotá D.C.
INSERT INTO cat_ciudad (codigo, descripcion, pais) VALUES ('BOG', 'Bogotá D.C.', 'COL');
-- Antioquia
INSERT INTO cat_ciudad (codigo, descripcion, pais) VALUES ('MED', 'Medellín', 'COL');
INSERT INTO cat_ciudad (codigo, descripcion, pais) VALUES ('BEL', 'Bello', 'COL');
INSERT INTO cat_ciudad (codigo, descripcion, pais) VALUES ('ENV', 'Envigado', 'COL');
INSERT INTO cat_ciudad (codigo, descripcion, pais) VALUES ('ITG', 'Itagüí', 'COL');
INSERT INTO cat_ciudad (codigo, descripcion, pais) VALUES ('SAB', 'Sabaneta', 'COL');
INSERT INTO cat_ciudad (codigo, descripcion, pais) VALUES ('COP', 'Copacabana', 'COL');
INSERT INTO cat_ciudad (codigo, descripcion, pais) VALUES ('GIR', 'Girardota', 'COL');
INSERT INTO cat_ciudad (codigo, descripcion, pais) VALUES ('BAR', 'Barbosa', 'COL');
-- Valle del Cauca
INSERT INTO cat_ciudad (codigo, descripcion, pais) VALUES ('CAL', 'Cali', 'COL');
INSERT INTO cat_ciudad (codigo, descripcion, pais) VALUES ('PAL', 'Palmira', 'COL');
INSERT INTO cat_ciudad (codigo, descripcion, pais) VALUES ('BUE', 'Buenaventura', 'COL');
INSERT INTO cat_ciudad (codigo, descripcion, pais) VALUES ('TUL', 'Tuluá', 'COL');
INSERT INTO cat_ciudad (codigo, descripcion, pais) VALUES ('CART', 'Cartago', 'COL');
INSERT INTO cat_ciudad (codigo, descripcion, pais) VALUES ('YUM', 'Yumbo', 'COL');
INSERT INTO cat_ciudad (codigo, descripcion, pais) VALUES ('JAM', 'Jamundí', 'COL');
-- Atlántico
INSERT INTO cat_ciudad (codigo, descripcion, pais) VALUES ('BAQ', 'Barranquilla', 'COL');
INSERT INTO cat_ciudad (codigo, descripcion, pais) VALUES ('SOA', 'Soledad', 'COL');
INSERT INTO cat_ciudad (codigo, descripcion, pais) VALUES ('MAL', 'Malambo', 'COL');
INSERT INTO cat_ciudad (codigo, descripcion, pais) VALUES ('SAB', 'Sabanalarga', 'COL');
-- Bolívar
INSERT INTO cat_ciudad (codigo, descripcion, pais) VALUES ('CTG', 'Cartagena', 'COL');
INSERT INTO cat_ciudad (codigo, descripcion, pais) VALUES ('MAG', 'Magangué', 'COL');
INSERT INTO cat_ciudad (codigo, descripcion, pais) VALUES ('TUR', 'Turbaco', 'COL');
-- Santander
INSERT INTO cat_ciudad (codigo, descripcion, pais) VALUES ('BUC', 'Bucaramanga', 'COL');
INSERT INTO cat_ciudad (codigo, descripcion, pais) VALUES ('FLO', 'Floridablanca', 'COL');
INSERT INTO cat_ciudad (codigo, descripcion, pais) VALUES ('GIR', 'Girón', 'COL');
INSERT INTO cat_ciudad (codigo, descripcion, pais) VALUES ('PIE', 'Piedecuesta', 'COL');
-- Cundinamarca
INSERT INTO cat_ciudad (codigo, descripcion, pais) VALUES ('SOA', 'Soacha', 'COL');
INSERT INTO cat_ciudad (codigo, descripcion, pais) VALUES ('FUN', 'Funza', 'COL');
INSERT INTO cat_ciudad (codigo, descripcion, pais) VALUES ('MOS', 'Mosquera', 'COL');
INSERT INTO cat_ciudad (codigo, descripcion, pais) VALUES ('CHI', 'Chía', 'COL');
INSERT INTO cat_ciudad (codigo, descripcion, pais) VALUES ('FAC', 'Facatativá', 'COL');
INSERT INTO cat_ciudad (codigo, descripcion, pais) VALUES ('ZIP', 'Zipaquirá', 'COL');
INSERT INTO cat_ciudad (codigo, descripcion, pais) VALUES ('CHQ', 'Chiquinquirá', 'COL');
-- Eje Cafetero
INSERT INTO cat_ciudad (codigo, descripcion, pais) VALUES ('PER', 'Pereira', 'COL');
INSERT INTO cat_ciudad (codigo, descripcion, pais) VALUES ('ARM', 'Armenia', 'COL');
INSERT INTO cat_ciudad (codigo, descripcion, pais) VALUES ('MAN', 'Manizales', 'COL');
INSERT INTO cat_ciudad (codigo, descripcion, pais) VALUES ('DOS', 'Dosquebradas', 'COL');
INSERT INTO cat_ciudad (codigo, descripcion, pais) VALUES ('SAL', 'La Virginia', 'COL');
-- Otras ciudades principales
INSERT INTO cat_ciudad (codigo, descripcion, pais) VALUES ('IBG', 'Ibagué', 'COL');
INSERT INTO cat_ciudad (codigo, descripcion, pais) VALUES ('NEI', 'Neiva', 'COL');
INSERT INTO cat_ciudad (codigo, descripcion, pais) VALUES ('PAS', 'Pasto', 'COL');
INSERT INTO cat_ciudad (codigo, descripcion, pais) VALUES ('POP', 'Popayán', 'COL');
INSERT INTO cat_ciudad (codigo, descripcion, pais) VALUES ('SMR', 'Santa Marta', 'COL');
INSERT INTO cat_ciudad (codigo, descripcion, pais) VALUES ('VUP', 'Villavicencio', 'COL');
INSERT INTO cat_ciudad (codigo, descripcion, pais) VALUES ('MTR', 'Montería', 'COL');
INSERT INTO cat_ciudad (codigo, descripcion, pais) VALUES ('CTA', 'Cúcuta', 'COL');
INSERT INTO cat_ciudad (codigo, descripcion, pais) VALUES ('RIO', 'Riohacha', 'COL');
INSERT INTO cat_ciudad (codigo, descripcion, pais) VALUES ('LET', 'Leticia', 'COL');
INSERT INTO cat_ciudad (codigo, descripcion, pais) VALUES ('SJE', 'San José del Guaviare', 'COL');
INSERT INTO cat_ciudad (codigo, descripcion, pais) VALUES ('MCO', 'Mitú', 'COL');
INSERT INTO cat_ciudad (codigo, descripcion, pais) VALUES ('PUO', 'Puerto Carreño', 'COL');

-- ============================================================
-- TIPOS DE CUENTA COLOMBIA
-- ============================================================
DELETE FROM cat_tipo_cuenta;
INSERT INTO cat_tipo_cuenta (codigo, descripcion) VALUES ('AHO', 'Cuenta de Ahorros');
INSERT INTO cat_tipo_cuenta (codigo, descripcion) VALUES ('CTE', 'Cuenta Corriente');
INSERT INTO cat_tipo_cuenta (codigo, descripcion) VALUES ('CTA', 'Cuenta de Ahorro Programado');
INSERT INTO cat_tipo_cuenta (codigo, descripcion) VALUES ('PLA', 'CDT / Plazo Fijo');
INSERT INTO cat_tipo_cuenta (codigo, descripcion) VALUES ('INV', 'Cuenta de Inversión');
INSERT INTO cat_tipo_cuenta (codigo, descripcion) VALUES ('NOM', 'Cuenta Nómina');
INSERT INTO cat_tipo_cuenta (codigo, descripcion) VALUES ('EMP', 'Cuenta Empresarial');
INSERT INTO cat_tipo_cuenta (codigo, descripcion) VALUES ('SIM', 'Cuenta Simplificada');
INSERT INTO cat_tipo_cuenta (codigo, descripcion) VALUES ('MEN', 'Cuenta de Menores');
INSERT INTO cat_tipo_cuenta (codigo, descripcion) VALUES ('JUV', 'Cuenta Joven');

-- ============================================================
-- TIPOS DE DOCUMENTO COLOMBIANOS
-- ============================================================
DELETE FROM cat_tipo_documento;
INSERT INTO cat_tipo_documento (codigo, descripcion) VALUES ('CC', 'Cédula de Ciudadanía');
INSERT INTO cat_tipo_documento (codigo, descripcion) VALUES ('CE', 'Cédula de Extranjería');
INSERT INTO cat_tipo_documento (codigo, descripcion) VALUES ('TI', 'Tarjeta de Identidad');
INSERT INTO cat_tipo_documento (codigo, descripcion) VALUES ('NIT', 'Número de Identificación Tributaria');
INSERT INTO cat_tipo_documento (codigo, descripcion) VALUES ('PA', 'Pasaporte');
INSERT INTO cat_tipo_documento (codigo, descripcion) VALUES ('RC', 'Registro Civil');
INSERT INTO cat_tipo_documento (codigo, descripcion) VALUES ('AS', 'Adulto Sin Identificación');
INSERT INTO cat_tipo_documento (codigo, descripcion) VALUES ('MS', 'Menor Sin Identificación');
INSERT INTO cat_tipo_documento (codigo, descripcion) VALUES ('NU', 'Número Único de Identificación');
INSERT INTO cat_tipo_documento (codigo, descripcion) VALUES ('CD', 'Carné Diplomático');

-- ============================================================
-- GÉNERO
-- ============================================================
DELETE FROM cat_genero;
INSERT INTO cat_genero (codigo, descripcion) VALUES ('M', 'Masculino');
INSERT INTO cat_genero (codigo, descripcion) VALUES ('F', 'Femenino');
INSERT INTO cat_genero (codigo, descripcion) VALUES ('X', 'No binario / Otro');

-- ============================================================
-- ESTADO CIVIL (COLOMBIA)
-- ============================================================
DELETE FROM cat_estado_civil;
INSERT INTO cat_estado_civil (codigo, descripcion) VALUES ('S', 'Soltero/a');
INSERT INTO cat_estado_civil (codigo, descripcion) VALUES ('C', 'Casado/a');
INSERT INTO cat_estado_civil (codigo, descripcion) VALUES ('D', 'Divorciado/a');
INSERT INTO cat_estado_civil (codigo, descripcion) VALUES ('V', 'Viudo/a');
INSERT INTO cat_estado_civil (codigo, descripcion) VALUES ('U', 'Unión Marital de Hecho');
INSERT INTO cat_estado_civil (codigo, descripcion) VALUES ('S', 'Separado/a');

-- ============================================================
-- MONEDA - COLOMBIA
-- ============================================================
DELETE FROM cat_moneda;
INSERT INTO cat_moneda (codigo, descripcion, simbolo) VALUES ('COP', 'Peso Colombiano', '$');
INSERT INTO cat_moneda (codigo, descripcion, simbolo) VALUES ('USD', 'Dólar Estadounidense', 'US$');
INSERT INTO cat_moneda (codigo, descripcion, simbolo) VALUES ('EUR', 'Euro', 'EUR');

-- ============================================================
-- CONFIGURACIÓN PLANTILLA - CLIENTES COLOMBIA
-- ============================================================
DELETE FROM cfg_plantilla WHERE nombre = 'colombia_clientes';
INSERT INTO cfg_plantilla (nombre, hoja, columna_excel, encabezado, campo_bd, validador, obligatorio) VALUES ('colombia_clientes','Clientes','A','Tipo Documento','tipo_doc','tipo_doc','S');
INSERT INTO cfg_plantilla (nombre, hoja, columna_excel, encabezado, campo_bd, validador, obligatorio) VALUES ('colombia_clientes','Clientes','B','Número Documento','num_doc','documento','S');
INSERT INTO cfg_plantilla (nombre, hoja, columna_excel, encabezado, campo_bd, validador, obligatorio) VALUES ('colombia_clientes','Clientes','C','Primer Apellido','apellido1','apellido','S');
INSERT INTO cfg_plantilla (nombre, hoja, columna_excel, encabezado, campo_bd, validador, obligatorio) VALUES ('colombia_clientes','Clientes','D','Segundo Apellido','apellido2','apellido','N');
INSERT INTO cfg_plantilla (nombre, hoja, columna_excel, encabezado, campo_bd, validador, obligatorio) VALUES ('colombia_clientes','Clientes','E','Primer Nombre','nombre1','nombre','S');
INSERT INTO cfg_plantilla (nombre, hoja, columna_excel, encabezado, campo_bd, validador, obligatorio) VALUES ('colombia_clientes','Clientes','F','Segundo Nombre','nombre2','nombre','N');
INSERT INTO cfg_plantilla (nombre, hoja, columna_excel, encabezado, campo_bd, validador, obligatorio) VALUES ('colombia_clientes','Clientes','G','Fecha Nacimiento','fecha_nac','fecha','S');
INSERT INTO cfg_plantilla (nombre, hoja, columna_excel, encabezado, campo_bd, validador, obligatorio) VALUES ('colombia_clientes','Clientes','H','Género','genero','genero','S');
INSERT INTO cfg_plantilla (nombre, hoja, columna_excel, encabezado, campo_bd, validador, obligatorio) VALUES ('colombia_clientes','Clientes','I','Email','email','email','S');
INSERT INTO cfg_plantilla (nombre, hoja, columna_excel, encabezado, campo_bd, validador, obligatorio) VALUES ('colombia_clientes','Clientes','J','Teléfono','telefono','telefono','N');
INSERT INTO cfg_plantilla (nombre, hoja, columna_excel, encabezado, campo_bd, validador, obligatorio) VALUES ('colombia_clientes','Clientes','K','Celular','celular','telefono','N');
INSERT INTO cfg_plantilla (nombre, hoja, columna_excel, encabezado, campo_bd, validador, obligatorio) VALUES ('colombia_clientes','Clientes','L','Dirección','direccion','direccion','S');
INSERT INTO cfg_plantilla (nombre, hoja, columna_excel, encabezado, campo_bd, validador, obligatorio) VALUES ('colombia_clientes','Clientes','M','Ciudad','ciudad','ciudad','S');
INSERT INTO cfg_plantilla (nombre, hoja, columna_excel, encabezado, campo_bd, validador, obligatorio) VALUES ('colombia_clientes','Clientes','M','Departamento','departamento','departamento','N');
INSERT INTO cfg_plantilla (nombre, hoja, columna_excel, encabezado, campo_bd, validador, obligatorio) VALUES ('colombia_clientes','Clientes','N','Teléfono','telefono','telefono','N');
INSERT INTO cfg_plantilla (nombre, hoja, columna_excel, encabezado, campo_bd, validador, obligatorio) VALUES ('colombia_clientes','Clientes','O','Celular','celular','telefono','N');
INSERT INTO cfg_plantilla (nombre, hoja, columna_excel, encabezado, campo_bd, validador, obligatorio) VALUES ('colombia_clientes','Clientes','P','Email','email','email','S');
INSERT INTO cfg_plantilla (nombre, hoja, columna_excel, encabezado, campo_bd, validador, obligatorio) VALUES ('colombia_clientes','Clientes','Q','Estado Civil','estado_civil','estado_civil','N');

-- ============================================================
-- CONFIGURACIÓN PLANTILLA - SOLICITUD APERTURA CUENTA
-- ============================================================
DELETE FROM cfg_plantilla WHERE nombre = 'colombia_solicitud_cuenta';
INSERT INTO cfg_plantilla (nombre, hoja, columna_excel, encabezado, campo_bd, validador, obligatorio) VALUES ('colombia_solicitud_cuenta','Solicitudes','A','Nº Solicitud','nro_solicitud','texto','N');
INSERT INTO cfg_plantilla (nombre, hoja, columna_excel, encabezado, campo_bd, validador, obligatorio) VALUES ('colombia_solicitud_cuenta','Solicitudes','B','Fecha Solicitud','fecha_solicitud','fecha','S');
INSERT INTO cfg_plantilla (nombre, hoja, columna_excel, encabezado, campo_bd, validador, obligatorio) VALUES ('colombia_solicitud_cuenta','Solicitudes','C','Tipo Solicitud','tipo_solicitud','tipo_solicitud','S');
INSERT INTO cfg_plantilla (nombre, hoja, columna_excel, encabezado, campo_bd, validador, obligatorio) VALUES ('colombia_solicitud_cuenta','Solicitudes','C','Tipo Cuenta','tipo_cuenta','tipo_cuenta','S');
INSERT INTO cfg_plantilla (nombre, hoja, columna_excel, encabezado, campo_bd, validador, obligatorio) VALUES ('colombia_solicitud_cuenta','Solicitudes','D','Moneda','moneda','moneda','S');
INSERT INTO cfg_plantilla (nombre, hoja, columna_excel, encabezado, campo_bd, validador, obligatorio) VALUES ('colombia_solicitud_cuenta','Solicitudes','E','Sucursal','sucursal','sucursal','S');
INSERT INTO cfg_plantilla (nombre, hoja, columna_excel, encabezado, campo_bd, validador, obligatorio) VALUES ('colombia_solicitud_cuenta','Solicitudes','F','Tipo Doc Cliente','cliente_tipo_doc','tipo_doc','S');
INSERT INTO cfg_plantilla (nombre, hoja, columna_excel, encabezado, campo_bd, validador, obligatorio) VALUES ('colombia_solicitud_cuenta','Solicitudes','G','Nº Doc Cliente','cliente_num_doc','documento','S');
INSERT INTO cfg_plantilla (nombre, hoja, columna_excel, encabezado, campo_bd, validador, obligatorio) VALUES ('colombia_solicitud_cuenta','Solicitudes','H','Apellidos','cliente_apellidos','apellido','S');
INSERT INTO cfg_plantilla (nombre, hoja, columna_excel, encabezado, campo_bd, validador, obligatorio) VALUES ('colombia_solicitud_cuenta','Solicitudes','I','Nombres','cliente_nombres','nombre','S');
INSERT INTO cfg_plantilla (nombre, hoja, columna_excel, encabezado, campo_bd, validador, obligatorio) VALUES ('colombia_solicitud_cuenta','Solicitudes','J','Email','cliente_email','email','S');
INSERT INTO cfg_plantilla (nombre, hoja, columna_excel, encabezado, campo_bd, validador, obligatorio) VALUES ('colombia_solicitud_cuenta','Solicitudes','K','Teléfono','cliente_telefono','telefono','N');
INSERT INTO cfg_plantilla (nombre, hoja, columna_excel, encabezado, campo_bd, validador, obligatorio) VALUES ('colombia_solicitud_cuenta','Solicitudes','K','Celular','cliente_celular','telefono','N');
INSERT INTO cfg_plantilla (nombre, hoja, columna_excel, encabezado, campo_bd, validador, obligatorio) VALUES ('colombia_solicitud_cuenta','Solicitudes','L','Monto Inicial','monto_inicial','monto_positivo','S');
INSERT INTO cfg_plantilla (nombre, hoja, columna_excel, encabezado, campo_bd, validador, obligatorio) VALUES ('colombia_solicitud_cuenta','Solicitudes','M','Origen Fondos','origen_fondos','origen_fondos','S');
INSERT INTO cfg_plantilla (nombre, hoja, columna_excel, encabezado, campo_bd, validador, obligatorio) VALUES ('colombia_solicitud_cuenta','Solicitudes','N','Destino Fondos','destino_fondos','destino_fondos','S');
INSERT INTO cfg_plantilla (nombre, hoja, columna_excel, encabezado, campo_bd, validador, obligatorio) VALUES ('colombia_solicitud_cuenta','Solicitudes','O','Firma Digital','firma_digital','firma_digital','S');
INSERT INTO cfg_plantilla (nombre, hoja, columna_excel, encabezado, campo_bd, validador, obligatorio) VALUES ('colombia_solicitud_cuenta','Solicitudes','P','Oficial Cuenta','oficial_cuenta','texto','N');
INSERT INTO cfg_plantilla (nombre, hoja, columna_excel, encabezado, campo_bd, validador, obligatorio) VALUES ('colombia_solicitud_cuenta','Solicitudes','Q','Estado','estado_solicitud','estado_solicitud','S');
INSERT INTO cfg_plantilla (nombre, hoja, columna_excel, encabezado, campo_bd, validador, obligatorio) VALUES ('colombia_solicitud_cuenta','Solicitudes','R','Observaciones','observaciones','texto','N');