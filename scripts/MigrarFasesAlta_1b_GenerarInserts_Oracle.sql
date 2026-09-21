/*
    PASO 1-bis — alternativa al asistente de transferencia de DBeaver.
    Se ejecuta en la conexión **Meta4** (Oracle).

    Hace lo mismo que MigrarFasesAlta_1_Meta4_Oracle.sql, pero en lugar de devolver una grilla para
    exportar, devuelve una columna de TEXTO con los INSERT ya escritos. El transporte pasa a ser
    copiar y pegar, sin asistentes, sin mapeos de columnas y sin drivers de por medio.

    Es más tosco y es a propósito: cuando la transferencia automática falla, lo último que uno
    quiere es depurar el transportador. Acá lo que se mueve es texto plano — o funciona, o el error
    de SQL Server dice exactamente en qué línea y por qué.

    CÓMO USARLO
      1. Completar el ID_SOCIEDAD abajo (el mismo del paso 1) y ejecutar.
      2. La grilla devuelve una sola columna, una línea por INSERT. Para llevarlas:
         · Pocas filas: seleccionar la columna entera (clic en el encabezado), Ctrl+C.
         · Muchas: botón derecho → Exportar resultado… → Archivo → TXT o CSV **sin encabezado y
           sin comillas**, y después abrir ese archivo. Copiar desde la grilla puede truncar.
      3. Pegar en una pestaña conectada a **Migr2013R2** y ejecutar como script (Alt+X).
      4. Seguir con MigrarFasesAlta_2_BC_SqlServer.sql desde el control de totales.

    La tabla dbo.MIG_FasesM4 tiene que existir: la crea el bloque -1 del script del paso 3.
    Si ya tenía datos de un intento anterior, vaciarla primero:  DELETE FROM dbo.MIG_FasesM4;

    POR QUÉ ESTÁ ESCRITO ASÍ, TODO EN LÍNEA
    Sale ilegible, con seis niveles de comillas anidadas, y podría resolverse con dos funciones de
    tres líneas. Pero crear funciones en Meta4 exige permisos de escritura sobre un sistema de
    producción ajeno, y lo normal es tener solo lectura. Al final del archivo está esa versión, más
    corta y más clara, por si el permiso existe.
*/

-- Guardián: DUAL solo existe en Oracle. Si el editor apunta a SQL Server, corta acá.
SELECT 'Conexión correcta: Oracle' AS GUARDIAN FROM DUAL;

SELECT
    'INSERT INTO dbo.MIG_FasesM4 (LEGAJO,FEC_ALTA,FEC_BAJA,MOTIVO_BAJA,COMENT,COMENT_BAJA) VALUES ('
    || '''' || TRIM(f.ID_EMPLEADO) || ''','
    -- Fechas en ISO: es el único formato que SQL Server interpreta igual sin importar el idioma del
    -- servidor. Con DD/MM/YYYY, un 03/04 se convierte en marzo o en abril según la configuración
    -- regional, y no da error — deja fechas cambiadas, que es peor.
    || CASE WHEN f.FEC_ALTA_EMPLEADO IS NULL THEN 'NULL'
            ELSE '''' || TO_CHAR(f.FEC_ALTA_EMPLEADO, 'YYYY-MM-DD') || '''' END || ','
    || CASE WHEN f.FEC_BAJA IS NULL THEN 'NULL'
            ELSE '''' || TO_CHAR(f.FEC_BAJA, 'YYYY-MM-DD') || '''' END || ','
    || CASE WHEN TRIM(f.ID_MOTIVO_BAJA) IS NULL THEN 'NULL'
            ELSE '''' || TRIM(f.ID_MOTIVO_BAJA) || '''' END || ','
    -- Los comentarios: se recortan a 250, se les duplican las comillas simples y se les sacan los
    -- saltos de línea. Los de Meta4 tienen saltos adentro, y uno en el medio partiría el INSERT en
    -- dos líneas que no compilan.
    || CASE WHEN TRIM(f.COMENT) IS NULL THEN 'NULL'
            ELSE '''' || REPLACE(REPLACE(REPLACE(SUBSTR(TRIM(f.COMENT), 1, 250), '''', ''''''), CHR(10), ' '), CHR(13), ' ') || '''' END || ','
    || CASE WHEN TRIM(f.COMENT_BAJA) IS NULL THEN 'NULL'
            ELSE '''' || REPLACE(REPLACE(REPLACE(SUBSTR(TRIM(f.COMENT_BAJA), 1, 250), '''', ''''''), CHR(10), ' '), CHR(13), ' ') || '''' END
    || ');'   AS LINEA
FROM ARBPRO.M4T_FASES_ALTA f
WHERE f.ID_SOCIEDAD = 'COMPLETAR'
ORDER BY TRIM(f.ID_EMPLEADO), f.FEC_ALTA_EMPLEADO;

/*
    ─────────────────────────────────────────────────────────────────────────────────────────────
    SI SON MUCHAS FILAS y el pegado se hace incómodo, se puede partir por legajo:

        AND TRIM(f.ID_EMPLEADO) BETWEEN '00001' AND '02000'

    y repetir cambiando el rango. Los INSERT son independientes entre sí, así que traer de a partes
    no rompe nada: el control de totales del paso 3 avisa si al final falta alguna.

    ─────────────────────────────────────────────────────────────────────────────────────────────
    VERSIÓN CON FUNCIONES — más corta y legible, pero necesita permiso para crear objetos en Meta4.
    Si lo tenés, crear estas dos y usar la consulta de abajo; se pueden borrar después.

    CREATE OR REPLACE FUNCTION Q(p_txt IN VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        IF p_txt IS NULL OR TRIM(p_txt) IS NULL THEN RETURN 'NULL'; END IF;
        RETURN '''' ||
               REPLACE(REPLACE(REPLACE(SUBSTR(TRIM(p_txt), 1, 250), '''', ''''''), CHR(10), ' '), CHR(13), ' ')
               || '''';
    END;
    /

    CREATE OR REPLACE FUNCTION D(p_fec IN DATE) RETURN VARCHAR2 IS
    BEGIN
        IF p_fec IS NULL THEN RETURN 'NULL'; END IF;
        RETURN '''' || TO_CHAR(p_fec, 'YYYY-MM-DD') || '''';
    END;
    /

    SELECT
        'INSERT INTO dbo.MIG_FasesM4 (LEGAJO,FEC_ALTA,FEC_BAJA,MOTIVO_BAJA,COMENT,COMENT_BAJA) VALUES ('
        || Q(TRIM(f.ID_EMPLEADO))    || ','
        || D(f.FEC_ALTA_EMPLEADO)    || ','
        || D(f.FEC_BAJA)             || ','
        || Q(TRIM(f.ID_MOTIVO_BAJA)) || ','
        || Q(f.COMENT)               || ','
        || Q(f.COMENT_BAJA)          || ');'   AS LINEA
    FROM ARBPRO.M4T_FASES_ALTA f
    WHERE f.ID_SOCIEDAD = 'COMPLETAR'
    ORDER BY TRIM(f.ID_EMPLEADO), f.FEC_ALTA_EMPLEADO;
*/
