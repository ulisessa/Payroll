/*
    PASO 1 de 2 — se ejecuta en la conexión **Meta4** (Oracle, m4-vm.arbumasa.net.ar:1521).

    EL AGUJERO QUE VIENE A TAPAR. El historial de estados salió de M4T_HIST_ESTADOS_EMPL, que sólo
    cubre embarcados: los administrativos quedaron con CERO estados. Eso ya se vio dos veces hoy —el
    falso positivo del bloque 4.a de AuditarAsignacionesSinFase, que marcó 54 legajos 80xxx/90xxx
    por "no registrar actividad", y la falta de vacaciones de tierra—.

    M4T_AUSENTISMOS tiene las ausencias CON FECHAS REALES (FEC_INICIO / FEC_FIN) y un tipo que mapea
    a los códigos AU*: el 9 es vacaciones. O sea que no es un import de vacaciones, es el historial
    de ausencias entero.

    Y NO ES SÓLO DE TIERRA, aunque al empezar lo pareciera: son 15.202 filas de 1.561 legajos —1.079
    embarcados y 482 de tierra—. Lo que decide qué migrar no es la población sino si esa ausencia ya
    está cargada como estado (bloque 3.c):

        Embarcado · ya está en estados    10.412
        Embarcado · falta                    945
        Tierra    · falta                  3.845

    Para los embarcados, Meta4 ya materializó el 92% de sus ausencias dentro de M4T_HIST_ESTADOS_EMPL
    y por eso llegaron a BC con la migración de estados. Los de tierra no tienen ni una.

    LAS FECHAS BUENAS SON LAS DEL CAMPO, NO LAS DEL COMENTARIO. Las filas traen un texto libre del
    estilo "05/01/2026 - 08/02/2026" que NO coincide con FEC_INICIO/FEC_FIN: los corrimientos van de
    −7 a +30 días, sin patrón. Lo que cierra es el campo — verificado contra DIAS_VACACIONES de
    M4T_ACUMULADO_RL para el legajo 90251 en ocho años distintos:

        2008  01/02 → 14/02 = 14 días  ·  DIAS_VACACIONES 14   ✔
        2009  01/02 → 21/02 = 21       ·  21                   ✔
        2013  01/02 → 21/02 = 21       ·  21                   ✔
        2014  01/01 → 28/01 = 28       ·  28                   ✔
        2019  04/03 → 31/03 = 28       ·  28                   ✔

    En 2021 el comentario da 21 días y el campo 28: el comentario pierde. Probablemente sean las
    fechas efectivamente gozadas contra las imputadas; se guarda en Observaciones y no se calcula
    con él.

    ESTE SCRIPT TODAVÍA NO MIGRA NADA. Los bloques 1 a 4 miden, y son los que deciden si el import
    es posible y con qué alcance. El SELECT de exportación es el bloque 5.
*/

-- ╔══════════════════════════════════════════════════════════════════════════════════════════╗
-- ║  CONEXIÓN: Meta4  (Oracle)                                                               ║
-- ╚══════════════════════════════════════════════════════════════════════════════════════════╝
-- DUAL sólo existe en Oracle: si el editor está apuntando a BC, corta acá y no diez líneas abajo
-- con un error que manda a buscar el problema al lugar equivocado.
SELECT 'Conexión correcta: Oracle' AS GUARDIAN FROM DUAL;

------------------------------------------------------------------------------------------------
-- 1. LAS COLUMNAS — cómo se llaman de verdad
------------------------------------------------------------------------------------------------
-- La grilla que vimos venía sin encabezados, así que los nombres de abajo son deducidos de la
-- posición. Esto los confirma antes de que el resto del script los use.
SELECT column_id, column_name, data_type, data_length, nullable
FROM   all_tab_columns
WHERE  owner = 'ARBPRO' AND table_name = 'M4T_AUSENTISMOS'
ORDER  BY column_id;

------------------------------------------------------------------------------------------------
-- 2. VOLUMEN Y TIPOS — qué ausencias hay y cuántas
------------------------------------------------------------------------------------------------
-- El tipo numérico tiene que mapear contra los códigos AU* del catálogo de BC. El 9 ya sabemos que
-- es vacaciones. Los demás hay que identificarlos: un tipo sin equivalente en BC es una fila que se
-- migra como un código inexistente, y eso el motor no lo reconoce como nada y lo ignora al liquidar
-- —sin error—.
--
-- AJUSTAR EL NOMBRE DE LAS COLUMNAS con lo que devuelva el bloque 1.
SELECT ID_TIPO_AUSENTISMO                    AS TIPO,
       COUNT(*)                            AS FILAS,
       COUNT(DISTINCT ID_EMPLEADO)         AS LEGAJOS,
       MIN(FEC_INICIO)                     AS DESDE,
       MAX(FEC_INICIO)                     AS HASTA,
       ROUND(AVG(FEC_FIN - FEC_INICIO + 1), 1) AS DIAS_PROMEDIO
