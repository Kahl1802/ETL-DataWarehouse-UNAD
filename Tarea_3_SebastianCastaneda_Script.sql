-- =============================================================================
-- PROYECTO: Bodega de Datos - Warehouse Integrated
-- CURSO: Tecnologías ETL - UNAD
-- ESTUDIANTE: Sebastián Castañeda Rodríguez
-- MOTOR: PostgreSQL
-- =============================================================================

-- 1. ESTRUCTURA Y DDL (MODELO EN ESTRELLA)
DROP VIEW IF EXISTS View_Cubo_Logico_Ventas CASCADE;
DROP TABLE IF EXISTS Fact_Ventas CASCADE;
DROP TABLE IF EXISTS Dim_Cliente CASCADE;
DROP TABLE IF EXISTS Dim_Tiempo CASCADE;
DROP TABLE IF EXISTS Dim_Producto CASCADE;
DROP TABLE IF EXISTS Dim_Tienda CASCADE;
DROP TABLE IF EXISTS Staging_Clientes CASCADE;

CREATE TABLE Dim_Tienda (
    IdCiudad INT PRIMARY KEY,
    Ciudad VARCHAR(100) NOT NULL,
    Departamento VARCHAR(100) NOT NULL,
    Region VARCHAR(100) NOT NULL
);

CREATE TABLE Dim_Producto (
    IdProducto INT PRIMARY KEY,
    ProductoNombre VARCHAR(150) NOT NULL,
    Marca VARCHAR(100),
    Modelo VARCHAR(100),
    Categoria VARCHAR(100),
    Subcategoria VARCHAR(100),
    Precio DECIMAL(12, 2)
);

CREATE TABLE Dim_Tiempo (
    IdTiempo INT PRIMARY KEY,
    Fecha DATE NOT NULL,
    Dia INT NOT NULL,
    Mes INT NOT NULL,
    Trimestre INT NOT NULL,
    Anio INT NOT NULL,
    DiaSemana VARCHAR(20),
    EsFinSemana INT
);

CREATE TABLE Staging_Clientes (
    idCliente INT,
    Nombre VARCHAR(200),
    Email VARCHAR(200),
    Telefono VARCHAR(100),
    Segmento VARCHAR(100),
    Ciudad VARCHAR(100),
    Sexo VARCHAR(20),
    Edad INT
);

CREATE TABLE Dim_Cliente (
    IdCliente INT PRIMARY KEY,
    Nombre VARCHAR(150) NOT NULL,
    Email VARCHAR(150) NOT NULL,
    Telefono VARCHAR(50),
    Segmento VARCHAR(50),
    Ciudad VARCHAR(100) NOT NULL,
    Sexo VARCHAR(20),
    Edad INT
);

CREATE TABLE Fact_Ventas (
    IdVenta INT PRIMARY KEY,
    IdTiempo INT NOT NULL,
    IdCliente INT NOT NULL,
    IdProducto INT NOT NULL,
    IdTienda INT NOT NULL,
    Cantidad INT NOT NULL,
    PrecioUnitario DECIMAL(12, 2) NOT NULL,
    TotalVenta DECIMAL(12, 2) NOT NULL,
    CostoUnitario DECIMAL(12, 2) NOT NULL,
    MargenUnitario DECIMAL(12, 2) NOT NULL,
    MargenTotal DECIMAL(12, 2) NOT NULL,
    
    CONSTRAINT fk_ventas_tiempo FOREIGN KEY (IdTiempo) REFERENCES Dim_Tiempo(IdTiempo),
    CONSTRAINT fk_ventas_cliente FOREIGN KEY (IdCliente) REFERENCES Dim_Cliente(IdCliente),
    CONSTRAINT fk_ventas_producto FOREIGN KEY (IdProducto) REFERENCES Dim_Producto(IdProducto),
    CONSTRAINT fk_ventas_tienda FOREIGN KEY (IdTienda) REFERENCES Dim_Tienda(IdCiudad)
);

