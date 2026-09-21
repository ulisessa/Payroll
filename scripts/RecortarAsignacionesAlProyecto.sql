/*
    LA ASIGNACIÓN NO PUEDE DURAR MÁS QUE EL PROYECTO

    Nadie sigue asignado a una marea después de que la marea terminó. El legajo 00191 figura en
    PP-118-000323 hasta el 27/5/2026; hay que ver hasta cuándo duró esa marea.

    DE DÓNDE SALE. MigrarPersonalProyecto_4 deriva las fechas del PRIMER y del ÚLTIMO estado del
    empleado en ese proyecto. Como "Personal Proyecto" admite una sola fila por par empleado+proyecto
    —así lo fija su clave primaria—, el que estuvo en el mismo barco en dos temporadas quedó con una
    asignación única que va del primer embarque al último desembarque, meses después del arribo.

    POR QUÉ IMPORTA. La selección del lote filtra por estas fechas. Una baja de más mete a la persona
    en períodos en los que ese proyecto ya no existía.

    De acá en adelante lo sostiene la tabla: "Personal Proyecto".ValidarBajaDentroDelProyecto, en
    OnInsert y OnModify. Este script arregla lo ya escrito.

    Bloques 1 a 3 leen. El UPDATE del bloque 4 está comentado.
*/

USE [Migr2013R2];
GO
SET NOCOUNT ON;
GO

SELECT 'Conexión correcta: SQL Server — base ' + DB_NAME() AS GUARDIAN;

------------------------------------------------------------------------------------------------
-- 0. ¿QUÉ PASOS SE CORRIERON? — correr ESTO primero, siempre
------------------------------------------------------------------------------------------------
-- Las tres consultas de abajo miden el estado de la limpieza, no los datos. Sirven porque medir el
-- caso 1 o el caso 3 en un estado intermedio da números que no significan nada — ya pasó una vez,
-- con una lectura del bloque 1.b que llevó a una conclusión equivocada.
--
-- Las tres tienen que dar CERO para que el resto del script sea interpretable.
--
-- EXCEPCIÓN CONOCIDA DESDE EL 15/9/2026, y es importante NO "arreglarla". La migración de
-- ausentismos (MigrarAusentismos_2) cargó 3.839 estados de administrativos desde el año 2000, y 690
-- de ellos apuntan a un PN-ADM-*. Las asignaciones a esos proyectos arrancan el 1/1/2026 —se
-- crearon para el personal activo, no como historia— así que el paso 1 de acá las va a marcar como
-- pendientes: sus fechas no salen de sus estados.
--
-- ESO ES CORRECTO Y HAY QUE DEJARLO ASÍ. Correr el bloque 5 de MoverEstadosDeTierraANomina para
-- "corregirlo" llevaría esas asignaciones para atrás hasta 2000, atribuyéndole al proyecto de
-- nómina una antigüedad que no tuvo — y de esas fechas sale la ventana que el motor usa para contar
-- días. Un control que deja de dar cero no siempre pide una corrección: a veces pide una nota.
WITH PorPar AS (
    SELECT e.[No_ Empleado] AS Emp, e.[No_ Proyecto] AS Proy,
           MIN(e.[Fecha Inicio]) AS Desde,
           -- Misma regla que el bloque 5 de MoverEstadosDeTierraANomina: si algún estado del par
           -- quedó abierto, la asignación queda abierta.
           CASE WHEN MAX(CASE WHEN e.[Fecha Fin] = '1753-01-01' THEN 1 ELSE 0 END) = 1
                THEN '1753-01-01'
                ELSE MAX(e.[Fecha Fin]) END AS Hasta
    FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
    WHERE  e.[Tipo Entidad] = 0 AND e.[No_ Proyecto] <> ''
    GROUP  BY e.[No_ Empleado], e.[No_ Proyecto]
)
SELECT '1. Bloque 5 UPDATE — asignaciones con fechas que no salen de sus estados' AS Paso,
       COUNT(*) AS Pendientes
