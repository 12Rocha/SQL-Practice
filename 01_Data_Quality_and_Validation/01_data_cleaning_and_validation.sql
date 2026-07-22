-- ====================================================================
-- PROYECTO: Validación de Calidad de Datos (Data Quality Audit)
-- AUTOR: Estefany Manjarres
-- DESCRIPCIÓN: Consultas SQL para auditar, detectar inconsistencias,
--              duplicados y registros nulos en tablas operativas.
-- ====================================================================

-- 1. DETECCIÓN DE VALORES NULOS O CRÍTICOS FALTANTES
-- Muestra registros que no tienen correo electrónico ni teléfono registrado.
SELECT 
    customer_id, 
    first_name, 
    last_name, 
    email, 
    phone_number
FROM customers
WHERE email IS NULL 
   OR phone_number IS NULL;


-- 2. IDENTIFICACIÓN DE REGISTROS DUPLICADOS
-- Cuenta si un cliente aparece más de una vez con el mismo correo electrónico.
SELECT 
    email, 
    COUNT(*) AS total_registros
FROM customers
GROUP BY email
HAVING COUNT(*) > 1;


-- 3. VALIDACIÓN DE REGLAS DE NEGOCIO (Valores atípicos o inválidos)
-- Identifica transacciones de venta con montos negativos o en cero.
SELECT 
    transaction_id, 
    customer_id, 
    transaction_date, 
    amount
FROM sales_transactions
WHERE amount <= 0;


-- 4. CONCILIACIÓN DE DATOS CON UNIONES (LEFT JOIN para detectar huérfanos)
-- Encuentra ventas registradas que no tienen un cliente asignado en la base de datos.
SELECT 
    s.transaction_id, 
    s.transaction_date, 
    s.amount, 
    s.customer_id
FROM sales_transactions s
LEFT JOIN customers c ON s.customer_id = c.customer_id
WHERE c.customer_id IS NULL;


-- 5. CLASIFICACIÓN Y CATEGORIZACIÓN DE ESTADOS (Métricas de Calidad)
-- Clasifica el estado del perfil según la completitud de los datos.
SELECT 
    customer_id,
    first_name,
    last_name,
    CASE 
        WHEN email IS NOT NULL AND phone_number IS NOT NULL THEN 'Perfil Completo'
        WHEN email IS NOT NULL OR phone_number IS NOT NULL THEN 'Perfil Parcial'
        ELSE 'Requiere Auditoría'
    END AS estado_registro
FROM customers;
