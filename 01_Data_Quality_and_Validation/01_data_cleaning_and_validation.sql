-- ============================================================
-- 1. DETECCIÓN DE VALORES NULOS O CRÍTICOS FALTANTES
-- ============================================================
-- Muestra registros que no tienen correo electrónico O
-- teléfono registrado.
--
-- IMPORTANTE:
-- Se utiliza OR porque queremos identificar perfiles
-- incompletos cuando falta al menos uno de los dos datos.
--
-- Si se quisiera encontrar únicamente clientes que no tienen
-- ninguno de los dos datos, se debería utilizar AND.
--
-- Además, esta validación detecta NULL, pero no cadenas vacías.
-- ============================================================

SELECT 
    customer_id, 
    first_name, 
    last_name, 
    email, 
    phone_number
FROM customers
WHERE email IS NULL 
   OR phone_number IS NULL;


-- ============================================================
-- 2. IDENTIFICACIÓN DE REGISTROS DUPLICADOS
-- ============================================================
-- Identifica clientes que aparecen más de una vez utilizando
-- el mismo correo electrónico.
--
-- Se excluyen valores NULL y cadenas vacías para evitar que
-- múltiples registros sin correo sean interpretados como
-- duplicados.
-- ============================================================

SELECT 
    email, 
    COUNT(*) AS total_registros
FROM customers
WHERE email IS NOT NULL 
  AND TRIM(email) <> ''
GROUP BY email
HAVING COUNT(*) > 1;


-- ============================================================
-- 2.1. IDENTIFICACIÓN DE DUPLICADOS CON ROW_NUMBER()
-- ============================================================
-- Asigna un ranking a los registros que comparten el mismo
-- correo electrónico.
--
-- duplicate_rank = 1 → Registro principal/candidato a conservar.
-- duplicate_rank > 1 → Posibles duplicados para revisión.
--
-- IMPORTANTE:
-- El ranking no determina automáticamente qué registro debe
-- eliminarse. En un entorno real se debe definir una regla
-- de supervivencia (survivorship rule).
-- ============================================================

SELECT
    customer_id,
    first_name,
    last_name,
    email,
    phone_number,
    ROW_NUMBER() OVER (
        PARTITION BY email
        ORDER BY customer_id
    ) AS duplicate_rank
FROM customers
WHERE email IS NOT NULL
  AND TRIM(email) <> '';


-- ============================================================
-- 2.2. REGISTROS CANDIDATOS A REVISIÓN
-- ============================================================
-- Muestra únicamente los registros cuyo ranking es mayor
-- a 1, es decir, posibles duplicados.
-- ============================================================

SELECT *
FROM (
    SELECT
        customer_id,
        first_name,
        last_name,
        email,
        phone_number,
        ROW_NUMBER() OVER (
            PARTITION BY email
            ORDER BY customer_id
        ) AS duplicate_rank
    FROM customers
    WHERE email IS NOT NULL
      AND TRIM(email) <> ''
) AS ranked_customers
WHERE duplicate_rank > 1;


-- ============================================================
-- 3. VALIDACIÓN DE REGLAS DE NEGOCIO
-- ============================================================
-- Identifica transacciones de venta con montos negativos
-- o iguales a cero.
--
-- De acuerdo con la regla de negocio asumida, una venta válida
-- debe tener un monto superior a cero.
-- ============================================================

SELECT 
    transaction_id, 
    customer_id, 
    transaction_date, 
    amount
FROM sales_transactions
WHERE amount <= 0;


-- ============================================================
-- 4. CONCILIACIÓN DE DATOS / INTEGRIDAD REFERENCIAL
-- ============================================================
-- Encuentra ventas registradas que no tienen un cliente
-- correspondiente en la tabla customers.
--
-- Se utiliza LEFT JOIN para conservar todas las transacciones
-- y detectar aquellas cuyo customer_id no tiene coincidencia
-- en la tabla de clientes.
--
-- Estos registros pueden representar problemas de integridad
-- referencial, cargas incompletas o errores de sincronización.
-- ============================================================

