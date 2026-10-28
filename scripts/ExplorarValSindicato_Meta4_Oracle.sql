/*
    EXPLORACIÓN — se ejecuta en la conexión **Meta4** (Oracle, m4-vm.arbumasa.net.ar:1521).

    QUÉ SE BUSCA
      El porcentaje de CAJA COMPENSADORA (8542) y de FONDO DE DESEMPLEO (8543). Las dos fórmulas
      están vacías en BC y en enero de 2026 dejan de pagar 2.180.633,11 y 95.533,37 en cuatro
      empleados (01541, 04724, 04893, 04924).

    POR QUÉ ESTE SCRIPT Y NO LA RECONSTRUCCIÓN DESDE LOS RECIBOS
      Se puede derivar el porcentaje de las columnas PORC_CAJA_COMP y PORC_FDO_DESEMP del histórico
      ya migrado (Hist. Liq. Meta4), y de hecho se hizo: da 96 empleados con porcentaje de caja y 304
      con el de fondo, y validando enero contra lo que Meta4 cobró cierra exacto en 6 de 8 casos.
      Pero esa reconstrucción tiene DOS límites que sólo esta tabla puede levantar:

      1. NO DISTINGUE "dejó de pagar" de "no hubo corrida ese mes". Reconstruido por meses
         consecutivos aparecen cuatro huecos de 1 a 3 meses donde el porcentaje desaparece y vuelve
         con EL MISMO valor (04724 dos veces, 01479, 03336). Casi seguro son meses sin liquidar, no
         bajas del aporte, pero el recibo no lo dice: un mes sin recibo y un mes sin aporte se ven
         igual. La vigencia correcta sale de donde esté declarada, no de dónde hubo pago.

      2. NO DICE DE QUÉ DEPENDE EL PORCENTAJE. Reconstruido parece ser POR EMPLEADO: entre los que
         pagan caja compensadora hay 2, 3, 5, 6, 7 y 8, y conviven dentro del mismo sindicato (CAP
         tiene 5, 7 y 8 al mismo tiempo). Si el valor en realidad cuelga del SINDICATO más alguna
         otra dimensión —escala, carga de familia, antigüedad—, entonces en BC no va como atributo
         del empleado sino como parámetro por convenio o como atributo de otra entidad, y cargar 21
         filas por empleado sería congelar un dato derivado. Ver la nota de [atributos-tipados].

    ESTADO EN BC AL 3/10/2026
      Los dos tipos de atributo están creados y **VACÍOS**, a propósito: CAJA_COMPENSADORA
      (PCT_CAJA_COMPENSADORA) y FDO_DESEMPLEO (PCT_FDO_DESEMPLEO), decimales, por empleado. Si esta
      tabla muestra que el valor no es por empleado, se borran sin consecuencias porque ninguna
      fórmula los nombra todavía.

    CÓMO LLEVAR EL RESULTADO, con DBeaver
      Los bloques 1 a 4 son para LEER en pantalla y pegar acá abajo lo que devuelvan; no se exportan.
      El bloque 5 es el que se exporta, y sólo tiene sentido una vez que sepamos las columnas:
        · Botón derecho sobre la grilla -> Exportar resultado... -> Base de datos.
        · Destino: la conexión de BC, esquema dbo, tabla  MIG_ValSindicatoM4  (DDL al final).
        · Mapeo de columnas POR NOMBRE.
*/

-- Que no se ejecute por error contra la base de BC.
SELECT 'Conexión correcta: Oracle' AS GUARDIAN FROM DUAL;


-- ── 1. ¿Existe, y qué otras tablas de sindicato hay? ──────────────────────────────────────────
SELECT   owner, table_name
FROM     all_tables
WHERE    table_name LIKE '%SINDICAT%'
ORDER BY owner, table_name;


-- ── 2. Las columnas de M4T_VAL_SINDICATO ──────────────────────────────────────────────────────
SELECT   column_id, column_name, data_type, data_length, data_precision, data_scale, nullable
FROM     all_tab_columns
WHERE    table_name = 'M4T_VAL_SINDICATO'
ORDER BY column_id;

-- Y las de la de historial, que es la que dice quién está en qué sindicato y desde cuándo.
SELECT   column_id, column_name, data_type, data_length, nullable
FROM     all_tab_columns
WHERE    table_name = 'M4T_HIST_SINDICATOS'
ORDER BY column_id;