FROM   ARBPRO.M4T_AUSENTISMOS
WHERE  ID_SOCIEDAD = '01'
GROUP  BY ID_TIPO_AUSENTISMO
ORDER  BY COUNT(*) DESC;

------------------------------------------------------------------------------------------------
-- 3. ¿A QUIÉN CUBRE? — administrativos, embarcados, o los dos
------------------------------------------------------------------------------------------------
-- ESTE ES EL BLOQUE QUE DECIDE EL ALCANCE, y el riesgo concreto es la DUPLICACIÓN: si la tabla
-- también trae embarcados, sus AU* ya están en BC —vinieron por M4T_HIST_ESTADOS_EMPL— y migrarlos
-- de nuevo deja dos estados solapados para los mismos días. El historial de estados es contiguo por
-- construcción: dos filas pisándose no dan error, dan días contados dos veces.
--
-- Los legajos de tierra son los 80xxx y 90xxx; los embarcados, los de cuatro dígitos.
SELECT CASE WHEN TRIM(ID_EMPLEADO) LIKE '8%' OR TRIM(ID_EMPLEADO) LIKE '9%'
            THEN 'Tierra (80xxx/90xxx)'
            ELSE 'Embarcado' END          AS POBLACION,
       COUNT(*)                           AS FILAS,
       COUNT(DISTINCT ID_EMPLEADO)        AS LEGAJOS,
       MIN(FEC_INICIO)                    AS DESDE,
       MAX(FEC_INICIO)                    AS HASTA
FROM   ARBPRO.M4T_AUSENTISMOS
WHERE  ID_SOCIEDAD = '01'
GROUP  BY CASE WHEN TRIM(ID_EMPLEADO) LIKE '8%' OR TRIM(ID_EMPLEADO) LIKE '9%'
               THEN 'Tierra (80xxx/90xxx)'
               ELSE 'Embarcado' END;

-- 3.b LO MISMO CONTRA LA OTRA FUENTE. Si un legajo aparece en las dos tablas, hay que decidir cuál
--     manda antes de migrar. La comparación se hace acá, en Oracle, porque las dos tablas viven
--     de este lado.
SELECT CASE WHEN h.ID_EMPLEADO IS NULL THEN 'Sólo en AUSENTISMOS (hay que migrar)'
            ELSE 'En las DOS (riesgo de duplicar)' END AS SITUACION,
       COUNT(DISTINCT a.ID_EMPLEADO)                   AS LEGAJOS
FROM   (SELECT DISTINCT ID_EMPLEADO FROM ARBPRO.M4T_AUSENTISMOS WHERE ID_SOCIEDAD = '01') a
LEFT JOIN (SELECT DISTINCT ID_EMPLEADO FROM ARBPRO.M4T_HIST_ESTADOS_EMPL WHERE ID_SOCIEDAD = '01') h
       ON h.ID_EMPLEADO = a.ID_EMPLEADO
GROUP  BY CASE WHEN h.ID_EMPLEADO IS NULL THEN 'Sólo en AUSENTISMOS (hay que migrar)'
               ELSE 'En las DOS (riesgo de duplicar)' END;

-- 3.c LA COMPARACIÓN QUE DECIDE — fila contra fila, no legajo contra legajo.
--
--     EL 3.b NO ALCANZA. Medido el 15/9/2026, la tabla trae 11.357 filas de embarcados (1.079
--     legajos) y 3.845 de tierra (482). Casi todos los embarcados van a aparecer en las dos tablas
--     por el solo hecho de tener historial, así que cruzar por legajo dice "riesgo" para todos y no
--     distingue nada.
--
--     Lo que hay que saber es si CADA AUSENCIA ya está cargada como estado: mismo legajo, misma
--     fecha de inicio, mismo código. Si la respuesta es "sí" para los embarcados, entonces
--     M4T_HIST_ESTADOS_EMPL ya materializó las ausencias y sólo hay que migrar tierra.
SELECT CASE WHEN TRIM(a.ID_EMPLEADO) LIKE '8%' OR TRIM(a.ID_EMPLEADO) LIKE '9%'
            THEN 'Tierra' ELSE 'Embarcado' END                    AS POBLACION,
       CASE WHEN h.ID_EMPLEADO IS NULL
            THEN 'FALTA en estados (hay que migrarla)'
            ELSE 'YA está en estados (duplicaría)' END            AS SITUACION,
       COUNT(*)                                                   AS FILAS