SELECT 
    s.transaction_id, 
    s.transaction_date, 
    s.amount, 
    s.customer_id
FROM sales_transactions s
LEFT JOIN customers c 
    ON s.customer_id = c.customer_id
WHERE c.customer_id IS NULL;


-- ============================================================
-- 5. CLASIFICACIÓN Y CATEGORIZACIÓN DE ESTADOS
-- ============================================================
-- Clasifica el estado del perfil según la completitud
-- de los datos de contacto.
--
-- Perfil Completo:
-- Tiene email y teléfono.
--
-- Perfil Parcial:
-- Tiene solamente uno de los dos datos.
--
-- Requiere Auditoría:
-- No tiene ninguno de los dos datos.
-- ============================================================

SELECT 
    customer_id,
    first_name,
    last_name,
    CASE 
        WHEN email IS NOT NULL 
             AND TRIM(email) <> ''
             AND phone_number IS NOT NULL 
             AND TRIM(phone_number) <> ''
            THEN 'Perfil Completo'

        WHEN (email IS NOT NULL AND TRIM(email) <> '')
          OR (phone_number IS NOT NULL AND TRIM(phone_number) <> '')
            THEN 'Perfil Parcial'

        ELSE 'Requiere Auditoría'
    END AS estado_registro
FROM customers;


-- ============================================================
-- 6. DETECCIÓN DE FECHAS INVÁLIDAS O FUTURAS
-- ============================================================
-- Identifica transacciones cuya fecha sea posterior a la fecha
-- actual.
--
-- Una transacción de venta no debería encontrarse en el futuro,
-- salvo que el sistema esté diseñado para manejar transacciones
-- programadas.
-- ============================================================

SELECT
    transaction_id,
    customer_id,
    transaction_date,
    amount
FROM sales_transactions
WHERE transaction_date > CURRENT_DATE;


-- ============================================================
-- 7. DETECCIÓN DE FECHAS NULAS
-- ============================================================
-- Identifica transacciones que no tienen una fecha registrada.
--
-- La ausencia de una fecha puede afectar análisis temporales,
-- reportes, conciliaciones y métricas de ventas.
-- ============================================================

SELECT
    transaction_id,
    customer_id,
    transaction_date,
    amount
FROM sales_transactions
WHERE transaction_date IS NULL;


-- ============================================================
-- 8. DETECCIÓN DE DATOS DE CONTACTO VACÍOS
-- ============================================================
-- Detecta registros donde email o teléfono están almacenados
-- como cadenas vacías o únicamente espacios.
--
-- Esta validación complementa la detección de NULL porque,
-- dependiendo del sistema de origen, los datos faltantes pueden
-- almacenarse de diferentes maneras.
-- ============================================================

SELECT
    customer_id,
    first_name,
    last_name,
    email,
    phone_number
FROM customers
WHERE (email IS NOT NULL AND TRIM(email) = '')
   OR (phone_number IS NOT NULL AND TRIM(phone_number) = '');


-- ============================================================
-- 9. DETECCIÓN DE POSIBLES DUPLICADOS POR TELÉFONO
-- ============================================================
-- Identifica números de teléfono asociados a más de un cliente.
--
-- Un mismo teléfono puede ser válido para varios clientes
-- dependiendo del contexto del negocio, por lo que estos
-- registros deben considerarse como "posibles duplicados"
-- y revisarse antes de realizar una depuración.
-- ============================================================

SELECT
    phone_number,
    COUNT(*) AS total_registros
FROM customers
WHERE phone_number IS NOT NULL
  AND TRIM(phone_number) <> ''
GROUP BY phone_number
HAVING COUNT(*) > 1;


-- ============================================================
-- 10. DETECCIÓN DE POSIBLES DUPLICADOS POR NOMBRE
-- ============================================================
-- Identifica combinaciones de nombre y apellido que aparecen
-- más de una vez.
--
-- Esta consulta sirve como mecanismo adicional de profiling.
-- Una coincidencia no significa necesariamente que exista un
-- duplicado real, ya que diferentes personas pueden compartir
-- el mismo nombre.
-- ============================================================