FROM   [dbo].[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
JOIN   PorPar p ON p.Emp = pp.[No_ Empleado] AND p.Proy = pp.[No_ Proyecto]
WHERE  pp.[Fecha Alta Asignación] <> p.Desde OR pp.[Fecha Baja] <> p.Hasta

UNION ALL
SELECT '2. Bloque 5.c DELETE — asignaciones de la migración sin ningún estado',
       COUNT(*)
FROM   [dbo].[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
WHERE  pp.[Observaciones] LIKE 'Generado por la migración%'
  AND  NOT EXISTS (
           SELECT 1 FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
           WHERE e.[Tipo Entidad] = 0
             AND e.[No_ Empleado] = pp.[No_ Empleado]
             AND e.[No_ Proyecto] = pp.[No_ Proyecto])

UNION ALL
SELECT '3. MigrarPersonalProyecto_4 — pares empleado+proyecto con estados y sin asignación',
       COUNT(*)
FROM   (SELECT DISTINCT e.[No_ Empleado] AS Emp, e.[No_ Proyecto] AS Proy
        FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
        WHERE  e.[Tipo Entidad] = 0 AND e.[No_ Proyecto] <> '') d
WHERE  NOT EXISTS (
           SELECT 1 FROM [dbo].[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
           WHERE pp.[No_ Empleado] = d.Emp AND pp.[No_ Proyecto] = d.Proy);

------------------------------------------------------------------------------------------------
-- 1. VOLUMEN — cuántas asignaciones se pasan del fin de su proyecto
------------------------------------------------------------------------------------------------
-- Se separan tres casos porque no se arreglan igual:
--   · "Baja posterior al arribo"        → se recorta la baja al arribo.
--   · "Sigue abierta y el proyecto cerró" → la baja está en blanco pero la marea ya llegó: también
--                                          se cierra en el arribo.
--   · "Empieza después del arribo"      → la asignación entera es posterior al proyecto. Recortar
--                                          la baja daría un intervalo invertido: va aparte.
WITH Casos AS (
    SELECT pp.[No_ Empleado] AS Emp, pp.[No_ Proyecto] AS Proy,
           pp.[Fecha Alta Asignación] AS Alta, pp.[Fecha Baja] AS Baja,
           j.[Ending Date] AS Arribo,
           CASE WHEN pp.[Fecha Alta Asignación] > j.[Ending Date]
                     THEN '3. Empieza después del arribo'
                WHEN pp.[Fecha Baja] = '1753-01-01'
                     THEN '2. Sigue abierta y el proyecto cerró'
                ELSE      '1. Baja posterior al arribo' END AS Caso
    FROM   [dbo].[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
    JOIN   [dbo].[ArbuTest$Job$437dbf0e-84ff-417a-965d-ed2bb9650972] j
           ON j.[No_] = pp.[No_ Proyecto]
    WHERE  j.[Ending Date] <> '1753-01-01'
      AND  (pp.[Fecha Baja] = '1753-01-01' OR pp.[Fecha Baja] > j.[Ending Date])
)
-- El CASE se calcula en el CTE: dentro del GROUP BY sería el Msg 144.
SELECT Caso,
       COUNT(*)            AS Asignaciones,
       COUNT(DISTINCT Emp) AS Empleados,
       COUNT(DISTINCT Proy) AS Proyectos,
       MAX(DATEDIFF(day, Arribo, CASE WHEN Baja = '1753-01-01' THEN Arribo ELSE Baja END)) AS MaxDiasDeMas
FROM   Casos
GROUP  BY Caso
ORDER  BY Caso;

------------------------------------------------------------------------------------------------
-- 1.b ¿POR QUÉ SE PASA LA BAJA? — el último estado de esa asignación, con su fin y el que sigue
------------------------------------------------------------------------------------------------
-- DESPUÉS DE MOVER LOS GP/DQ/PI el caso 3 cayó de 5.186 a 58, pero el caso 1 apenas bajó: 7.690 a
-- 7.457, con 3.360 todavía entre uno y doce meses. Eso no debería poder pasar: en un proyecto de
-- marea ya sólo quedan NV, PS y PL, y PL nunca se pasa de tres días del arribo.
--
-- LA HIPÓTESIS es la contigüidad. "Fecha Fin" no es cuándo terminó ese estado: es el día anterior al
-- estado SIGUIENTE del empleado, en cualquier proyecto. Si después del desembarco no hubo ningún
-- estado durante meses, el último estado de marea se estira solo hasta que aparece el próximo, y el
-- bloque 5 copia esa fecha a la asignación.
--
-- ESTO LO CONFIRMA O LO DESCARTA. Por cada asignación que se pasa, muestra el último estado de ese
-- proyecto —código, inicio, fin— y el primer estado del empleado posterior a ese fin. Si la fecha de
-- baja coincide con "el día antes del siguiente", es la contigüidad y se arregla en el bloque 5,
-- tomando el fin REAL del estado y no el derivado. Si no coincide, es otra cosa.
WITH Pasadas AS (
    SELECT pp.[No_ Empleado] AS Emp, pp.[No_ Proyecto] AS Proy, pp.[Fecha Baja] AS Baja,
           j.[Ending Date] AS Arribo
    FROM   [dbo].[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
    JOIN   [dbo].[ArbuTest$Job$437dbf0e-84ff-417a-965d-ed2bb9650972] j ON j.[No_] = pp.[No_ Proyecto]
    WHERE  j.[Ending Date] <> '1753-01-01'
      AND  pp.[Fecha Baja] <> '1753-01-01'
      AND  pp.[Fecha Baja] > j.[Ending Date]
      AND  DATEDIFF(day, j.[Ending Date], pp.[Fecha Baja]) > 3   -- el borde de PL no interesa acá
),
UltimoDelProyecto AS (
    SELECT p.Emp, p.Proy, p.Baja, p.Arribo,
           e.[Cód_ Estado] AS UltCod, e.[Fecha Inicio] AS UltInicio, e.[Fecha Fin] AS UltFin,
           ROW_NUMBER() OVER (PARTITION BY p.Emp, p.Proy ORDER BY e.[Fecha Inicio] DESC) AS Orden
    FROM   Pasadas p
    JOIN   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
           ON e.[Tipo Entidad] = 0 AND e.[No_ Empleado] = p.Emp AND e.[No_ Proyecto] = p.Proy
),
ConSiguiente AS (
    SELECT u.*,
           -- El primer estado del empleado en CUALQUIER proyecto después de este. Es contra éste
           -- que la contigüidad estiró la fecha fin.
           (SELECT MIN(e2.[Fecha Inicio])
              FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e2
             WHERE e2.[Tipo Entidad] = 0
               AND e2.[No_ Empleado] = u.Emp
               AND e2.[Fecha Inicio] > u.UltInicio) AS SiguienteInicio
    FROM   UltimoDelProyecto u
    WHERE  u.Orden = 1
),
-- LA COMPARACIÓN QUE IMPORTA es entre la BAJA DE LA ASIGNACIÓN y el fin del último estado de ese
-- proyecto. La primera versión de esta consulta comparaba "Fecha Fin" contra el día anterior al
-- estado siguiente, y eso es verdadero también en el caso normal —así se construye la contigüidad—
-- así que clasificaba como sospechoso a todo y no distinguía nada. El resultado (3.268 PL, 1.629 NV)
-- no significaba lo que el nombre de la categoría decía.
Diagnostico AS (
    SELECT Emp, Proy, Baja, Arribo, UltCod, UltInicio, UltFin, SiguienteInicio,
           CASE WHEN Baja = UltFin
                     THEN '1. La baja YA coincide con el último estado (el exceso es real)'
                WHEN Baja > UltFin
                     THEN '2. La baja va MÁS ALLÁ del último estado (falta correr el bloque 5)'
                ELSE      '3. La baja queda ANTES del último estado (revisar a mano)'
                END AS Causa
    FROM   ConSiguiente
)
SELECT Causa, UltCod AS UltimoEstado, COUNT(*) AS Asignaciones,
       MAX(DATEDIFF(day, Arribo, Baja))  AS MaxDiasDesdeElArribo,
       MAX(DATEDIFF(day, UltFin, Baja))  AS MaxDiasSobrantes
FROM   Diagnostico
GROUP  BY Causa, UltCod
ORDER  BY Causa, COUNT(*) DESC;

-- 1.b.2 Veinte casos concretos, los que más se pasan.
WITH Pasadas AS (
    SELECT pp.[No_ Empleado] AS Emp, pp.[No_ Proyecto] AS Proy, pp.[Fecha Baja] AS Baja,
           j.[Ending Date] AS Arribo
    FROM   [dbo].[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
    JOIN   [dbo].[ArbuTest$Job$437dbf0e-84ff-417a-965d-ed2bb9650972] j ON j.[No_] = pp.[No_ Proyecto]
    WHERE  j.[Ending Date] <> '1753-01-01'
      AND  pp.[Fecha Baja] <> '1753-01-01'
      AND  pp.[Fecha Baja] > j.[Ending Date]
      AND  DATEDIFF(day, j.[Ending Date], pp.[Fecha Baja]) > 3
),
UltimoDelProyecto AS (
    SELECT p.Emp, p.Proy, p.Baja, p.Arribo,
           e.[Cód_ Estado] AS UltCod, e.[Fecha Inicio] AS UltInicio, e.[Fecha Fin] AS UltFin,
           ROW_NUMBER() OVER (PARTITION BY p.Emp, p.Proy ORDER BY e.[Fecha Inicio] DESC) AS Orden
    FROM   Pasadas p
    JOIN   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
           ON e.[Tipo Entidad] = 0 AND e.[No_ Empleado] = p.Emp AND e.[No_ Proyecto] = p.Proy
)
SELECT TOP 20
       u.Emp AS Legajo, u.Proy AS Proyecto, u.Arribo, u.Baja AS BajaAsignacion,
       u.UltCod AS UltimoEstado, u.UltInicio AS EstadoDesde, u.UltFin AS EstadoHasta,
       (SELECT MIN(e2.[Fecha Inicio])
          FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e2
         WHERE e2.[Tipo Entidad] = 0 AND e2.[No_ Empleado] = u.Emp
           AND e2.[Fecha Inicio] > u.UltInicio) AS SiguienteEstado,
       DATEDIFF(day, u.Arribo, u.Baja) AS DiasDeMas
FROM   UltimoDelProyecto u
WHERE  u.Orden = 1
ORDER  BY DiasDeMas DESC;

------------------------------------------------------------------------------------------------
-- 2. POR CUÁNTO SE PASAN — para saber si es un borde o son meses
------------------------------------------------------------------------------------------------
WITH Exceso AS (
    SELECT DATEDIFF(day, j.[Ending Date], pp.[Fecha Baja]) AS DiasDeMas
    FROM   [dbo].[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
    JOIN   [dbo].[ArbuTest$Job$437dbf0e-84ff-417a-965d-ed2bb9650972] j
           ON j.[No_] = pp.[No_ Proyecto]
    WHERE  j.[Ending Date] <> '1753-01-01'
      AND  pp.[Fecha Baja] <> '1753-01-01'
      AND  pp.[Fecha Baja] > j.[Ending Date]
),
Bucket AS (
    SELECT CASE WHEN DiasDeMas = 1    THEN '1 día'
                WHEN DiasDeMas <= 7   THEN '2 a 7 días'
                WHEN DiasDeMas <= 31  THEN '8 a 31 días'
                WHEN DiasDeMas <= 365 THEN '1 a 12 meses'
                ELSE                       'más de un año' END AS Tramo,
           DiasDeMas
    FROM   Exceso
)
SELECT Tramo, COUNT(*) AS Asignaciones, MIN(DiasDeMas) AS Min_, MAX(DiasDeMas) AS Max_
FROM   Bucket
GROUP  BY Tramo
ORDER  BY MIN(DiasDeMas);

------------------------------------------------------------------------------------------------
-- 3. EL DETALLE — las peores primero
------------------------------------------------------------------------------------------------
SELECT TOP 100
       pp.[No_ Empleado] AS Legajo,
       em.[First Name] + ' ' + em.[Last Name] AS Nombre,
       pp.[No_ Proyecto] AS Proyecto,
       j.[Starting Date] AS ProyectoDesde,
       j.[Ending Date]   AS ProyectoHasta,
       pp.[Fecha Alta Asignación] AS AsigDesde,
       CASE WHEN pp.[Fecha Baja] = '1753-01-01' THEN NULL ELSE pp.[Fecha Baja] END AS AsigHasta,
       DATEDIFF(day, j.[Ending Date],
                CASE WHEN pp.[Fecha Baja] = '1753-01-01' THEN j.[Ending Date] ELSE pp.[Fecha Baja] END) AS DiasDeMas
FROM   [dbo].[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
JOIN   [dbo].[ArbuTest$Job$437dbf0e-84ff-417a-965d-ed2bb9650972] j
       ON j.[No_] = pp.[No_ Proyecto]
LEFT JOIN [dbo].[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972] em
       ON em.[No_] = pp.[No_ Empleado]
WHERE  j.[Ending Date] <> '1753-01-01'
  AND  (pp.[Fecha Baja] = '1753-01-01' OR pp.[Fecha Baja] > j.[Ending Date])
ORDER  BY DiasDeMas DESC, pp.[No_ Empleado];

------------------------------------------------------------------------------------------------
-- 3.b ANTES DE RECORTAR: ¿ES LA MAREA CORRECTA?
------------------------------------------------------------------------------------------------
-- LO QUE ENCONTRÓ EL BLOQUE 3 no parece una fecha mal calculada. PP-128-000002 va del 4/4/2007 al
-- 7/5/2007 y tiene asignaciones hasta el 17/2/2011; PP-126-000048 va del 5/4/2013 al 30/4/2013 y
-- tiene tripulación del 7/1/2024. Una marea de 33 días no lleva gente cuatro años después: esa
-- gente no estuvo en esa marea.
--
-- LA SOSPECHA. MigrarEstados_1 arma el proyecto como PP-<buque>-<ID_MAREA a 6 dígitos>. Si el
-- ID_MAREA de Meta4 se reinicia o se reutiliza a lo largo de 27 años, la marea 2 del buque 128 de
-- 2007 y la marea 2 de 2010 caen en el MISMO proyecto de BC. Con el rango enero-junio 2026 que se
-- probó al principio no se notaba; con el histórico completo colisiona.
--
-- POR QUÉ HAY QUE MIRARLO ANTES DEL RECORTE. Si la marea está mal, recortar la baja al arribo deja
-- las asignaciones prolijas y la gente en el barco equivocado: esconde el problema en vez de
-- resolverlo.
--
-- CÓMO SE LEE. Un proyecto con estados repartidos en varias "épocas" separadas por años es una
-- colisión. Uno con estados que se pasan unos días del arribo es un borde y no tiene nada de raro.
WITH PorProyecto AS (
    SELECT e.[No_ Proyecto] AS Proy,
           COUNT(*)                      AS Estados,
           COUNT(DISTINCT e.[No_ Empleado]) AS Empleados,
           MIN(e.[Fecha Inicio])         AS PrimerEstado,
           MAX(e.[Fecha Inicio])         AS UltimoEstado,
           DATEDIFF(day, MIN(e.[Fecha Inicio]), MAX(e.[Fecha Inicio])) AS SpanDias
    FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
    WHERE  e.[Tipo Entidad] = 0
      AND  e.[No_ Proyecto] LIKE 'PP-%'
    GROUP  BY e.[No_ Proyecto]
),
ConJob AS (
    SELECT p.Proy, p.Estados, p.Empleados, p.PrimerEstado, p.UltimoEstado, p.SpanDias,
           j.[Starting Date] AS JobDesde, j.[Ending Date] AS JobHasta,
           DATEDIFF(day, j.[Starting Date], j.[Ending Date]) AS DuracionMarea
    FROM   PorProyecto p
    JOIN   [dbo].[ArbuTest$Job$437dbf0e-84ff-417a-965d-ed2bb9650972] j ON j.[No_] = p.Proy
    WHERE  j.[Ending Date] <> '1753-01-01' AND j.[Starting Date] <> '1753-01-01'
),
Clasificado AS (
    SELECT Proy, Estados, Empleados, SpanDias, DuracionMarea,
           CASE WHEN SpanDias > DuracionMarea + 365 THEN '3. COLISIÓN — estados de más de un año fuera de la marea'
                WHEN SpanDias > DuracionMarea + 31  THEN '2. Sospechoso — más de un mes fuera'
                ELSE                                     '1. Normal' END AS Diagnostico
    FROM   ConJob
)
SELECT Diagnostico, COUNT(*) AS Proyectos, SUM(Estados) AS Estados, MAX(SpanDias) AS MaxSpanDias
FROM   Clasificado
GROUP  BY Diagnostico
ORDER  BY Diagnostico;

-- 3.c LAS PEORES, CON LAS ÉPOCAS A LA VISTA.
--     Si un proyecto tiene estados en 2007 y en 2011 y nada en el medio, son dos mareas distintas
--     con el mismo número. Si están repartidos de forma continua, es otra cosa.
SELECT TOP 30
       e.[No_ Proyecto] AS Proyecto,
       j.[Starting Date] AS MareaDesde, j.[Ending Date] AS MareaHasta,
       YEAR(e.[Fecha Inicio]) AS Anio,
       COUNT(*) AS Estados,
       COUNT(DISTINCT e.[No_ Empleado]) AS Empleados
FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
JOIN   [dbo].[ArbuTest$Job$437dbf0e-84ff-417a-965d-ed2bb9650972] j ON j.[No_] = e.[No_ Proyecto]
WHERE  e.[Tipo Entidad] = 0
  AND  e.[No_ Proyecto] IN ('PP-128-000002', 'PP-126-000048', 'PP-117-000086', 'PP-127-000008')
GROUP  BY e.[No_ Proyecto], j.[Starting Date], j.[Ending Date], YEAR(e.[Fecha Inicio])
ORDER  BY e.[No_ Proyecto], YEAR(e.[Fecha Inicio]);

------------------------------------------------------------------------------------------------
-- 3.d LOS 34.408 "SOSPECHOSOS" — ¿son la preparación del barco o son otra cosa?
------------------------------------------------------------------------------------------------
-- EL 3.b DEJÓ CLARO que la colisión de mareas es chica: 5 proyectos, 721 estados. Lo grande es el
-- tramo del medio —274 proyectos, 34.408 estados, hasta 384 días fuera de la ventana del Job—, y
-- eso NO lo explica un número de marea repetido.
--
-- LA HIPÓTESIS BUENA es que parte de esos días son reales y la ventana del Job no los cubre: el
-- tripulante sube antes de la zarpada a preparar el barco, o espera un día de más para relevar a
-- alguien que todavía está embarcado. Si es eso, se ve en el código de estado —tendría que ser
-- guardia en puerto, no navegación— y en la distancia —días, no meses—.
--
-- ESTO MIDE CADA ESTADO CONTRA LA VENTANA DE SU PROPIO PROYECTO, por lado y por código. Si "antes
-- de la zarpada" es casi todo GP/PS a pocos días, la ventana del Job es lo que hay que ensanchar, no
-- el dato lo que hay que corregir. Si aparece NV a meses de distancia, es otra cosa.
WITH Fuera AS (
    SELECT e.[Cód_ Estado] AS Cod,
           CASE WHEN e.[Fecha Inicio] < j.[Starting Date] THEN 'antes de la zarpada'
                ELSE                                           'después del arribo' END AS Lado,
           CASE WHEN e.[Fecha Inicio] < j.[Starting Date]
                     THEN DATEDIFF(day, e.[Fecha Inicio], j.[Starting Date])
                ELSE      DATEDIFF(day, j.[Ending Date], e.[Fecha Inicio]) END AS Dist
    FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
    JOIN   [dbo].[ArbuTest$Job$437dbf0e-84ff-417a-965d-ed2bb9650972] j
           ON j.[No_] = e.[No_ Proyecto]
    WHERE  e.[Tipo Entidad] = 0
      AND  e.[No_ Proyecto] LIKE 'PP-%'
      AND  j.[Starting Date] <> '1753-01-01'
      AND  j.[Ending Date]   <> '1753-01-01'
      AND  (e.[Fecha Inicio] < j.[Starting Date] OR e.[Fecha Inicio] > j.[Ending Date])
),
Tramos AS (
    SELECT Cod, Lado, Dist,
           CASE WHEN Dist <= 3    THEN 'a. 1 a 3 días'
                WHEN Dist <= 7    THEN 'b. 4 a 7 días'
                WHEN Dist <= 31   THEN 'c. 8 a 31 días'
                WHEN Dist <= 180  THEN 'd. 1 a 6 meses'
                ELSE                   'e. más de 6 meses' END AS Tramo
    FROM   Fuera
)
SELECT Lado, Tramo, COUNT(*) AS Estados
FROM   Tramos
GROUP  BY Lado, Tramo
ORDER  BY Lado, Tramo;

-- 3.d.2 LO MISMO POR CÓDIGO DE ESTADO. Es lo que separa "subió antes a preparar" de un error.
WITH Fuera AS (
    SELECT e.[Cód_ Estado] AS Cod,
           CASE WHEN e.[Fecha Inicio] < j.[Starting Date] THEN 'antes de la zarpada'
                ELSE                                           'después del arribo' END AS Lado,
           CASE WHEN e.[Fecha Inicio] < j.[Starting Date]
                     THEN DATEDIFF(day, e.[Fecha Inicio], j.[Starting Date])
                ELSE      DATEDIFF(day, j.[Ending Date], e.[Fecha Inicio]) END AS Dist
    FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
    JOIN   [dbo].[ArbuTest$Job$437dbf0e-84ff-417a-965d-ed2bb9650972] j
           ON j.[No_] = e.[No_ Proyecto]
    WHERE  e.[Tipo Entidad] = 0
      AND  e.[No_ Proyecto] LIKE 'PP-%'
      AND  j.[Starting Date] <> '1753-01-01'
      AND  j.[Ending Date]   <> '1753-01-01'
      AND  (e.[Fecha Inicio] < j.[Starting Date] OR e.[Fecha Inicio] > j.[Ending Date])
)
SELECT Lado, Cod AS Estado, COUNT(*) AS Estados,
       MIN(Dist) AS DistMin, MAX(Dist) AS DistMax,
       -- Las dos columnas que contestan la pregunta: cuántos entran en "un par de días" y cuántos
       -- están tan lejos que no hay explicación operativa posible.
       SUM(CASE WHEN Dist <= 3  THEN 1 ELSE 0 END) AS Hasta3Dias,
       SUM(CASE WHEN Dist > 31 THEN 1 ELSE 0 END) AS MasDeUnMes
FROM   Fuera
GROUP  BY Lado, Cod
ORDER  BY Lado, COUNT(*) DESC;

------------------------------------------------------------------------------------------------
-- 3.e LA PRUEBA DECISIVA — ¿el barco ya había vuelto a zarpar?
------------------------------------------------------------------------------------------------
-- LO QUE DEJÓ CLARO EL 3.d.2. La ventana del Job cubre SÓLO la navegación, y que un estado caiga
-- afuera no es un error por sí mismo: es el modelo. ResolverProyectoInactividad (Cod50017) manda al
-- proyecto de nómina únicamente los estados que NO devengan francos; los que sí —DQ GP NV PI PL PS—
-- se quedan colgados de la marea. Por eso PS aparece antes de la zarpada y PL/GP después del arribo,
-- y por eso los 1.587 PL están TODOS a tres días o menos: es el pilotaje de la llegada.
--
-- LO QUE SÍ ES UN ERROR es la cola larga: 8.128 GP a más de un mes del arribo, con un máximo de
-- 3.904 días. Diez años de guardia en puerto sobre la misma marea es ID_MAREA congelado en Meta4 —
-- el barco llegó, la gente quedó en puerto y el identificador siguió siendo el de la marea anterior.
--
-- LA PRUEBA. Si ese estado empieza DESPUÉS de que el mismo buque ya zarpó en su marea siguiente,
-- entonces no hay ambigüedad posible: está apuntando a una marea que para esa fecha ya había sido
-- reemplazada. Eso es una regla de corrección, no una interpretación.
--
-- El buque sale de la dimensión global 1 del Job, igual que en MigrarPersonalProyecto_4.
WITH Mareas AS (
    SELECT j.[No_] AS Proy, j.[Global Dimension 1 Code] AS Buque,
           j.[Starting Date] AS Zarpada, j.[Ending Date] AS Arribo
    FROM   [dbo].[ArbuTest$Job$437dbf0e-84ff-417a-965d-ed2bb9650972] j
    WHERE  j.[No_] LIKE 'PP-%'
      AND  j.[Starting Date] <> '1753-01-01'
      AND  j.[Ending Date]   <> '1753-01-01'
),
ConSiguiente AS (
    -- La subconsulta correlacionada va en el SELECT y no dentro de un agregado: mezclar una
    -- referencia externa con columnas internas dentro de un agregado es el Msg 8124.
    SELECT m.Proy, m.Buque, m.Zarpada, m.Arribo,
           (SELECT MIN(m2.Zarpada)
              FROM Mareas m2
             WHERE m2.Buque = m.Buque AND m2.Zarpada > m.Arribo) AS ProxZarpada
    FROM   Mareas m
),
Clasificado AS (
    SELECT e.[Cód_ Estado] AS Cod,
           CASE WHEN s.ProxZarpada IS NULL
                     THEN '3. Sin marea siguiente del buque (no se puede decidir)'
                WHEN e.[Fecha Inicio] >= s.ProxZarpada
                     THEN '1. MAL — el buque ya zarpó de nuevo'
                ELSE      '2. Entre el arribo y la próxima zarpada (el barco estaba en puerto)'
                END AS Veredicto
    FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
    JOIN   ConSiguiente s ON s.Proy = e.[No_ Proyecto]
    WHERE  e.[Tipo Entidad] = 0
      AND  e.[Fecha Inicio] > s.Arribo
)
SELECT Veredicto, Cod AS Estado, COUNT(*) AS Estados
FROM   Clasificado
GROUP  BY Veredicto, Cod
ORDER  BY Veredicto, COUNT(*) DESC;

------------------------------------------------------------------------------------------------
-- 4. EL RECORTE  (COMENTADO)
------------------------------------------------------------------------------------------------
-- NO CORRER ESTO ANTES DEL BLOQUE 3.b. Si el problema es que dos mareas distintas comparten número
-- de proyecto, recortar la baja al arribo deja la asignación prolija y a la persona en el barco
-- equivocado. El recorte sirve para el borde de unos días, no para una colisión de años.
--
-- Pone la baja de la asignación en la fecha de arribo del proyecto. Cubre los casos 1 y 2 del
-- bloque 1 — la baja de más y la que quedó abierta con el proyecto ya cerrado.
--
-- DEJA AFUERA EL CASO 3 a propósito: si el alta de la asignación ya es posterior al arribo, recortar
-- la baja daría un intervalo invertido. Esa asignación no existió y hay que decidir si se borra;
-- mirarla en el bloque 3 antes.
--
-- Por SQL y no por AL: el OnModify de "Personal Proyecto" sincroniza estados, y acá los estados ya
-- vienen de Meta4 — dejar correr el trigger generaría un estado por cada fila tocada.
/*
BEGIN TRANSACTION;

UPDATE pp
SET    pp.[Fecha Baja] = j.[Ending Date],
       pp.[$systemModifiedAt] = SYSUTCDATETIME()
FROM   [dbo].[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
JOIN   [dbo].[ArbuTest$Job$437dbf0e-84ff-417a-965d-ed2bb9650972] j
       ON j.[No_] = pp.[No_ Proyecto]
WHERE  j.[Ending Date] <> '1753-01-01'
  AND  pp.[Fecha Alta Asignación] <= j.[Ending Date]
  AND  (pp.[Fecha Baja] = '1753-01-01' OR pp.[Fecha Baja] > j.[Ending Date]);

PRINT 'Asignaciones recortadas: ' + CAST(@@ROWCOUNT AS varchar(10));

-- 4.b CONTROL — tiene que quedar sólo el caso 3, si es que hay alguno.
SELECT COUNT(*) AS QuedanFueraDeRango
FROM   [dbo].[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
JOIN   [dbo].[ArbuTest$Job$437dbf0e-84ff-417a-965d-ed2bb9650972] j
       ON j.[No_] = pp.[No_ Proyecto]
WHERE  j.[Ending Date] <> '1753-01-01'
  AND  (pp.[Fecha Baja] = '1753-01-01' OR pp.[Fecha Baja] > j.[Ending Date]);

-- COMMIT TRANSACTION;  /  ROLLBACK TRANSACTION;
*/