FROM   ARBPRO.M4T_AUSENTISMOS a
LEFT JOIN ARBPRO.M4T_HIST_ESTADOS_EMPL h
       ON  h.ID_SOCIEDAD      = a.ID_SOCIEDAD
       AND h.ID_EMPLEADO      = a.ID_EMPLEADO
       AND TRUNC(h.FEC_INICIO) = TRUNC(a.FEC_INICIO)
       AND TRIM(h.ID_ESTADO_EMPL) = 'AU' || TRIM(a.ID_TIPO_AUSENTISMO)
WHERE  a.ID_SOCIEDAD = '01'
GROUP  BY CASE WHEN TRIM(a.ID_EMPLEADO) LIKE '8%' OR TRIM(a.ID_EMPLEADO) LIKE '9%'
               THEN 'Tierra' ELSE 'Embarcado' END,
          CASE WHEN h.ID_EMPLEADO IS NULL
               THEN 'FALTA en estados (hay que migrarla)'
               ELSE 'YA está en estados (duplicaría)' END
ORDER  BY 1, 2

-- 3.d SI EL 3.c MUESTRA FILAS "QUE FALTAN" EN EMBARCADOS, mirarlas antes de decidir: puede ser que
--     la fecha difiera por un día, y entonces no es que falte sino que está corrida — migrarla
--     igual dejaría dos estados casi iguales pisándose.
SELECT TRIM(a.ID_EMPLEADO)                    AS LEGAJO,
       TRUNC(a.FEC_INICIO)                    AS AUSENCIA_DESDE,
       TRUNC(a.FEC_FIN)                       AS AUSENCIA_HASTA,
       'AU' || TRIM(a.ID_TIPO_AUSENTISMO)     AS COD,
       (SELECT MIN(TRUNC(h2.FEC_INICIO))
          FROM ARBPRO.M4T_HIST_ESTADOS_EMPL h2
         WHERE h2.ID_SOCIEDAD = a.ID_SOCIEDAD
           AND h2.ID_EMPLEADO = a.ID_EMPLEADO
           AND TRIM(h2.ID_ESTADO_EMPL) = 'AU' || TRIM(a.ID_TIPO_AUSENTISMO)
           AND h2.FEC_INICIO BETWEEN a.FEC_INICIO - 7 AND a.FEC_INICIO + 7) AS ESTADO_CERCANO
FROM   ARBPRO.M4T_AUSENTISMOS a
WHERE  a.ID_SOCIEDAD = '01'
  AND  NOT (TRIM(a.ID_EMPLEADO) LIKE '8%' OR TRIM(a.ID_EMPLEADO) LIKE '9%')
  AND  NOT EXISTS (SELECT 1 FROM ARBPRO.M4T_HIST_ESTADOS_EMPL h
                   WHERE h.ID_SOCIEDAD = a.ID_SOCIEDAD
                     AND h.ID_EMPLEADO = a.ID_EMPLEADO
                     AND TRUNC(h.FEC_INICIO) = TRUNC(a.FEC_INICIO)
                     AND TRIM(h.ID_ESTADO_EMPL) = 'AU' || TRIM(a.ID_TIPO_AUSENTISMO))
  AND  ROWNUM <= 30
ORDER  BY 1, 2

------------------------------------------------------------------------------------------------
-- 4. CALIDAD DE LAS FECHAS — lo que rompería el historial contiguo de BC
------------------------------------------------------------------------------------------------
-- "Estado Empleado" mantiene la contigüidad y no admite dos estados que arranquen el mismo día para
-- la misma persona (ValidarUnEstadoPorFecha). Estas tres cosas hay que verlas ANTES:
SELECT 'a. Sin fecha de inicio'           AS PROBLEMA, COUNT(*) AS FILAS
FROM   ARBPRO.M4T_AUSENTISMOS WHERE ID_SOCIEDAD = '01' AND FEC_INICIO IS NULL
UNION ALL
SELECT 'b. Fin anterior al inicio',       COUNT(*)
FROM   ARBPRO.M4T_AUSENTISMOS WHERE ID_SOCIEDAD = '01' AND FEC_FIN < FEC_INICIO
UNION ALL
SELECT 'c. Sin fecha de fin (abierta)',   COUNT(*)
FROM   ARBPRO.M4T_AUSENTISMOS WHERE ID_SOCIEDAD = '01' AND FEC_FIN IS NULL;