-- ── 3. Tamaño y clave: ¿una fila por sindicato, o por sindicato y algo más? ───────────────────
SELECT COUNT(*) AS FILAS FROM ARBPRO.M4T_VAL_SINDICATO;

-- La PK responde de qué depende el valor, que es la pregunta del punto 2 de la cabecera.
SELECT   c.constraint_name, c.constraint_type, cc.position, cc.column_name
FROM     all_constraints c
JOIN     all_cons_columns cc
           ON  cc.owner           = c.owner
           AND cc.constraint_name = c.constraint_name
WHERE    c.table_name = 'M4T_VAL_SINDICATO'
  AND    c.constraint_type IN ('P','U')
ORDER BY c.constraint_name, cc.position;


-- ── 4. Una mirada a los datos ─────────────────────────────────────────────────────────────────
SELECT * FROM ARBPRO.M4T_VAL_SINDICATO WHERE ROWNUM <= 50;

-- Los cuatro que hoy quedan sin cobrar el aporte en BC. Si la tabla tiene ID_EMPLEADO, esto los
-- muestra; si no lo tiene, el error confirma que el valor NO es por empleado, que es justamente lo
-- que se quiere saber.
SELECT * FROM ARBPRO.M4T_VAL_SINDICATO
WHERE  TRIM(ID_EMPLEADO) IN ('01541','04724','04893','04924');


-- ── 5. LA EXTRACCIÓN, para exportar ───────────────────────────────────────────────────────────
/*
    OJO: los nombres de columna de abajo son una APUESTA sobre el modelo —ID_SINDICATO,
    ID_CONCEPTO, VALOR, FEC_INICIO, FEC_FIN— tomada del patrón de las otras M4T_*. Hay que
    ajustarlos con lo que devuelva el bloque 2 ANTES de correr esto. Si alguna no existe, Oracle
    corta con ORA-00904 y no se exporta nada a medias.
*/
SELECT   TRIM(v.ID_SINDICATO)              AS ID_SINDICATO,
         TRIM(v.ID_CONCEPTO)               AS ID_CONCEPTO,
         v.VALOR                           AS VALOR,
         TRUNC(v.FEC_INICIO)               AS FEC_INICIO,
         TRUNC(v.FEC_FIN)                  AS FEC_FIN
FROM     ARBPRO.M4T_VAL_SINDICATO v
ORDER BY 1, 2, 4;


/*
    ── QUÉ CONTESTAR CON ESTO ─────────────────────────────────────────────────────────────────
    Pegá acá el resultado de los bloques 2 y 3 y con eso se decide el modelo en BC:

    a) Si la clave es (sindicato, concepto) con vigencia y NO hay empleado:
       el porcentaje es una TASA DEL SINDICATO. En BC va como Parámetro Vigente con sufijo, y lo
       que falta por empleado es sólo la AFILIACIÓN, que ya está en el atributo SINDICATO. Las
       fórmulas quedan  round(BASE_SINDICAL * PCT_CAJA_COMPENSADORA / 100, PRECISION_REDONDEO)
       con el parámetro resolviendo por sindicato, y los dos tipos de atributo recién creados se
       borran. Esto además explicaría los 2/3/5/6/7/8 como sindicatos distintos y no como
       empleados distintos.

    b) Si la clave incluye el empleado:
       es por empleado y la carga previsualizada (21 filas, 9 empleados) sirve tal cual; esta tabla
       sólo aporta las vigencias declaradas, que son las que cierran los cuatro huecos.

    c) Si la clave incluye una tercera dimensión (escala, categoría, carga de familia):
       eso es un atributo nuevo sobre el empleado MÁS una tasa por sindicato, y hay que verlo antes
       de cargar nada.

    ── DDL del destino, para el bloque 5 ──────────────────────────────────────────────────────
    Ajustar los tipos con lo que diga el bloque 2.

    IF OBJECT_ID('dbo.MIG_ValSindicatoM4') IS NOT NULL DROP TABLE dbo.MIG_ValSindicatoM4;
    CREATE TABLE dbo.MIG_ValSindicatoM4 (
        ID_SINDICATO  nvarchar(20)   NULL,
        ID_CONCEPTO   nvarchar(20)   NULL,
        VALOR         decimal(38,12) NULL,
        FEC_INICIO    date           NULL,
        FEC_FIN       date           NULL
    );
*/
