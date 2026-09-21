/*
    PASO 2 de 2 — se ejecuta en la conexión **BC** (SQL Server).

    Toma dbo.MIG_EstadosM4 (cargada con el resultado de MigrarEstados_1_Meta4_Oracle.sql) y la
    convierte en filas de "Estado Empleado".

    LO QUE TRADUCE
      · Buque:   'HF' + n -> n        (HF801 -> 801)
                 'A'  + n -> '1' + n  (A14 -> 114, A28 -> 128)
                 'PM'     -> 'PPM'    (Puerto Madryn)
      · Estado:  tal cual. El catálogo de BC se renombró a los códigos de Meta4.
      · Proyecto: NO viene en los datos. ID_MAREA nunca es cero —tampoco en las filas de tierra—
        así que no sirve para distinguir. El criterio es "Devenga Francos" del código de estado,
        el mismo que usa ResolverProyectoInactividad en Cod50017:

              Devenga Francos = Sí  ->  PP-<buque>-<marea a 6 dígitos>   (PP-114-000311)
              Devenga Francos = No  ->  PN-<buque>-NOMINA                (PN-114-NOMINA)

    SUPUESTO A CONFIRMAR: las 6 filas de PM (Puerto Madryn) van SIEMPRE a PN-PPM-NOMINA, incluso
    las de estado GP/FR que devengan francos. PPM es un puerto, no un buque: no tiene mareas, y
    las seis filas traen ID_MAREA = 1, que no se corresponde con ninguna marea real. Si el
    supuesto está mal, el bloque 3.c lo reporta como proyecto inexistente antes de insertar.

    ESTO ESCRIBE EN LA MISMA TABLA QUE MigrarFasesAlta_2. Las dos migraciones se complementan
    —altas/bajas por un lado, estados operativos por el otro— pero se intercalan en el mismo
    historial, y eso tiene una consecuencia: las "Fecha Fin" que calculó la migración de fases
    quedan viejas en cuanto se meten estados en el medio. El bloque 6 las recalcula. No es
    opcional.

    ORDEN DE EJECUCIÓN: bloques 1 a 4, después el 5 (inserta) y el 6 (recalcula).

    OJO: el bloque 2 YA NO ES SÓLO LECTURA. El 2.b borra y modifica filas de #Estados —la tabla
    temporal, nunca la base— para resolver dos desfasajes contra las fases de alta. Es idempotente
    y se rehace corriendo el bloque 2 entero desde el principio.
*/

-- ╔══════════════════════════════════════════════════════════════════════════════════════════╗
-- ║  CONEXIÓN: BC  (SQL Server)                                                              ║
-- ╚══════════════════════════════════════════════════════════════════════════════════════════╝
-- Guardián al revés que el del paso 1: si esto corre contra Oracle, falla acá y no más abajo.
SELECT 'Conexión correcta: SQL Server — base ' + DB_NAME() AS GUARDIAN;

------------------------------------------------------------------------------------------------
-- 1. LA TABLA PUENTE
------------------------------------------------------------------------------------------------
IF OBJECT_ID('dbo.MIG_EstadosM4') IS NULL
    CREATE TABLE dbo.MIG_EstadosM4 (
        LEGAJO      varchar(20),
        FEC_ALTA    date,
        FEC_INICIO  date,
        FEC_FIN     date,
        COD_ESTADO  varchar(20),
        BUQUE_M4    varchar(20),
        MAREA       int,
        COMENT      varchar(250)
    );
-- Para rehacer la carga:  TRUNCATE TABLE dbo.MIG_EstadosM4;
-- HAY QUE TRUNCARLA antes de recargar con un rango distinto. Si no, las filas del rango viejo
-- quedan mezcladas con las del nuevo y el LEAD del bloque 2 calcula la contigüidad sobre una
-- mezcla que no existió nunca.

-- Con el histórico completo son ~244.000 filas, y el bloque 2 hace un LEAD particionado por
-- legajo. Sin índice, eso es un sort de la tabla entera en cada corrida.
IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE name = 'IX_MIG_EstadosM4_Legajo' AND object_id = OBJECT_ID('dbo.MIG_EstadosM4'))
    CREATE INDEX IX_MIG_EstadosM4_Legajo ON dbo.MIG_EstadosM4 (LEGAJO, FEC_INICIO);

SELECT COUNT(*)                     AS Filas,
       COUNT(DISTINCT LEGAJO)       AS Legajos,
       COUNT(FEC_FIN)               AS ConFin,
       COUNT(*) - COUNT(FEC_FIN)    AS Abiertos,
       MIN(FEC_INICIO)              AS Desde,
       MAX(FEC_INICIO)              AS Hasta
FROM dbo.MIG_EstadosM4;
-- Histórico completo: ~244.010 filas desde 1999-08-28.
-- Con el rango enero-junio 2026 daba: 2910, 334, 2764, 146, 2026-01-01, 2026-06-xx.

-- 1.b LA PUENTE CARGADA DOS VECES — el error más caro de este script, y el más silencioso.
--
--     Pasó el 13/9/2026: la tabla tenía las 2.910 filas de enero-junio 2026 de una carga anterior y
--     encima se exportó el histórico completo, que las incluye. Total 246.920 en vez de 244.010.
--
--     NADA FALLA. El LEAD del bloque 2 ve dos filas con el mismo inicio, le da a la primera un
--     InicioSiguiente igual a su propio inicio, y la fila queda con FECHA FIN UN DÍA ANTES DEL
--     INICIO. Después el dedup del bloque 5 se queda con una de las dos sin criterio para preferir
--     la sana. El síntoma aparece mucho después, en un recibo, como un estado que no cubre nada.
--
--     El arreglo es TRUNCATE TABLE dbo.MIG_EstadosM4 y volver a exportar.
--
--     Un puñado de duplicados SÍ existe en el origen —Meta4 tiene alguno, como el del 2006-01-15— y
--     ésos los resuelve el dedup. Lo que delata la doble carga es el RANGO: si los duplicados se
--     concentran en el rango de una carga anterior, no son del origen.
SELECT COUNT(*)            AS CombinacionesDuplicadas,
       MIN(FEC_INICIO)     AS PrimerDuplicado,
       MAX(FEC_INICIO)     AS UltimoDuplicado
FROM  (SELECT LEGAJO, FEC_INICIO, COD_ESTADO
       FROM   dbo.MIG_EstadosM4
       GROUP  BY LEGAJO, FEC_INICIO, COD_ESTADO
       HAVING COUNT(*) > 1) x;
-- Con el histórico completo bien cargado tiene que dar 1 (el del 2006-01-15).
-- Dio 2911 con la doble carga, y el rango arrancaba en 2006 pero se concentraba en 2026.

------------------------------------------------------------------------------------------------
-- 2. TRADUCCIÓN — buque, proyecto y contigüidad, todo en una tabla temporal
------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#Estados') IS NOT NULL DROP TABLE #Estados;

WITH Base AS (
    SELECT
        LTRIM(RTRIM(m.LEGAJO))     AS Legajo,
        m.FEC_INICIO               AS FechaInicio,
        m.FEC_FIN                  AS FinM4,
        LTRIM(RTRIM(m.COD_ESTADO)) AS CodEstado,
        LTRIM(RTRIM(m.BUQUE_M4))   AS BuqueM4,
        m.MAREA                    AS Marea,
        ISNULL(m.COMENT, '')       AS Observaciones,
        CASE
            WHEN LTRIM(RTRIM(m.BUQUE_M4)) = 'PM'      THEN 'PPM'
            WHEN LTRIM(RTRIM(m.BUQUE_M4)) LIKE 'HF%'  THEN SUBSTRING(LTRIM(RTRIM(m.BUQUE_M4)), 3, 18)
            WHEN LTRIM(RTRIM(m.BUQUE_M4)) LIKE 'A%'   THEN '1' + SUBSTRING(LTRIM(RTRIM(m.BUQUE_M4)), 2, 18)
            ELSE NULL   -- buque no contemplado: lo caza el bloque 3.b
        END                        AS BuqueBC
    FROM dbo.MIG_EstadosM4 m
)
SELECT
    IDENTITY(int, 1, 1)                   AS Id,   -- identidad de fila: la necesitan las depuraciones del 2.b
    b.Legajo,
    b.FechaInicio,
    b.FinM4,
    b.CodEstado,
    b.BuqueM4,
    b.BuqueBC,
    b.Marea,
    CAST(b.Observaciones AS varchar(250)) AS Observaciones,
    CAST(
        CASE
            -- PPM es un puerto, no un buque: no tiene proyecto de marea (ver el supuesto de arriba).
            WHEN b.BuqueBC = 'PPM'        THEN 'PN-PPM-NOMINA'
            WHEN e.[Devenga Francos] = 1  THEN 'PP-' + b.BuqueBC + '-' + RIGHT('000000' + CAST(b.Marea AS varchar(10)), 6)
            ELSE                               'PN-' + b.BuqueBC + '-NOMINA'
        END AS varchar(20))               AS Proyecto,
    -- Contigüidad: cada estado se cierra el día anterior al inicio del siguiente del mismo legajo.
    -- Se recalcula en vez de confiar en FEC_FIN de Meta4 porque BC exige un historial sin huecos
    -- ni pisadas, y Meta4 no lo garantiza. El bloque 4.a muestra dónde los dos números difieren.
    LEAD(b.FechaInicio) OVER (PARTITION BY b.Legajo ORDER BY b.FechaInicio) AS InicioSiguiente