SELECT
    first_name,
    last_name,
    COUNT(*) AS total_registros
FROM customers
WHERE first_name IS NOT NULL
  AND last_name IS NOT NULL
  AND TRIM(first_name) <> ''
  AND TRIM(last_name) <> ''
GROUP BY 
    first_name,
    last_name
HAVING COUNT(*) > 1;


-- ============================================================
-- 11. MÉTRICAS GENERALES DE CALIDAD DE DATOS
-- ============================================================
-- Calcula indicadores generales sobre la completitud de los
-- perfiles de clientes.
--
-- Estas métricas permiten pasar de una revisión registro por
-- registro a una visión agregada de la calidad de los datos.
-- ============================================================

SELECT
    COUNT(*) AS total_clientes,

    SUM(
        CASE 
            WHEN email IS NULL OR TRIM(email) = '' 
            THEN 1 
            ELSE 0 
        END
    ) AS clientes_sin_email,

    SUM(
        CASE 
            WHEN phone_number IS NULL OR TRIM(phone_number) = '' 
            THEN 1 
            ELSE 0 
        END
    ) AS clientes_sin_telefono,

    SUM(
        CASE 
            WHEN (email IS NULL OR TRIM(email) = '')
             AND (phone_number IS NULL OR TRIM(phone_number) = '')
            THEN 1 
            ELSE 0 
        END
    ) AS clientes_sin_contacto,

    SUM(
        CASE 
            WHEN email IS NOT NULL 
             AND TRIM(email) <> ''
             AND phone_number IS NOT NULL
             AND TRIM(phone_number) <> ''
            THEN 1 
            ELSE 0 
        END
    ) AS perfiles_completos

FROM customers;


-- ============================================================
-- 12. CONTEO DE TRANSACCIONES CON PROBLEMAS DE CALIDAD
-- ============================================================
-- Resume la cantidad de transacciones que presentan diferentes
-- tipos de problemas de calidad.
--
-- Esto permite construir un resumen ejecutivo de Data Quality.
-- ============================================================

SELECT
    COUNT(*) AS total_transacciones,

    SUM(
        CASE 
            WHEN amount <= 0 
            THEN 1 
            ELSE 0 
        END
    ) AS transacciones_monto_invalido,

    SUM(
        CASE 
            WHEN transaction_date IS NULL 
            THEN 1 
            ELSE 0 
        END
    ) AS transacciones_sin_fecha,

    SUM(
        CASE 
            WHEN transaction_date > CURRENT_DATE 
            THEN 1 
            ELSE 0 
        END
    ) AS transacciones_fecha_futura

FROM sales_transactions;


-- ============================================================
-- DATA QUALITY OBSERVATIONS
-- ============================================================
--
-- 1. Los valores faltantes pueden representarse como NULL,
--    cadenas vacías ('') o espacios en blanco. Las validaciones
--    deben contemplar estas diferentes representaciones.
--
-- 2. OR y AND tienen diferentes implicaciones:
--    OR identifica registros donde falta al menos uno de los
--    campos evaluados.
--    AND identifica registros donde faltan ambos campos.
--
-- 3. Los duplicados deben analizarse con cuidado. Una coincidencia
--    por email, teléfono o nombre no necesariamente significa
--    que dos registros representen al mismo cliente.
--
-- 4. La detección de anomalías debe complementarse con reglas
--    de negocio. Un monto <= 0, una fecha futura o una venta
--    sin cliente pueden representar diferentes tipos de
--    problemas operativos.
--
-- 5. Las métricas agregadas permiten cuantificar la calidad de
--    los datos y comunicar el impacto de los hallazgos a usuarios
--    técnicos y de negocio.
--
-- 6. Los resultados de estas consultas deberían utilizarse como
--    insumo para acciones correctivas, tales como:
--      - Normalización de datos.
--      - Corrección de registros.
--      - Eliminación o consolidación de duplicados.
--      - Validaciones en procesos ETL/ELT.
--      - Reglas de validación en sistemas de captura.
--      - Monitoreo continuo de Data Quality.
--
-- ============================================================