-- 4.b AUSENCIAS QUE SE PISAN ENTRE SÍ, dentro de la misma tabla. Dos filas del mismo empleado con
--     días compartidos no se pueden migrar las dos: el historial de BC es una línea de tiempo sin
--     superposiciones.
SELECT COUNT(*) AS PARES_SUPERPUESTOS
FROM   ARBPRO.M4T_AUSENTISMOS a
JOIN   ARBPRO.M4T_AUSENTISMOS b
       ON  b.ID_SOCIEDAD = a.ID_SOCIEDAD
       AND b.ID_EMPLEADO = a.ID_EMPLEADO
       AND b.FEC_INICIO  > a.FEC_INICIO
       AND b.FEC_INICIO <= a.FEC_FIN
WHERE  a.ID_SOCIEDAD = '01';

------------------------------------------------------------------------------------------------
-- 5. EL SELECT DE EXPORTACIÓN — descomentar cuando los bloques 1 a 4 cierren
------------------------------------------------------------------------------------------------
-- Mismo camino que los estados: se exporta con DBeaver a una tabla puente en SQL Server y el paso 2
-- inserta desde ahí. Mapeo de columnas POR NOMBRE.
--
-- El código de estado se arma como 'AU' + el tipo, que es la convención del catálogo de BC. Si el
-- bloque 2 muestra tipos sin equivalente, hay que mapearlos a mano acá antes de exportar.
--
-- EL FILTRO ES "LO QUE NO ESTÁ", NO "LA GENTE DE TIERRA". Medido el 15/9/2026 con el bloque 3.c:
--
--     Embarcado · ya está en estados    10.412   ← 92%: Meta4 ya las materializó como estado
--     Embarcado · falta                    945   ← revisar con el 3.d antes de incluirlas
--     Tierra    · falta                  3.845   ← el 100% de tierra; el agujero
--
-- Filtrar por población dejaría afuera los 945 de embarcados que sí faltan, y —peor— dependería de
-- que el número de legajo siga diciendo quién es de tierra. El NOT EXISTS pregunta lo que importa:
-- si esa ausencia ya está cargada como estado. Y es idempotente: correr el import dos veces no
-- duplica nada.
--
-- LOS TRES SIN FECHA DE FIN quedan afuera (bloque 4.c). Un estado sin cerrar vale hasta el
-- 31/12/9999 y se solapa con todos los períodos posteriores; es exactamente el problema que
-- hicieron los francos abiertos desde 2001. Van a mano, con la fecha que diga nómina.
/*
SELECT TRIM(a.ID_EMPLEADO)                       AS LEGAJO,
       TRUNC(a.FEC_INICIO)                       AS FEC_INICIO,
       TRUNC(a.FEC_FIN)                          AS FEC_FIN,
       'AU' || TRIM(a.ID_TIPO_AUSENTISMO)        AS COD_ESTADO,
       -- El texto libre va a Observaciones: no coincide con las fechas del campo y conviene
       -- conservarlo para poder mirarlo si alguna vez hay que discutir un período.
       SUBSTR(TRIM(a.COMENT), 1, 200)            AS COMENT
FROM   ARBPRO.M4T_AUSENTISMOS a
WHERE  a.ID_SOCIEDAD = '01'
  AND  a.FEC_INICIO IS NOT NULL
  AND  a.FEC_FIN IS NOT NULL
  AND  NOT EXISTS (
           SELECT 1
           FROM   ARBPRO.M4T_HIST_ESTADOS_EMPL h
           WHERE  h.ID_SOCIEDAD          = a.ID_SOCIEDAD
             AND  h.ID_EMPLEADO          = a.ID_EMPLEADO
             AND  TRUNC(h.FEC_INICIO)    = TRUNC(a.FEC_INICIO)
             AND  TRIM(h.ID_ESTADO_EMPL) = 'AU' || TRIM(a.ID_TIPO_AUSENTISMO))
ORDER  BY a.ID_EMPLEADO, a.FEC_INICIO;
*/