INTO #Estados
FROM Base b
LEFT JOIN [dbo].[ArbuTest$Cód_ Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
       ON e.[Código] = b.CodEstado;

ALTER TABLE #Estados ADD FechaFin date NULL;

------------------------------------------------------------------------------------------------
-- 2.b DEPURACIÓN CONTRA LAS FASES DE ALTA
--
--     Corre ANTES de calcular fechas de fin y antes de generar rellenos, porque las dos cosas
--     dependen de qué filas quedan.
--
--     De dónde sale: el bloque 3.h.2 midió 3.982 estados que caen fuera de toda fase de alta, y
--     3.900 de ellos están a UN DÍA exacto del borde. Ninguno a más de un año. O sea que no es un
--     problema de datos sino un desfasaje sistemático, y el 3.h.3 mostró que son DOS desfasajes
--     distintos que se arreglan al revés uno del otro.
------------------------------------------------------------------------------------------------

-- 2.b.1 EL "OR" DEL DÍA SIGUIENTE A LA BAJA NO ES UN ESTADO: ES EL FIN DE LA RELACIÓN.
--
--     3.835 filas, 1.071 legajos: OR 3829, OI 4, FR 2 — todos estados de tierra que arrancan
--     exactamente el día después de la fecha de baja de una fase. El historial de estados de Meta4
--     es contiguo y no puede quedar sin nada, así que al terminar la relación abre un estado "a la
--     orden" que en realidad significa "ya no está en la empresa".
--
--     LA ALTERNATIVA ERA EXTENDER LA FASE UN DÍA, y es peor: le agrega a 1.071 personas un día de
--     trabajo que no existió, y con él un día de antigüedad. La fecha de baja es el dato bueno.
--
--     No hace falta tocar el estado anterior: hoy el LEAD lo cierra el día antes de este OR, que
--     es justo la fecha de baja de la fase. Al borrar el OR se recalcula abajo y da lo mismo.
DELETE t
FROM   #Estados t
WHERE  EXISTS (
           SELECT 1
           FROM   [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
           WHERE  f.[No_ Empleado] = t.Legajo
             AND  f.[Fecha Baja] <> '1753-01-01'
             AND  t.FechaInicio = DATEADD(day, 1, f.[Fecha Baja]))
  -- Y que no esté cubierto por NINGUNA otra fase: si la persona volvió a entrar justo al día
  -- siguiente, el estado es real y no hay nada que borrar.
  AND NOT EXISTS (
           SELECT 1
           FROM   [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f2
           WHERE  f2.[No_ Empleado] = t.Legajo
             AND  f2.[Fecha Alta] <= t.FechaInicio
             AND  (f2.[Fecha Baja] = '1753-01-01' OR f2.[Fecha Baja] >= t.FechaInicio));

PRINT 'Estados de cierre de relación descartados: ' + CAST(@@ROWCOUNT AS varchar(10));
-- Sobre el histórico completo dio 3835.

-- 2.b.2 EL EMBARQUE DEL DÍA ANTERIOR AL ALTA SÍ ES UN ESTADO: LLEGÓ TARDE EL ALTA.
--
--     65 filas, 63 legajos: PS 53, GP 11, NV 1 — todos estados de EMBARQUE que arrancan el día
--     antes de la fecha de alta. Esa gente estaba a bordo; lo que está corrido es el alta, no el
--     estado. Al revés que el caso anterior, acá el dato bueno es el estado.
--
--     Se corre el estado un día en vez de adelantar la fase: adelantar el alta cambia antigüedad
--     —y la antigüedad sale de las fases— por un día de embarque que ya está registrado igual.
--     Lo que se pierde es ese único día de navegación en el historial de 63 personas.
UPDATE t
   SET t.FechaInicio = f.[Fecha Alta],
       t.Observaciones = CAST(LEFT(CASE WHEN t.Observaciones = '' THEN '' ELSE t.Observaciones + ' | ' END
                              + 'Migración: embarcado el '
                              + CONVERT(varchar(10), t.FechaInicio, 103)
                              + ', un día antes del alta; corrido al alta.', 250) AS varchar(250))
FROM   #Estados t
JOIN   [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
       ON f.[No_ Empleado] = t.Legajo
      AND t.FechaInicio = DATEADD(day, -1, f.[Fecha Alta])
WHERE  NOT EXISTS (
           SELECT 1
           FROM   [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f2
           WHERE  f2.[No_ Empleado] = t.Legajo
             AND  f2.[Fecha Alta] <= t.FechaInicio
             AND  (f2.[Fecha Baja] = '1753-01-01' OR f2.[Fecha Baja] >= t.FechaInicio));

PRINT 'Estados de embarque corridos al día del alta: ' + CAST(@@ROWCOUNT AS varchar(10));
-- Sobre el histórico completo dio 65.

-- 2.b.3 RECALCULAR LA CONTIGÜIDAD. Obligatorio: borrar filas y mover fechas deja el
--       InicioSiguiente del bloque anterior apuntando a filas que ya no están donde estaban.
WITH Recalc AS (
    SELECT Id,
           LEAD(FechaInicio) OVER (PARTITION BY Legajo ORDER BY FechaInicio, Id) AS Sig
    FROM   #Estados
)
UPDATE t
   SET t.InicioSiguiente = r.Sig
FROM   #Estados t
JOIN   Recalc r ON r.Id = t.Id;

-- 2.b.4 LO QUE QUEDA FUERA DE FASE SE MARCA, NO SE BORRA NI SE ACOMODA.
--
--     Después del 2.b.1 y el 2.b.2 sobreviven unos 68 estados que caen fuera de toda fase por más
--     de un día: entre una semana y un año, ninguno más. No hay una regla que los explique a todos
--     —son casos sueltos, muchos de 2002 y 2007, y algunos recientes como el legajo 04932— así que
--     inventar una sería peor que dejarlos.
--
--     Entran igual, porque el estado ocurrió. Pero entran MARCADOS: el INSERT del bloque 5 va por
--     SQL y no ejecuta ValidarDentroDeFaseDeAlta, o sea que nada más los va a señalar. Un estado
--     fuera de fase hace que ese tramo liquide con antigüedad cero, y cuando alguien lo note dentro
--     de dos años, la observación es lo único que va a decir que ya se sabía.
--
--     Para encontrarlos después:
--         SELECT * FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
--         WHERE [Observaciones] LIKE '%fuera de toda fase%';
UPDATE t
   SET t.Observaciones = CAST(LEFT(CASE WHEN t.Observaciones = '' THEN '' ELSE t.Observaciones + ' | ' END
                          + 'Migración: fuera de toda fase de alta del empleado.', 250) AS varchar(250))
FROM   #Estados t
WHERE  NOT EXISTS (
           SELECT 1
           FROM   [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
           WHERE  f.[No_ Empleado] = t.Legajo
             AND  f.[Fecha Alta] <= t.FechaInicio
             AND  (f.[Fecha Baja] = '1753-01-01' OR f.[Fecha Baja] >= t.FechaInicio))
  -- Sólo los que TIENEN fases. Quien no tiene ninguna tampoco existe como Employee y el bloque 5
  -- lo descarta entero: marcarlo sería ensuciar una fila que no va a llegar a la base.
  AND  EXISTS (
           SELECT 1
           FROM   [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f2
           WHERE  f2.[No_ Empleado] = t.Legajo);

PRINT 'Estados marcados como fuera de fase: ' + CAST(@@ROWCOUNT AS varchar(10));
-- Sobre el histórico completo dio del orden de 68.

------------------------------------------------------------------------------------------------

-- EL CIERRE DE META4 SE RESPETA CUANDO ES ANTERIOR AL INICIO DEL SIGUIENTE.
--
-- La versión anterior estiraba el estado hasta el día antes del siguiente, siempre. Eso tapa el
-- hueco pero MIENTE cuando el estado es consumible: FR es franco GOZADO, así que estirarlo dos
-- semanas le hace consumir a esa persona dos semanas de franco que nunca se tomó. Son 28 casos con
-- huecos de entre 2 y 22 días, y el error sale en el recibo sin que nada lo marque.
--
-- Sin siguiente, se conserva el fin de Meta4; si Meta4 tampoco lo cerró, queda abierto.
-- '1753-01-01' es como BC guarda una fecha en blanco, o sea "estado abierto, sigue vigente".
UPDATE #Estados
   SET FechaFin = CASE
                    WHEN InicioSiguiente IS NULL
                        THEN COALESCE(FinM4, '1753-01-01')
                    WHEN FinM4 IS NOT NULL AND FinM4 < DATEADD(day, -1, InicioSiguiente)
                        THEN FinM4
                    ELSE DATEADD(day, -1, InicioSiguiente)
                  END;

-- EL HUECO SE TAPA CON UNA FILA PROPIA, no estirando la anterior.
--
-- Quien no tiene ningún estado está a la orden en tierra: el código es OR. No devenga francos, así
-- que cae en PN-<buque>-NOMINA por la misma regla que el resto — no es una excepción, es la regla
-- aplicada a un estado más.
--
-- Las filas generadas se reconocen por la observación: son las únicas que no vienen de Meta4, y el
-- día que alguien se pregunte de dónde salió ese OR, la fila lo dice.
INSERT INTO #Estados
    (Legajo, FechaInicio, FinM4, CodEstado, BuqueM4, BuqueBC, Marea,
     Observaciones, Proyecto, InicioSiguiente, FechaFin)
SELECT t.Legajo,
       DATEADD(day, 1, t.FinM4),
       NULL,
       'OR',
       t.BuqueM4,
       t.BuqueBC,
       t.Marea,
       CAST('Generado por la migración: Meta4 cerró el ' + CONVERT(varchar(10), t.CodEstado)
            + ' el ' + CONVERT(varchar(10), t.FinM4, 103)
            + ' y el estado siguiente arranca el ' + CONVERT(varchar(10), t.InicioSiguiente, 103)
            AS varchar(250)),
       CAST('PN-' + t.BuqueBC + '-NOMINA' AS varchar(20)),
       t.InicioSiguiente,
       DATEADD(day, -1, t.InicioSiguiente)
FROM   #Estados t
WHERE  t.InicioSiguiente IS NOT NULL
  AND  t.FinM4 IS NOT NULL
  AND  t.FinM4 < DATEADD(day, -1, t.InicioSiguiente)
  -- SÓLO SI EL HUECO CAE DENTRO DE UNA FASE. Desde que el 2.b.1 borra el OR de cierre de relación,
  -- entre una baja y el alta siguiente queda un hueco REAL: la persona no estaba en la empresa.
  -- Sin esta condición el relleno lo taparía con un OR y volveríamos a inventar lo mismo que el
  -- 2.b.1 acaba de sacar, sólo que ahora con una fila que dice "generado por la migración".
  --
  -- ESTA CONDICIÓN SE AGREGÓ TARDE, y una corrida anterior alcanzó a insertar 26 rellenos sin ella:
  -- todos 'OR', todos arrancando el día siguiente a una baja y terminando el día antes del
  -- reingreso. El de 04513 son 54 días que el motor contaría como trabajados. Ya no pueden
  -- generarse, pero quedaron escritos — se borran con el bloque 4.d de CerrarEstadosPorBaja.sql.
  AND  EXISTS (
           SELECT 1
           FROM   [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
           WHERE  f.[No_ Empleado] = t.Legajo
             AND  f.[Fecha Alta] <= DATEADD(day, 1, t.FinM4)
             AND  (f.[Fecha Baja] = '1753-01-01'
                   OR f.[Fecha Baja] >= DATEADD(day, -1, t.InicioSiguiente)));
-- Sin buque traducido el CONCAT da NULL y el relleno queda sin proyecto, igual que la fila que lo
-- originó. Antes se descartaban esas filas; desde que un estado sin proyecto entra igual (ver el
-- bloque 5), descartarlas dejaría un hueco en el historial de alguien por un buque que ya no existe.

SELECT COUNT(*) AS FilasTotales,
       SUM(CASE WHEN Observaciones LIKE 'Generado por la migración%' THEN 1 ELSE 0 END) AS Rellenos
FROM   #Estados;
-- Con el rango enero-junio: 2910 de Meta4 + 28 de relleno = 2938.
-- Con el histórico completo: ~244.010 de Meta4 más los rellenos que salgan.

SELECT Proyecto, COUNT(*) AS Filas FROM #Estados GROUP BY Proyecto ORDER BY 2 DESC;
-- Reparto con enero-junio: 2363 filas a PP-* (marea) y 547 + 28 de relleno a PN-*-NOMINA (tierra).

------------------------------------------------------------------------------------------------
-- 3. PRE-VUELO — las cinco cosas que hacen fallar la migración. Todas tienen que dar CERO filas.
------------------------------------------------------------------------------------------------

-- 3.a Códigos de estado que no existen en BC.
--     Una fila con un código inexistente no da error visible: el motor no la reconoce como nada
--     y la ignora al liquidar.
SELECT DISTINCT t.CodEstado
FROM #Estados t
WHERE NOT EXISTS (SELECT 1 FROM [dbo].[ArbuTest$Cód_ Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
                  WHERE e.[Código] = t.CodEstado);

-- 3.b Buques que la traducción no supo mapear.
--     Un buque sin traducir deja el proyecto en NULL —la concatenación con NULL da NULL— y esas
--     filas NO entran: el INSERT del bloque 5 hace JOIN contra Job. Con el histórico completo
--     esto deja de ser anecdótico: la flota de 1999 no es la de 2026.
SELECT BuqueM4, COUNT(*) AS Filas, MIN(FechaInicio) AS Desde, MAX(FechaInicio) AS Hasta
FROM #Estados WHERE BuqueBC IS NULL
GROUP BY BuqueM4 ORDER BY 2 DESC;

-- Y el otro motivo de proyecto NULL, que no es el buque: marea vacía en un estado que devenga
-- francos. Se separa porque la solución es distinta — un buque se traduce, una marea no se inventa.
SELECT COUNT(*) AS FilasSinMareaPeroConBuque
FROM #Estados WHERE BuqueBC IS NOT NULL AND Proyecto IS NULL;

-- 3.c Proyectos que no existen como Job. YA NO ES BLOQUEANTE: desde el 13/9/2026 esas filas entran
--     con "No. Proyecto" en blanco (ver el bloque 5). Sigue acá porque es el número que dice
--     cuánta historia queda sin marea, y porque una falta en un año RECIENTE sí es un problema:
--     ahí el proyecto debería existir, y si no está es que la sincronización con NAV se lo perdió.
--     Un PN-<buque>-NOMINA faltante deja sin encuadre a todo un buque, y eso no se ve hasta que
--     falta gente en la liquidación.
--
--     3.c.1 EL RESUMEN, que es lo que decide. El detalle de abajo puede traer miles de filas y no
--     se lee; esto sí. La sincronización con NAV trajo 4477 proyectos, y son los recientes.
SELECT CASE WHEN t.Proyecto LIKE 'PP-%' THEN 'PP (marea)' ELSE 'PN (tierra)' END AS Tipo,
       YEAR(t.FechaInicio)        AS Anio,
       COUNT(DISTINCT t.Proyecto) AS ProyectosFaltantes,
       COUNT(*)                   AS FilasQueSePerderian
FROM #Estados t
WHERE t.Proyecto IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM [dbo].[ArbuTest$Job$437dbf0e-84ff-417a-965d-ed2bb9650972] j
                  WHERE j.[No_] = t.Proyecto)
GROUP BY CASE WHEN t.Proyecto LIKE 'PP-%' THEN 'PP (marea)' ELSE 'PN (tierra)' END,
         YEAR(t.FechaInicio)
ORDER BY Anio, Tipo;
-- Leerlo por año: si lo que falta se concentra en los años viejos, recortar el rango resuelve.
-- Si falta parejo hasta 2026, el problema no es la antigüedad y hay que crear los proyectos.

--     3.c.2 El detalle.
SELECT t.Proyecto, COUNT(*) AS Filas, MIN(t.BuqueM4) AS BuqueM4, MIN(t.CodEstado) AS EjemploEstado
FROM #Estados t
WHERE NOT EXISTS (SELECT 1 FROM [dbo].[ArbuTest$Job$437dbf0e-84ff-417a-965d-ed2bb9650972] j
                  WHERE j.[No_] = t.Proyecto)
GROUP BY t.Proyecto
ORDER BY 2 DESC;

-- 3.d Legajos que no existen como Employee.
SELECT DISTINCT t.Legajo
FROM #Estados t
WHERE NOT EXISTS (SELECT 1 FROM [dbo].[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972] emp
                  WHERE emp.[No_] = t.Legajo);

-- 3.e Choques con lo que YA está en BC — sobre todo con las altas/bajas de MigrarFasesAlta.
--     Un empleado tiene un solo estado por fecha (ver ValidarUnEstadoPorFecha en Tab60000): dos
--     filas el mismo día dejan un historial contradictorio, y GetEstado elige una de las dos sin
--     criterio. La inserción del bloque 5 las saltea, pero saltearlas en silencio es peor que
--     saber cuáles son: si un ALT del 1/1 choca con un NV del 1/1, el que sobra es el NV y hay
--     que decidir a mano.
--
--     OJO AL RECARGAR CON UN RANGO MÁS AMPLIO: las filas que ya se migraron en una corrida
--     anterior vuelven a aparecer acá, porque están en BC y también en #Estados. Eso NO es un
--     choque: es la misma fila. El resumen de abajo las separa — un choque real es el que trae
--     un código de estado DISTINTO al que ya está cargado.
SELECT CASE WHEN t.CodEstado = ee.[Cód_ Estado] THEN 'Ya migrada (misma fila)'
            ELSE 'CHOQUE REAL — códigos distintos' END AS Tipo,
       COUNT(*) AS Filas
FROM #Estados t
JOIN [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
  ON ee.[No_ Empleado] = t.Legajo
 AND ee.[Fecha Inicio] = t.FechaInicio
 AND ee.[Tipo Entidad] = 0
GROUP BY CASE WHEN t.CodEstado = ee.[Cód_ Estado] THEN 'Ya migrada (misma fila)'
              ELSE 'CHOQUE REAL — códigos distintos' END;

-- El detalle, sólo de los choques reales.
SELECT t.Legajo, t.FechaInicio, t.CodEstado AS EstadoNuevo, ee.[Cód_ Estado] AS YaEnBC
FROM #Estados t
JOIN [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
  ON ee.[No_ Empleado] = t.Legajo
 AND ee.[Fecha Inicio] = t.FechaInicio
 AND ee.[Tipo Entidad] = 0
WHERE t.CodEstado <> ee.[Cód_ Estado]
ORDER BY t.Legajo, t.FechaInicio;

-- 3.h ESTADOS DE EMPLEADOS QUE NO TIENEN FASE DE ALTA QUE LOS CUBRA.
--     Desde que las altas y bajas viven en "Fase Alta Empleado", un estado operativo tiene que caer
--     adentro de una fase: nadie puede estar navegando un día en que no pertenece a la empresa. La
--     tabla lo valida, pero ESTE INSERT ENTRA POR SQL Y NO PASA POR ESA VALIDACIÓN — así que este
--     bloque es el único control. Si devuelve filas y se inserta igual, esos estados quedan fuera de
--     toda fase y el empleado liquida con antigüedad cero sin que nada lo diga.
--
--     Dos causas posibles y se distinguen por la columna Motivo:
--       · SIN NINGUNA FASE   → el empleado nunca se migró desde M4T_FASES_ALTA.
--       · FUERA DE SUS FASES → el estado es anterior al ingreso o posterior a la baja. Ahí hay que
--                              mirar cuál de los dos datos está mal antes de tocar nada.
-- El motivo se calcula en una CTE y no en el SELECT: SQL Server no admite una subconsulta en la
-- lista del GROUP BY (Msg 144), y repetir el CASE en el GROUP BY es lo que lo dispara.
WITH SinCobertura AS (
    SELECT t.Legajo,
           t.FechaInicio,
           CASE WHEN EXISTS (SELECT 1 FROM [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
                             WHERE f.[No_ Empleado] = t.Legajo)
                THEN 'FUERA DE SUS FASES'
                ELSE 'SIN NINGUNA FASE' END AS Motivo
    FROM   #Estados t
    WHERE  NOT EXISTS (
               SELECT 1
               FROM   [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
               WHERE  f.[No_ Empleado] = t.Legajo
                 AND  f.[Fecha Alta] <= t.FechaInicio
                 -- '1753-01-01' es la fecha en blanco de BC: fase abierta, sin tope por arriba.
                 AND  (f.[Fecha Baja] = '1753-01-01' OR f.[Fecha Baja] >= t.FechaInicio))
)
SELECT Legajo,
       Motivo,
       MIN(FechaInicio) AS PrimerEstado,
       MAX(FechaInicio) AS UltimoEstado,
       COUNT(*)         AS Estados
FROM   SinCobertura
GROUP  BY Legajo, Motivo
ORDER  BY Motivo, Estados DESC;

-- El resumen primero, que con el histórico completo es lo único legible: el detalle de arriba
-- puede traer miles de legajos.
WITH SinCobertura AS (
    SELECT t.Legajo,
           YEAR(t.FechaInicio) AS Anio,
           CASE WHEN EXISTS (SELECT 1 FROM [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
                             WHERE f.[No_ Empleado] = t.Legajo)
                THEN 'FUERA DE SUS FASES'
                ELSE 'SIN NINGUNA FASE' END AS Motivo
    FROM   #Estados t
    WHERE  NOT EXISTS (
               SELECT 1
               FROM   [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
               WHERE  f.[No_ Empleado] = t.Legajo
                 AND  f.[Fecha Alta] <= t.FechaInicio
                 AND  (f.[Fecha Baja] = '1753-01-01' OR f.[Fecha Baja] >= t.FechaInicio))
)
SELECT Motivo, Anio, COUNT(DISTINCT Legajo) AS Legajos, COUNT(*) AS Estados
FROM   SinCobertura
GROUP  BY Motivo, Anio
ORDER  BY Motivo, Anio;

-- 3.h.2 A QUÉ DISTANCIA DE UNA FASE QUEDA CADA ESTADO HUÉRFANO.
--
--     Es la consulta que decide qué hacer, y el detalle de arriba no sirve para eso: con el
--     histórico completo son cientos de legajos y leerlos de a uno no dice nada.
--
--     Un estado a UN DÍA de la baja es un borde: Meta4 cierra el estado el día siguiente al último
--     trabajado y la fase cierra el último. Eso se arregla con una regla, no caso por caso.
--     Un estado a DOS AÑOS de cualquier fase es otra cosa: o falta una fase que Meta4 sí tiene, o
--     el estado quedó abierto en Meta4 después de que la persona se fue. Ahí hay que mirar el caso.
--
--     La distancia se mide al borde más cercano de la fase más cercana del mismo legajo.
--
--     VA CON LEFT JOIN Y GROUP BY, NO CON UNA SUBCONSULTA CORRELACIONADA. El MIN necesita
--     h.FechaInicio Y f.[Fecha Alta] en el mismo CASE, y SQL Server rechaza un agregado que mezcle
--     una referencia externa con columnas de adentro: "Multiple columns are specified in an
--     aggregated expression containing an outer reference" (Msg 8124). OUTER APPLY TAMPOCO sirve
--     —la correlación sigue siendo una referencia externa para esa regla—. Con el join las dos
--     columnas vienen del mismo FROM y no hay referencia externa en absoluto.
--
--     El Id existe para que el GROUP BY no junte dos estados idénticos del mismo legajo y día.
WITH Huerfanos AS (
    SELECT ROW_NUMBER() OVER (ORDER BY t.Legajo, t.FechaInicio) AS Id,
           t.Legajo, t.FechaInicio, t.CodEstado
    FROM   #Estados t
    WHERE  NOT EXISTS (
               SELECT 1
               FROM   [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
               WHERE  f.[No_ Empleado] = t.Legajo
                 AND  f.[Fecha Alta] <= t.FechaInicio
                 AND  (f.[Fecha Baja] = '1753-01-01' OR f.[Fecha Baja] >= t.FechaInicio))
),
ConDistancia AS (
    SELECT h.Id, h.Legajo, h.FechaInicio, h.CodEstado,
           MIN(CASE
                 WHEN f.[No_ Empleado] IS NULL THEN NULL
                 WHEN h.FechaInicio < f.[Fecha Alta]
                      THEN DATEDIFF(day, h.FechaInicio, f.[Fecha Alta])
                 WHEN f.[Fecha Baja] <> '1753-01-01' AND h.FechaInicio > f.[Fecha Baja]
                      THEN DATEDIFF(day, f.[Fecha Baja], h.FechaInicio)
                 ELSE 0
               END) AS Dias
    FROM   Huerfanos h
    LEFT JOIN [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
           ON f.[No_ Empleado] = h.Legajo
    GROUP  BY h.Id, h.Legajo, h.FechaInicio, h.CodEstado
),
Clasificada AS (
    SELECT Legajo,
           CASE
             WHEN Dias IS NULL   THEN '0. sin ninguna fase'
             WHEN Dias <= 1      THEN '1. un día — borde de la fase'
             WHEN Dias <= 7      THEN '2. hasta una semana'
             WHEN Dias <= 30     THEN '3. hasta un mes'
             WHEN Dias <= 365    THEN '4. hasta un año'
             ELSE                     '5. más de un año — revisar'
           END AS Distancia
    FROM   ConDistancia
)
SELECT Distancia, COUNT(*) AS Estados, COUNT(DISTINCT Legajo) AS Legajos
FROM   Clasificada
GROUP  BY Distancia
ORDER  BY Distancia;

-- Y los peores casos concretos, para mirar tres o cuatro a mano antes de decidir por todos.
WITH Huerfanos AS (
    SELECT ROW_NUMBER() OVER (ORDER BY t.Legajo, t.FechaInicio) AS Id,
           t.Legajo, t.FechaInicio, t.CodEstado
    FROM   #Estados t
    WHERE  NOT EXISTS (
               SELECT 1
               FROM   [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
               WHERE  f.[No_ Empleado] = t.Legajo
                 AND  f.[Fecha Alta] <= t.FechaInicio
                 AND  (f.[Fecha Baja] = '1753-01-01' OR f.[Fecha Baja] >= t.FechaInicio))
)
SELECT TOP 20 h.Legajo, h.FechaInicio, h.CodEstado,
       MIN(CASE
             WHEN f.[No_ Empleado] IS NULL THEN NULL
             WHEN h.FechaInicio < f.[Fecha Alta]
                  THEN DATEDIFF(day, h.FechaInicio, f.[Fecha Alta])
             WHEN f.[Fecha Baja] <> '1753-01-01' AND h.FechaInicio > f.[Fecha Baja]
                  THEN DATEDIFF(day, f.[Fecha Baja], h.FechaInicio)
             ELSE 0
           END) AS Dias
FROM   Huerfanos h
LEFT JOIN [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
       ON f.[No_ Empleado] = h.Legajo
GROUP  BY h.Id, h.Legajo, h.FechaInicio, h.CodEstado
ORDER  BY Dias DESC;

-- 3.h.3 DE QUÉ LADO CAE EL DÍA.
--
--     Medido el 13/9/2026 sobre el histórico completo: de 3.982 estados fuera de fase, 3.900 están
--     a UN DÍA y ninguno a más de un año. O sea que no hay un problema de datos: hay un desfasaje
--     de un día entre cómo cierra Meta4 y cómo cierra la fase migrada.
--
--     Pero un día ANTES DEL ALTA y un día DESPUÉS DE LA BAJA no son lo mismo:
--       · Después de la baja → la fase cierra el último día trabajado y Meta4 sigue un día más.
--       · Antes del alta     → el estado arranca el día previo al ingreso, que no debería existir.
--     Esta consulta separa los dos casos y muestra la fase concreta al lado del estado, para poder
--     mirar diez y decidir por los 3.900.
WITH Huerfanos AS (
    SELECT ROW_NUMBER() OVER (ORDER BY t.Legajo, t.FechaInicio) AS Id,
           t.Legajo, t.FechaInicio, t.CodEstado
    FROM   #Estados t
    WHERE  NOT EXISTS (
               SELECT 1
               FROM   [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
               WHERE  f.[No_ Empleado] = t.Legajo
                 AND  f.[Fecha Alta] <= t.FechaInicio
                 AND  (f.[Fecha Baja] = '1753-01-01' OR f.[Fecha Baja] >= t.FechaInicio))
),
Pareado AS (
    SELECT h.Id, h.Legajo, h.FechaInicio, h.CodEstado,
           f.[Fecha Alta] AS FaseAlta, f.[Fecha Baja] AS FaseBaja,
           CASE
             WHEN h.FechaInicio < f.[Fecha Alta]
                  THEN DATEDIFF(day, h.FechaInicio, f.[Fecha Alta])
             WHEN f.[Fecha Baja] <> '1753-01-01' AND h.FechaInicio > f.[Fecha Baja]
                  THEN DATEDIFF(day, f.[Fecha Baja], h.FechaInicio)
             ELSE 0
           END AS Dias,
           CASE WHEN h.FechaInicio < f.[Fecha Alta] THEN 'antes del alta'
                ELSE 'después de la baja' END AS Lado
    FROM   Huerfanos h
    JOIN   [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
           ON f.[No_ Empleado] = h.Legajo
),
MasCercana AS (
    -- La fase más cercana de cada estado, con su lado. El ROW_NUMBER evita tener que volver a
    -- agregar: se queda con una fila por estado, la de menor distancia.
    SELECT *, ROW_NUMBER() OVER (PARTITION BY Id ORDER BY Dias) AS Orden
    FROM   Pareado
)
SELECT Lado, Dias, COUNT(*) AS Estados, COUNT(DISTINCT Legajo) AS Legajos
FROM   MasCercana
WHERE  Orden = 1 AND Dias <= 1
GROUP  BY Lado, Dias
ORDER  BY Lado, Dias;

-- Diez casos concretos con la fase al lado, para mirarlos antes de decidir por los 3.900.
WITH Huerfanos AS (
    SELECT ROW_NUMBER() OVER (ORDER BY t.Legajo, t.FechaInicio) AS Id,
           t.Legajo, t.FechaInicio, t.CodEstado
    FROM   #Estados t
    WHERE  NOT EXISTS (
               SELECT 1
               FROM   [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
               WHERE  f.[No_ Empleado] = t.Legajo
                 AND  f.[Fecha Alta] <= t.FechaInicio
                 AND  (f.[Fecha Baja] = '1753-01-01' OR f.[Fecha Baja] >= t.FechaInicio))
),
Pareado AS (
    SELECT h.Id, h.Legajo, h.FechaInicio, h.CodEstado,
           f.[Fecha Alta] AS FaseAlta, f.[Fecha Baja] AS FaseBaja,
           CASE
             WHEN h.FechaInicio < f.[Fecha Alta]
                  THEN DATEDIFF(day, h.FechaInicio, f.[Fecha Alta])
             WHEN f.[Fecha Baja] <> '1753-01-01' AND h.FechaInicio > f.[Fecha Baja]
                  THEN DATEDIFF(day, f.[Fecha Baja], h.FechaInicio)
             ELSE 0
           END AS Dias,
           CASE WHEN h.FechaInicio < f.[Fecha Alta] THEN 'antes del alta'
                ELSE 'después de la baja' END AS Lado
    FROM   Huerfanos h
    JOIN   [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
           ON f.[No_ Empleado] = h.Legajo
),
MasCercana AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY Id ORDER BY Dias) AS Orden
    FROM   Pareado
)
SELECT TOP 10 Legajo, FechaInicio AS EstadoDesde, CodEstado, FaseAlta, FaseBaja, Lado
FROM   MasCercana
WHERE  Orden = 1 AND Dias <= 1
ORDER  BY Legajo, FechaInicio;



-- 3.f AUTOPSIA — a cada fila, el motivo por el que entra o no entra. La suma da el total del
--     bloque 2. Es la consulta a correr PRIMERO cuando el INSERT mete muchas menos filas de las
--     esperadas: dice cuál de los filtros se las está comiendo, en vez de tener que probar de a uno.
--
--     EL ORDEN DEL CASE ES EL ORDEN DE LOS FILTROS REALES, y por eso "entra sin proyecto" va
--     después de "ya existe": una fila con las dos condiciones no entra, y etiquetarla por el
--     proyecto la haría parecer un caso benigno.
--
--     Medido el 13/9/2026 sobre el histórico completo: 211.314 entran completas, 33.470 entran sin
--     proyecto, 5.848 chocan con un estado que ya está, 161 son de legajos que no existen en BC y
--     CERO tienen un código de estado desconocido — los veinte códigos de Meta4 ya están en el
--     catálogo, incluidos ACC, DQ, LE y los AU* que el rango 2026 no mostraba.
SELECT
    CASE
        WHEN e.[Código]    IS NULL     THEN '1. NO ENTRA: código de estado inexistente'
        WHEN emp.[No_]     IS NULL     THEN '2. NO ENTRA: legajo inexistente como Employee'
        WHEN ee.[No_ Mov_] IS NOT NULL THEN '3. NO ENTRA: ya existe un estado ese día'
        WHEN t.Proyecto    IS NULL
          OR j.[No_]       IS NULL     THEN '4. ENTRA sin proyecto (el Job no existe en BC)'
        ELSE                                '5. ENTRA completa'
    END      AS Motivo,
    COUNT(*) AS Filas
FROM #Estados t
LEFT JOIN [dbo].[ArbuTest$Cód_ Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
       ON e.[Código] = t.CodEstado
LEFT JOIN [dbo].[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972] emp
       ON emp.[No_] = t.Legajo
LEFT JOIN [dbo].[ArbuTest$Job$437dbf0e-84ff-417a-965d-ed2bb9650972] j
       ON j.[No_] = t.Proyecto
LEFT JOIN [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
       ON ee.[No_ Empleado] = t.Legajo AND ee.[Fecha Inicio] = t.FechaInicio AND ee.[Tipo Entidad] = 0
GROUP BY
    CASE
        WHEN e.[Código]    IS NULL     THEN '1. NO ENTRA: código de estado inexistente'
        WHEN emp.[No_]     IS NULL     THEN '2. NO ENTRA: legajo inexistente como Employee'
        WHEN ee.[No_ Mov_] IS NOT NULL THEN '3. NO ENTRA: ya existe un estado ese día'
        WHEN t.Proyecto    IS NULL
          OR j.[No_]       IS NULL     THEN '4. ENTRA sin proyecto (el Job no existe en BC)'
        ELSE                                '5. ENTRA completa'
    END
ORDER BY 1;

-- 3.f.2 LOS DÍAS CON MÁS DE UN ESTADO EN EL ORIGEN.
--
--     Importa desde que el proyecto puede ir en blanco. La clave K1 es única por
--     (entidad, empleado, PROYECTO, fecha): mientras cada fila llevaba su marea, dos estados del
--     mismo día convivían; al blanquear el proyecto pasan a ser la misma clave y el INSERT entero
--     falla. El ROW_NUMBER del bloque 5 se queda con uno — "Descartadas" dice cuántos pierde.
--
--     Un número alto acá también explica por qué "ya existe un estado ese día" del 3.f puede ser
--     mayor que la cantidad de estados que hay en BC: varias filas del origen chocan contra la misma.
SELECT COUNT(*)                    AS DiasConMasDeUnEstado,
       SUM(Cuantos)                AS FilasInvolucradas,
       SUM(Cuantos) - COUNT(*)     AS FilasQueDescartaElDedup
FROM  (SELECT Legajo, FechaInicio, COUNT(*) AS Cuantos
       FROM   #Estados
       GROUP  BY Legajo, FechaInicio
       HAVING COUNT(*) > 1) x;

-- 3.g ¿EL LEGAJO VIAJA SIN LOS CEROS A LA IZQUIERDA?
--     Meta4 guarda ID_EMPLEADO como VARCHAR2, pero si el transporte pasó por Excel la columna se
--     tipa como número y '04850' llega como '4850'. Si esta consulta devuelve filas, ése es el
--     problema: el legajo existe en BC con padding y el JOIN no lo encuentra.
SELECT TOP 20 t.Legajo AS LegajoEnPuente, emp.[No_] AS LegajoEnBC
FROM #Estados t
JOIN [dbo].[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972] emp
  ON emp.[No_] = RIGHT('00000' + t.Legajo, 5)
WHERE NOT EXISTS (SELECT 1 FROM [dbo].[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972] e2
                  WHERE e2.[No_] = t.Legajo);
--     Si da filas, la corrección va en el bloque 2, sobre Base.Legajo:
--         RIGHT('00000' + LTRIM(RTRIM(m.LEGAJO)), 5)
--     y hay que rehacer #Estados antes de volver a insertar.

------------------------------------------------------------------------------------------------
-- 4. DIAGNÓSTICO — no bloquean, pero hay que mirarlos antes de insertar
------------------------------------------------------------------------------------------------

-- 4.a Las filas de relleno que se generaron, y contra qué hueco.
--     Los huecos de Meta4 ya no se tapan estirando el estado anterior —ver el bloque 2, FR es
--     franco gozado— sino con un OR propio. Esto muestra cuáles son, para poder contrastarlos con
--     RRHH: un hueco largo puede ser una licencia que nadie cargó, no días a la orden.
SELECT r.Legajo, r.FechaInicio AS DesdeRelleno, r.FechaFin AS HastaRelleno,
       DATEDIFF(day, r.FechaInicio, r.FechaFin) + 1 AS Dias,
       r.Proyecto, r.Observaciones
FROM #Estados r
WHERE r.Observaciones LIKE 'Generado por la migración%'
ORDER BY Dias DESC, r.Legajo;

-- 4.a.2 PISADAS: Meta4 cierra el estado DESPUÉS de que arranca el siguiente. Acá no hay relleno
--       posible —sobran días, no faltan— y el script se queda con el inicio del siguiente. Si son
--       muchas, el origen tiene solapamientos que conviene mirar.
SELECT Legajo, FechaInicio, CodEstado, FinM4, FechaFin AS FinCalculado
FROM #Estados
WHERE InicioSiguiente IS NOT NULL AND FinM4 IS NOT NULL
  AND FinM4 > DATEADD(day, -1, InicioSiguiente)
ORDER BY Legajo, FechaInicio;

-- 4.b Legajos cuyo último estado queda CERRADO. Después de esa fecha el empleado no tiene estado,
--     y el motor no liquida a alguien sin estado. Si son muchos, falta traer más rango de Meta4.
SELECT Legajo, MAX(FechaInicio) AS UltimoInicio, MAX(FechaFin) AS UltimoFin
FROM #Estados
GROUP BY Legajo
HAVING MAX(CASE WHEN FechaFin = '1753-01-01' THEN 1 ELSE 0 END) = 0
ORDER BY 1;

-- 4.c Estados que quedarían con fin ANTES del inicio: dos filas del mismo día en el origen.
SELECT * FROM #Estados
WHERE FechaFin <> '1753-01-01' AND FechaFin < FechaInicio
ORDER BY Legajo, FechaInicio;

------------------------------------------------------------------------------------------------
-- 5. LA INSERCIÓN — descomentar recién después de mirar los bloques 3 y 4
--
--     UN ESTADO SIN PROYECTO ENTRA IGUAL. Decisión del 13/9/2026, al traer el histórico completo:
--     no se declaran proyectos que no existen. Las mareas anteriores a 2010 nunca se cargaron en
--     BC y no se van a liquidar, así que crear 410 Jobs para sostenerlas es trabajo sin destino.
--     La fila entra con "No. Proyecto" en blanco —el campo lo admite, ver Tab60000— y el proyecto
--     que le habría correspondido queda escrito en la observación. No se inventa un dato y no se
--     pierde una fila; lo único que se resigna es poder filtrar esos estados viejos por marea.
--
--     Esto vale también para los buques sin traducir (E01, E02, YM, FM, KM, MEJ, SF: 4478 filas
--     entre 2002 y 2006) y para los casos sueltos en que Meta4 numera la marea distinto que NAV
--     —PP-128-000081 en enero de 2024, cuando el A28 en BC llega hasta la marea 62—.
--
--     LO QUE SÍ SIGUE SIENDO BLOQUEANTE es el bloque 3.a: el JOIN contra "Cód. Estado Empleado"
--     descarta en silencio las filas cuyo código no existe en el catálogo. Un estado sin código no
--     significa nada para el motor, y el catálogo es además el que dice si devenga francos. El
--     bloque 5.b lo cuenta después de insertar, que es la red por si el 3.a se miró por encima.
--
--     OJO CON LA TRANSACCIÓN ABIERTA. El COMMIT queda a mano a propósito —es la última chance de
--     revertir— pero entre el INSERT y tu decisión esta sesión mantiene BLOQUEADA Estado Empleado,
--     y BC deja de poder guardar cualquier cosa que la toque. El usuario ve "un registro se está
--     actualizando en una transacción realizada en otra sesión" sin ninguna pista de que el
--     culpable es una pestaña de SQL.
--
--     Si el INSERT falla, la transacción NO se cierra sola. Cerrala antes de ir a mirar el error.
------------------------------------------------------------------------------------------------
SELECT @@TRANCOUNT AS TransaccionesAbiertasEnEstaSesion;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

/*
BEGIN TRANSACTION;

-- El ROW_NUMBER no es decorativo. La clave K1 de "Estado Empleado" es
-- (Tipo Entidad, No. Empleado, No. Proyecto, Fecha Inicio) y es ÚNICA. Mientras cada fila llevaba
-- su proyecto, dos estados del mismo día se distinguían por ahí; al blanquear el proyecto dejan de
-- distinguirse y el INSERT entero falla por violación de índice. Se queda el que tiene marea, que
-- es el que más información trae.
WITH Dedup AS (
    SELECT t.*,
           ROW_NUMBER() OVER (PARTITION BY t.Legajo, t.FechaInicio
                              ORDER BY CASE WHEN t.Proyecto LIKE 'PP-%' THEN 0 ELSE 1 END,
                                       t.Proyecto) AS Orden
    FROM #Estados t
)
INSERT INTO [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
    -- Sin [No_ Mov_]: es AutoIncrement, o sea IDENTITY del lado de SQL.
    -- Sin [Descripción Estado]: es FlowField y no existe como columna.
    ([No_ Empleado], [Fecha Inicio], [Cód_ Estado], [Fecha Fin],
     [Observaciones], [No_ Proyecto], [Tipo Entidad],
     [$systemId], [$systemCreatedAt], [$systemCreatedBy], [$systemModifiedAt], [$systemModifiedBy])
SELECT
    t.Legajo,
    t.FechaInicio,
    t.CodEstado,
    t.FechaFin,
    -- La observación es lo único que queda del proyecto perdido: que diga cuál era y por qué no
    -- está. En BC el campo es Text[250], así que se corta acá y no en la inserción.
    CASE WHEN j.[No_] IS NULL
         THEN LEFT(CASE WHEN t.Observaciones = '' THEN '' ELSE t.Observaciones + ' | ' END
                   + 'Migración: sin proyecto en BC ('
                   + ISNULL(t.Proyecto, 'buque ' + ISNULL(t.BuqueM4, '?') + ' sin traducción')
                   + ').', 250)
         ELSE t.Observaciones
    END,
    CASE WHEN j.[No_] IS NULL THEN '' ELSE t.Proyecto END,
    0,                                   -- Tipo Entidad = Empleado
    NEWID(), SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000',
             SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000'
FROM Dedup t
JOIN [dbo].[ArbuTest$Cód_ Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
  ON e.[Código] = t.CodEstado
-- LEFT, no JOIN: el proyecto que no existe blanquea el campo, no descarta la fila.
LEFT JOIN [dbo].[ArbuTest$Job$437dbf0e-84ff-417a-965d-ed2bb9650972] j
  ON j.[No_] = t.Proyecto
WHERE t.Orden = 1
  AND EXISTS (SELECT 1 FROM [dbo].[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972] emp
              WHERE emp.[No_] = t.Legajo)
  AND NOT EXISTS (SELECT 1 FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
                  WHERE ee.[No_ Empleado] = t.Legajo
                    AND ee.[Fecha Inicio] = t.FechaInicio
                    AND ee.[Tipo Entidad] = 0);

PRINT 'Filas insertadas: ' + CAST(@@ROWCOUNT AS varchar(10));

-- Si el número cierra con el bloque 1:   COMMIT TRANSACTION;
-- Si no cierra, o el INSERT falló:       ROLLBACK TRANSACTION;
*/

------------------------------------------------------------------------------------------------
-- 5.b LA CONCILIACIÓN — correr DESPUÉS del COMMIT.
--
--     Cada fila de #Estados cae en una de estas categorías y la suma da el total del bloque 2. Es
--     la red contra el descarte silencioso: si "código de estado inexistente" no da cero, faltan
--     altas en el catálogo y esas personas quedaron con un agujero en su historia que nadie marcó.
------------------------------------------------------------------------------------------------
/*
WITH Clasificada AS (
    SELECT CASE
             WHEN NOT EXISTS (SELECT 1 FROM [dbo].[ArbuTest$Cód_ Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
                              WHERE e.[Código] = t.CodEstado)
                  THEN 'Descartada: código de estado inexistente'
             WHEN NOT EXISTS (SELECT 1 FROM [dbo].[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972] emp
                              WHERE emp.[No_] = t.Legajo)
                  THEN 'Descartada: legajo inexistente'
             WHEN EXISTS (SELECT 1 FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
                          WHERE ee.[No_ Empleado] = t.Legajo AND ee.[Fecha Inicio] = t.FechaInicio
                            AND ee.[Tipo Entidad] = 0 AND ee.[Cód_ Estado] = t.CodEstado)
                  THEN 'Insertada (o ya estaba)'
             ELSE 'REVISAR: no entró y no hay motivo conocido'
           END AS Resultado
    FROM #Estados t
)
SELECT Resultado, COUNT(*) AS Filas FROM Clasificada GROUP BY Resultado ORDER BY 2 DESC;

-- Y cuántas quedaron sin proyecto, que es el precio conocido de la decisión.
SELECT COUNT(*) AS EstadosSinProyecto
FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
WHERE [Tipo Entidad] = 0 AND [No_ Proyecto] = '';
*/

------------------------------------------------------------------------------------------------
-- 6. RECALCULAR LA CONTIGÜIDAD DE TODO EL HISTORIAL — correr DESPUÉS del COMMIT
--
--     Por qué hace falta: MigrarFasesAlta_2 calculó su "Fecha Fin" con un LEAD sobre las filas de
--     fases nada más. Al meter estados en el medio, esos cierres apuntan a la fila equivocada —un
--     ALT que se creía abierto hasta la baja ahora tiene un NV adentro—. Este bloque recalcula el
--     fin de TODAS las filas, mirando el historial completo.
--
--     UN ESTADO TERMINA EL DÍA ANTES DEL SIGUIENTE, O EL DÍA DE LA BAJA DE SU FASE, LO QUE PASE
--     PRIMERO. La segunda mitad de esa regla faltaba, y el síntoma apareció el 13/9/2026 en "Días
--     Liquidados por Empleado": 2.879 empleados con 89.104 días sin liquidar, cuando los activos
--     son unos 330. El legajo 00040 tiene su fase cerrada el 9/3/2011 y un AU9 Vacaciones que
--     arranca ese mismo día; sin siguiente estado, el LEAD lo dejaba ABIERTO y para el control esa
--     persona seguía de vacaciones quince años después de irse.
--
--     El mismo error tiene una segunda forma, menos visible: un estado de la fase 1 cuyo estado
--     siguiente está en la fase 3 se estiraba por encima del hueco entre fases, cubriendo años en
--     que la persona no trabajó en la empresa. Acotar por la baja de la fase arregla los dos.
--
--     Es idempotente: correrlo dos veces da lo mismo. NO necesita #Estados —el filtro por los
--     legajos tocados quedó comentado abajo— así que sirve para reparar la base en cualquier
--     momento, no sólo dentro de la sesión de migración.
------------------------------------------------------------------------------------------------
/*
BEGIN TRANSACTION;

WITH Hist AS (
    SELECT ee.[No_ Mov_]     AS NoMov,
           ee.[No_ Empleado] AS Legajo,
           ee.[Fecha Inicio] AS Inicio,
           DATEADD(day, -1, LEAD(ee.[Fecha Inicio]) OVER (PARTITION BY ee.[No_ Empleado]
                                                          ORDER BY ee.[Fecha Inicio])) AS FinPorSiguiente
    FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
    WHERE ee.[Tipo Entidad] = 0
      -- Para acotarlo a los legajos de esta migración, descomentar (necesita #Estados vivo):
      -- AND EXISTS (SELECT 1 FROM #Estados t WHERE t.Legajo = ee.[No_ Empleado])
),
ConTope AS (
    SELECT h.NoMov, h.FinPorSiguiente,
           -- La baja de la fase que cubre el inicio del estado. NULL si la fase está abierta, o si
           -- el estado no cae en ninguna fase —los ~68 marcados por el 2.b.4—: ahí no hay tope que
           -- aplicar y manda el estado siguiente, como antes.
           f.[Fecha Baja] AS TopeFase
    FROM   Hist h
    LEFT JOIN [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
           ON  f.[No_ Empleado] = h.Legajo
           AND f.[Fecha Alta]  <= h.Inicio
           AND f.[Fecha Baja]  <> '1753-01-01'
           AND f.[Fecha Baja]  >= h.Inicio
),
Final AS (
    SELECT NoMov,
           CASE
             -- Sin fase cerrada que lo cubra: como siempre, el día antes del siguiente, o abierto.
             WHEN TopeFase IS NULL
                  THEN COALESCE(FinPorSiguiente, '1753-01-01')
             -- Último estado de una fase cerrada: cierra con la baja.
             WHEN FinPorSiguiente IS NULL
                  THEN TopeFase
             -- Hay siguiente, pero cae después de la baja: el siguiente pertenece a otra fase.
             WHEN FinPorSiguiente > TopeFase
                  THEN TopeFase
             ELSE FinPorSiguiente
           END AS FinCorrecto
    FROM ConTope
)
UPDATE ee
   SET ee.[Fecha Fin]         = f.FinCorrecto,
       ee.[$systemModifiedAt] = SYSUTCDATETIME()
FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
JOIN Final f ON f.NoMov = ee.[No_ Mov_]
WHERE ee.[Fecha Fin] <> f.FinCorrecto;

PRINT 'Fechas Fin corregidas: ' + CAST(@@ROWCOUNT AS varchar(10));

-- COMMIT TRANSACTION;  /  ROLLBACK TRANSACTION;
*/

-- 6.b CUÁNTOS ESTADOS QUEDAN ABIERTOS. Es el control que delata el problema de arriba sin tener
--     que abrir una ficha: sólo los empleados con una fase ABIERTA pueden tener un estado abierto.
--
--     La clasificación se calcula en una CTE. Repetir el CASE con su subconsulta en el GROUP BY es
--     el Msg 144 ("Cannot use an aggregate or a subquery in an expression used for the group by
--     list"), que en este script ya apareció tres veces.
WITH Abiertos AS (
    SELECT ee.[No_ Empleado] AS Legajo,
           CASE WHEN EXISTS (SELECT 1 FROM [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
                             WHERE f.[No_ Empleado] = ee.[No_ Empleado]
                               AND f.[Fecha Baja] = '1753-01-01')
                THEN 'Correcto: tiene una fase abierta'
                ELSE 'MAL: estado abierto sin fase abierta' END AS Situacion
    FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
    WHERE ee.[Tipo Entidad] = 0 AND ee.[Fecha Fin] = '1753-01-01'
)
SELECT Situacion, COUNT(*) AS Estados, COUNT(DISTINCT Legajo) AS Legajos
FROM   Abiertos
GROUP  BY Situacion
ORDER  BY Situacion;
-- Después del bloque 6 corregido, "MAL" tiene que dar CERO y los correctos deben andar por los 330
-- legajos con fase abierta.

-- 6.c ESTADOS QUE SE PASAN DE LA BAJA DE SU FASE. Tiene que dar CERO después del bloque 6.
SELECT COUNT(*) AS EstadosQueSePasanDeLaBaja
FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
JOIN [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
     ON  f.[No_ Empleado] = ee.[No_ Empleado]
     AND f.[Fecha Alta]  <= ee.[Fecha Inicio]
     AND f.[Fecha Baja]  <> '1753-01-01'
     AND f.[Fecha Baja]  >= ee.[Fecha Inicio]
WHERE ee.[Tipo Entidad] = 0
  AND (ee.[Fecha Fin] = '1753-01-01' OR ee.[Fecha Fin] > f.[Fecha Baja]);

-- 6.d EMPLEADOS ACTIVOS SIN ESTADO VIGENTE. Es el control que más duele en la liquidación.
--
--     Una fase abierta sin un estado abierto significa que la persona está en la empresa pero su
--     historial se corta en alguna fecha pasada. El motor no lo tolera: ValidarEstadoExiste corta
--     con error al liquidar (Cod50014, en ValidarFormulas), así que esa persona no sale en el lote
--     y el error aparece recién cuando alguien mira por qué faltan recibos.
--
--     Medido el 13/9/2026 después del bloque 6: 276 estados abiertos contra ~330 fases abiertas.
--     La diferencia es esto.
--
--     El arreglo no es automático: hay que decidir qué estado le corresponde a cada uno desde que
--     se le cortó el historial. Si es gente a la orden en tierra, va un OR desde el día siguiente
--     al último estado cerrado; si volvió a embarcar, el estado sale de la marea.
SELECT f.[No_ Empleado],
       f.[Fecha Alta]                 AS AltaVigente,
       MAX(ee.[Fecha Fin])            AS UltimoEstadoHasta,
       DATEDIFF(day, MAX(ee.[Fecha Fin]), CAST(GETDATE() AS date)) AS DiasSinEstado,
       COUNT(ee.[No_ Mov_])           AS EstadosEnLaFase
FROM [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
LEFT JOIN [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
       ON  ee.[No_ Empleado] = f.[No_ Empleado]
       AND ee.[Tipo Entidad] = 0
       AND ee.[Fecha Inicio] >= f.[Fecha Alta]
WHERE f.[Fecha Baja] = '1753-01-01'
  AND NOT EXISTS (SELECT 1 FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e2
                  WHERE e2.[No_ Empleado] = f.[No_ Empleado]
                    AND e2.[Tipo Entidad] = 0
                    AND e2.[Fecha Fin]    = '1753-01-01')
GROUP BY f.[No_ Empleado], f.[Fecha Alta]
ORDER BY DiasSinEstado DESC;
-- EstadosEnLaFase = 0 es el caso grave: entró y no tiene NINGÚN estado, ni siquiera uno cerrado.
------------------------------------------------------------------------------------------------
-- 7. VERIFICACIÓN POSTERIOR
------------------------------------------------------------------------------------------------

-- 7.a Lo que quedó cargado, por estado.
SELECT ee.[Cód_ Estado], COUNT(*) AS Filas
FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
WHERE ee.[Tipo Entidad] = 0 AND ee.[Fecha Inicio] >= '2026-01-01'
GROUP BY ee.[Cód_ Estado] ORDER BY 2 DESC;

-- 7.b Huecos: un estado cerrado cuyo día siguiente no arranca ninguno. Tiene que dar CERO.
WITH H AS (
    SELECT ee.[No_ Empleado] AS Legajo, ee.[Fecha Inicio] AS Inicio, ee.[Fecha Fin] AS Fin,
           LEAD(ee.[Fecha Inicio]) OVER (PARTITION BY ee.[No_ Empleado] ORDER BY ee.[Fecha Inicio]) AS Sig
    FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
    WHERE ee.[Tipo Entidad] = 0
)
SELECT * FROM H WHERE Sig IS NOT NULL AND Fin <> DATEADD(day, -1, Sig) ORDER BY Legajo, Inicio;

-- 7.c Dos estados el mismo día para el mismo empleado. Tiene que dar CERO.
SELECT [No_ Empleado], [Fecha Inicio], COUNT(*) AS Cuantos
FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
WHERE [Tipo Entidad] = 0
GROUP BY [No_ Empleado], [Fecha Inicio] HAVING COUNT(*) > 1;

-- 7.d Estados cuyo proyecto no existe. Tiene que dar CERO.
SELECT ee.[No_ Proyecto], COUNT(*) AS Filas
FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
WHERE ee.[Tipo Entidad] = 0 AND ee.[No_ Proyecto] <> ''
  AND NOT EXISTS (SELECT 1 FROM [dbo].[ArbuTest$Job$437dbf0e-84ff-417a-965d-ed2bb9650972] j
                  WHERE j.[No_] = ee.[No_ Proyecto])
GROUP BY ee.[No_ Proyecto];