-- 2. PROCEDIMIENTO ALMACENADO ETL DE CLIENTES
CREATE OR REPLACE PROCEDURE sp_etl_cargar_clientes()
LANGUAGE plpgsql
AS $$
BEGIN
    TRUNCATE TABLE Dim_Cliente CASCADE;

    INSERT INTO Dim_Cliente (
        IdCliente, Nombre, Email, Telefono, Segmento, Ciudad, Sexo, Edad
    )
    SELECT 
        idCliente,
        COALESCE(NULLIF(TRIM(Nombre), ''), 'Cliente No Registrado') AS Nombre,
        COALESCE(NULLIF(TRIM(Email), ''), 'sin_correo@warehouse.com') AS Email,
        COALESCE(NULLIF(TRIM(CAST(Telefono AS VARCHAR)), ''), '0000000000') AS Telefono,
        COALESCE(NULLIF(TRIM(Segmento), ''), 'General') AS Segmento,
        CASE 
            WHEN UPPER(TRIM(Ciudad)) IN ('BOGOTA', 'BOGOTÁ') THEN 'Bogotá'
            WHEN UPPER(TRIM(Ciudad)) IN ('MEDELLIN', 'MEDELLÍN') THEN 'Medellín'
            WHEN UPPER(TRIM(Ciudad)) IN ('CALI') THEN 'Cali'
            WHEN UPPER(TRIM(Ciudad)) IN ('CARTAGENA') THEN 'Cartagena'
            WHEN UPPER(TRIM(Ciudad)) IN ('BUCARAMANGA') THEN 'Bucaramanga'
            WHEN UPPER(TRIM(Ciudad)) IN ('CUCUTA', 'CÚCUTA') THEN 'Cúcuta'
            WHEN UPPER(TRIM(Ciudad)) IN ('PEREIRA') THEN 'Pereira'
            WHEN UPPER(TRIM(Ciudad)) IN ('MANIZALES') THEN 'Manizales'
            WHEN UPPER(TRIM(Ciudad)) IN ('IBAGUÉ', 'IBAGUE') THEN 'Ibagué'
            WHEN UPPER(TRIM(Ciudad)) IN ('BARRANQUILLA') THEN 'Barranquilla'
            ELSE COALESCE(INITCAP(TRIM(Ciudad)), 'Sin Ciudad Definida')
        END AS Ciudad,
        COALESCE(NULLIF(TRIM(Sexo), ''), 'No Definido') AS Sexo,
        COALESCE(Edad, 0) AS Edad
    FROM Staging_Clientes;
    
    RAISE NOTICE 'Proceso ETL de Clientes finalizado con éxito.';
END;
$$;

-- 3. VISTA DEL CUBO LÓGICO DE VENTAS (5 NIVELES DE GRANULARIDAD CON SUM)
CREATE OR REPLACE VIEW View_Cubo_Logico_Ventas AS
SELECT 
    t.Mes AS Mes,
    p.Subcategoria AS Subcategoria,
    g.Region AS Region,
    g.Departamento AS Departamento,
    g.Ciudad AS Ciudad,
    
    SUM(v.Cantidad) AS Cantidad_Vendida_Total,
    SUM(v.TotalVenta) AS Total_Venta_Acumulado,
    SUM(v.CostoUnitario) AS Costo_Unitario_Total,
    SUM(v.MargenTotal) AS Margen_Total_Acumulado

FROM Fact_Ventas v
INNER JOIN Dim_Tiempo t ON v.IdTiempo = t.IdTiempo
INNER JOIN Dim_Producto p ON v.IdProducto = p.IdProducto
INNER JOIN Dim_Tienda g ON v.IdTienda = g.IdCiudad

GROUP BY 
    t.Mes,
    p.Subcategoria,
    g.Region,
    g.Departamento,
    g.Ciudad;
