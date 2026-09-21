/*
    AUDITORÍA — quién entra al lote sin estar en la empresa

    El lote (Cod50018, AplicarFiltroPersonal) elige a la gente por la ASIGNACIÓN a proyecto: baja en
    blanco o posterior al inicio del período, y alta anterior al fin. Nunca pregunta por "Fase Alta
    Empleado", que es donde viven el ingreso y el egreso. Una asignación que quedó abierta cuando la
    persona se fue hace que el lote le genere una liquidación vacía, en borrador, que ensucia el
    control de cobertura y los totales del período.

    El caso que lo destapó: legajo 02678, fase cerrada el 23/2/2001, asignación a PN-101-NOMINA sin
    fecha de baja desde el 21/6/2000, y una liquidación de enero 2026 sin una sola línea.

    SÓLO LEE. El bloque 5 trae el UPDATE de corrección, comentado.

    Ajustar @Desde / @Hasta al período que se está liquidando y ejecutar entero.
*/

USE [Migr2013R2];
GO
SET NOCOUNT ON;
GO

DECLARE @Desde date = '2026-01-01';
DECLARE @Hasta date = '2026-01-31';

SELECT 'Conexión correcta: SQL Server — base ' + DB_NAME() AS GUARDIAN;

------------------------------------------------------------------------------------------------
-- 1. VOLUMEN — de los que el lote elegiría, cuántos no tienen fase que cubra el período
------------------------------------------------------------------------------------------------
-- El filtro de la asignación es el MISMO que aplica AplicarFiltroPersonal para los tipos que no son
-- de arribo. La condición de fase es la que el lote NO tiene: alta anterior al fin del período y
-- baja en blanco o posterior al inicio.
WITH Asig AS (
    SELECT DISTINCT pp.[No_ Empleado] AS Emp
    FROM   [dbo].[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
    WHERE  (pp.[Fecha Baja] = '1753-01-01' OR pp.[Fecha Baja] >= @Desde)
      AND  pp.[Fecha Alta Asignación] <= @Hasta
),
Clasificado AS (
    SELECT a.Emp,
           CASE WHEN EXISTS (
                    SELECT 1
                    FROM   [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
                    WHERE  f.[No_ Empleado] = a.Emp
                      AND  f.[Fecha Alta] <= @Hasta
                      AND  (f.[Fecha Baja] = '1753-01-01' OR f.[Fecha Baja] >= @Desde))
                THEN 'Con fase vigente (correcto)'
                ELSE 'SIN FASE que cubra el período' END AS Situacion
    FROM   Asig a
)
-- El CASE va en el CTE y no acá: un CASE con subconsulta dentro del GROUP BY es el Msg 144.
SELECT Situacion, COUNT(*) AS Empleados
FROM   Clasificado
GROUP  BY Situacion
ORDER  BY Situacion;

------------------------------------------------------------------------------------------------
-- 1.b LOS MISMOS, ABIERTOS POR SITUACIÓN DE LA FASE
------------------------------------------------------------------------------------------------
-- Distingue tres cosas que el bloque 1 mete en la misma bolsa:
--   · Nunca tuvo fase          → la migración de fases no lo alcanzó.
--   · Se fue antes del período → el caso 02678: la baja es real y la asignación quedó abierta.
--   · Ingresa después          → asignación cargada por adelantado; no es un error.
--
-- OJO CON "3. Ingresa después": clasifica por la ÚLTIMA fase (MAX), así que un REINGRESADO cae ahí
-- aunque tenga una fase anterior que sí cubre el período. Medido el 14/9/2026 sobre enero 2026: de
-- 61 en esa categoría, 19 estaban bien. El número que manda es el del bloque 1 —46 sin cobertura—
-- y esta apertura sirve sólo para separar los motivos, no para contar.
WITH Asig AS (
    SELECT DISTINCT pp.[No_ Empleado] AS Emp
    FROM   [dbo].[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
    WHERE  (pp.[Fecha Baja] = '1753-01-01' OR pp.[Fecha Baja] >= @Desde)
      AND  pp.[Fecha Alta Asignación] <= @Hasta
),
Fases AS (
    -- Los agregados sobre la tabla de fases se resuelven con LEFT JOIN + GROUP BY y no con una
    -- subconsulta correlacionada dentro del agregado: eso último es el Msg 8124.
    -- La baja en blanco se mapea a 9999-12-31 para que el MAX la elija: es la fase más reciente.
    SELECT a.Emp,
           COUNT(f.[No_ Empleado]) AS CantFases,
           MAX(f.[Fecha Alta])     AS UltimaAlta,
           MAX(CASE WHEN f.[Fecha Baja] = '1753-01-01' THEN '9999-12-31' ELSE f.[Fecha Baja] END) AS UltimaBaja
    FROM   Asig a
    LEFT JOIN [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
           ON f.[No_ Empleado] = a.Emp
    GROUP  BY a.Emp
),
Clasificado AS (
    SELECT Emp,
           CASE WHEN CantFases = 0       THEN '1. Nunca tuvo fase'
                WHEN UltimaBaja < @Desde THEN '2. Se fue antes del período'
                WHEN UltimaAlta > @Hasta THEN '3. Ingresa después del período'
                ELSE                          '4. Fase vigente (correcto)' END AS Situacion
    FROM   Fases
)
SELECT Situacion, COUNT(*) AS Empleados
FROM   Clasificado
GROUP  BY Situacion
ORDER  BY Situacion;

------------------------------------------------------------------------------------------------
-- 2. EL DETALLE — uno por uno, con la fase, la asignación y el estado abierto
------------------------------------------------------------------------------------------------
-- Es la lista para mirar antes de tocar nada. Las columnas están puestas para decidir de un vistazo
-- si la baja es real (motivo cargado, último estado viejo) o si lo que falta es la fase.
WITH Asig AS (
    SELECT pp.[No_ Empleado] AS Emp, pp.[No_ Proyecto] AS Proy,
           pp.[Fecha Alta Asignación] AS AsigAlta, pp.[Fecha Baja] AS AsigBaja,
           ROW_NUMBER() OVER (PARTITION BY pp.[No_ Empleado]
                              ORDER BY pp.[Fecha Alta Asignación] DESC) AS Orden
    FROM   [dbo].[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
    WHERE  (pp.[Fecha Baja] = '1753-01-01' OR pp.[Fecha Baja] >= @Desde)
      AND  pp.[Fecha Alta Asignación] <= @Hasta
      AND  NOT EXISTS (
               SELECT 1
               FROM   [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
               WHERE  f.[No_ Empleado] = pp.[No_ Empleado]
                 AND  f.[Fecha Alta] <= @Hasta
                 AND  (f.[Fecha Baja] = '1753-01-01' OR f.[Fecha Baja] >= @Desde))
),
UltimaFase AS (
    SELECT f.[No_ Empleado] AS Emp, f.[Fecha Alta] AS FaseAlta, f.[Fecha Baja] AS FaseBaja,
           f.[Cód_ Motivo Baja] AS MotivoBaja,
           ROW_NUMBER() OVER (PARTITION BY f.[No_ Empleado] ORDER BY f.[No_ Fase] DESC) AS Orden
    FROM   [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
),
EstadoAbierto AS (
    SELECT e.[No_ Empleado] AS Emp, e.[Cód_ Estado] AS EstadoAbierto,
           e.[Fecha Inicio] AS EstadoDesde,
           ROW_NUMBER() OVER (PARTITION BY e.[No_ Empleado] ORDER BY e.[Fecha Inicio] DESC) AS Orden
    FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
    WHERE  e.[Tipo Entidad] = 0 AND e.[Fecha Fin] = '1753-01-01'
)
SELECT a.Emp AS Legajo,
       em.[First Name] + ' ' + em.[Last Name] AS Nombre,
       a.Proy     AS Proyecto,
       a.AsigAlta AS AsignadoDesde,
       CASE WHEN a.AsigBaja  = '1753-01-01' THEN NULL ELSE a.AsigBaja  END AS AsignadoHasta,
       uf.FaseAlta,
       CASE WHEN uf.FaseBaja = '1753-01-01' THEN NULL ELSE uf.FaseBaja END AS FaseBaja,
       uf.MotivoBaja,
       ea.EstadoAbierto, ea.EstadoDesde
FROM   Asig a
LEFT JOIN UltimaFase    uf ON uf.Emp = a.Emp AND uf.Orden = 1
LEFT JOIN EstadoAbierto ea ON ea.Emp = a.Emp AND ea.Orden = 1
LEFT JOIN [dbo].[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972] em ON em.[No_] = a.Emp
WHERE  a.Orden = 1
ORDER  BY uf.FaseBaja, a.Emp;

------------------------------------------------------------------------------------------------
-- 2.b ¿FALTA LA FASE O NO ESTABA? — la pregunta que decide qué hacer con cada uno
------------------------------------------------------------------------------------------------
-- Los 46 del bloque 1 no son un solo problema. Medido el 14/9/2026 sobre enero 2026, cuatro tienen
-- una baja real con motivo cargado y la asignación abierta (02678 es de 2001), pero los otros ~42
-- tienen un HUECO: la fase que se ve arranca en febrero, marzo o mayo de 2026, y la asignación al
-- proyecto los cubre desde septiembre de 2025 hasta mayo de 2026 — atravesando el hueco.
--
-- Lo que desempata es el estado operativo. Un estado vigente en el período significa que la persona
-- estaba embarcada o en puerto ESE MES: entonces lo que falta es la fase, y hay que crearla, no
-- saltear al empleado. Sin estados, no estaba, y la liquidación sobra.
--
-- Las fases de al lado —la última que empieza antes del período y la primera que empieza después—
-- muestran el hueco con sus dos bordes, que es como se ve si el problema es una baja de más o un
-- alta que llegó tarde.
WITH SinFase AS (
    SELECT DISTINCT pp.[No_ Empleado] AS Emp
    FROM   [dbo].[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
    WHERE  (pp.[Fecha Baja] = '1753-01-01' OR pp.[Fecha Baja] >= @Desde)
      AND  pp.[Fecha Alta Asignación] <= @Hasta
      AND  NOT EXISTS (
               SELECT 1
               FROM   [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
               WHERE  f.[No_ Empleado] = pp.[No_ Empleado]
                 AND  f.[Fecha Alta] <= @Hasta
                 AND  (f.[Fecha Baja] = '1753-01-01' OR f.[Fecha Baja] >= @Desde))
),
FasePrevia AS (
    SELECT f.[No_ Empleado] AS Emp, f.[No_ Fase] AS Fase,
           f.[Fecha Alta] AS Alta, f.[Fecha Baja] AS Baja, f.[Cód_ Motivo Baja] AS Motivo,
           ROW_NUMBER() OVER (PARTITION BY f.[No_ Empleado] ORDER BY f.[Fecha Alta] DESC) AS Orden
    FROM   [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
    WHERE  f.[Fecha Alta] < @Desde
),
FaseSiguiente AS (
    SELECT f.[No_ Empleado] AS Emp, f.[No_ Fase] AS Fase,
           f.[Fecha Alta] AS Alta, f.[Cód_ Motivo Alta] AS Motivo,
           ROW_NUMBER() OVER (PARTITION BY f.[No_ Empleado] ORDER BY f.[Fecha Alta]) AS Orden
    FROM   [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
    WHERE  f.[Fecha Alta] > @Hasta
),
-- Estados que se solapan con el período: inicio anterior al fin y fin en blanco o posterior al
-- inicio. Es la misma intersección de intervalos que usa el motor para contar días.
EstadosDelPeriodo AS (
    SELECT e.[No_ Empleado] AS Emp,
           COUNT(*)              AS Cantidad,
           MIN(e.[Fecha Inicio]) AS PrimerInicio,
           MAX(e.[Fecha Inicio]) AS UltimoInicio
    FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
    WHERE  e.[Tipo Entidad] = 0
      AND  e.[Fecha Inicio] <= @Hasta
      AND  (e.[Fecha Fin] = '1753-01-01' OR e.[Fecha Fin] >= @Desde)
    GROUP  BY e.[No_ Empleado]
),
Clasificado AS (
    SELECT s.Emp,
           COALESCE(ep.Cantidad, 0) AS EstadosEnPeriodo,
           ep.PrimerInicio, ep.UltimoInicio,
           fp.Fase AS FasePrevNo, fp.Alta AS FasePrevAlta, fp.Baja AS FasePrevBaja,
           fp.Motivo AS FasePrevMotivo,
           fs.Fase AS FaseSigNo, fs.Alta AS FaseSigAlta, fs.Motivo AS FaseSigMotivo,
           CASE WHEN COALESCE(ep.Cantidad, 0) > 0
                THEN 'A. FALTA LA FASE (tenía estados en el período)'
                ELSE 'B. NO ESTABA (sin estados en el período)' END AS Veredicto
    FROM   SinFase s
    LEFT JOIN EstadosDelPeriodo ep ON ep.Emp = s.Emp
    LEFT JOIN FasePrevia        fp ON fp.Emp = s.Emp AND fp.Orden = 1
    LEFT JOIN FaseSiguiente     fs ON fs.Emp = s.Emp AND fs.Orden = 1
)
SELECT Veredicto, COUNT(*) AS Empleados
FROM   Clasificado
GROUP  BY Veredicto
ORDER  BY Veredicto;

-- 2.b.2 El mismo veredicto, empleado por empleado y con los dos bordes del hueco.
--       Repite los CTE porque un WITH vive un solo statement.
WITH SinFase AS (
    SELECT DISTINCT pp.[No_ Empleado] AS Emp
    FROM   [dbo].[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
    WHERE  (pp.[Fecha Baja] = '1753-01-01' OR pp.[Fecha Baja] >= @Desde)
      AND  pp.[Fecha Alta Asignación] <= @Hasta
      AND  NOT EXISTS (
               SELECT 1
               FROM   [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
               WHERE  f.[No_ Empleado] = pp.[No_ Empleado]
                 AND  f.[Fecha Alta] <= @Hasta
                 AND  (f.[Fecha Baja] = '1753-01-01' OR f.[Fecha Baja] >= @Desde))
),
FasePrevia AS (
    SELECT f.[No_ Empleado] AS Emp, f.[No_ Fase] AS Fase,
           f.[Fecha Alta] AS Alta, f.[Fecha Baja] AS Baja, f.[Cód_ Motivo Baja] AS Motivo,
           ROW_NUMBER() OVER (PARTITION BY f.[No_ Empleado] ORDER BY f.[Fecha Alta] DESC) AS Orden
    FROM   [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
    WHERE  f.[Fecha Alta] < @Desde
),
FaseSiguiente AS (
    SELECT f.[No_ Empleado] AS Emp, f.[No_ Fase] AS Fase,
           f.[Fecha Alta] AS Alta, f.[Cód_ Motivo Alta] AS Motivo,
           ROW_NUMBER() OVER (PARTITION BY f.[No_ Empleado] ORDER BY f.[Fecha Alta]) AS Orden
    FROM   [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
    WHERE  f.[Fecha Alta] > @Hasta
),
EstadosDelPeriodo AS (
    SELECT e.[No_ Empleado] AS Emp,
           COUNT(*)              AS Cantidad,
           MIN(e.[Fecha Inicio]) AS PrimerInicio,
           MAX(e.[Fecha Inicio]) AS UltimoInicio
    FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
    WHERE  e.[Tipo Entidad] = 0
      AND  e.[Fecha Inicio] <= @Hasta
      AND  (e.[Fecha Fin] = '1753-01-01' OR e.[Fecha Fin] >= @Desde)
    GROUP  BY e.[No_ Empleado]
)
SELECT s.Emp AS Legajo,
       em.[First Name] + ' ' + em.[Last Name] AS Nombre,
       CASE WHEN COALESCE(ep.Cantidad, 0) > 0 THEN 'A. FALTA LA FASE'
            ELSE 'B. NO ESTABA' END AS Veredicto,
       COALESCE(ep.Cantidad, 0) AS EstadosEnPeriodo,
       ep.PrimerInicio, ep.UltimoInicio,
       fp.Fase AS FasePrev, fp.Alta AS FasePrevAlta,
       CASE WHEN fp.Baja = '1753-01-01' THEN NULL ELSE fp.Baja END AS FasePrevBaja,
       fp.Motivo AS MotivoBaja,
       fs.Fase AS FaseSig, fs.Alta AS FaseSigAlta, fs.Motivo AS MotivoAlta,
       -- El tamaño del hueco: si son pocos días es un desfasaje de bordes; si son meses, es que
       -- de verdad no estaba.
       -- NULLIF sobre la fecha en blanco: sin eso, una fase previa sin baja daría los 96.000 días
       -- que van desde 1753.
       DATEDIFF(day, NULLIF(fp.Baja, '1753-01-01'), fs.Alta) AS DiasDeHueco
FROM   SinFase s
LEFT JOIN EstadosDelPeriodo ep ON ep.Emp = s.Emp
LEFT JOIN FasePrevia        fp ON fp.Emp = s.Emp AND fp.Orden = 1
LEFT JOIN FaseSiguiente     fs ON fs.Emp = s.Emp AND fs.Orden = 1
LEFT JOIN [dbo].[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972] em ON em.[No_] = s.Emp
ORDER  BY Veredicto, DiasDeHueco DESC, s.Emp;

------------------------------------------------------------------------------------------------
-- 3. EL DAÑO YA HECHO — liquidaciones del período para esa gente
------------------------------------------------------------------------------------------------
-- El nombre de la tabla de liquidaciones depende de cómo BC escribió el acento, así que se descubre
-- en sys.tables igual que en DiagnosticoLiquidacion.sql. "_" es comodín de un carácter.
DECLARE @TLiq sysname, @TLin sysname, @sql nvarchar(max);
SELECT @TLiq = QUOTENAME(name) FROM sys.tables WHERE name LIKE N'ArbuTest$Liquidaci_n$%';
SELECT @TLin = QUOTENAME(name) FROM sys.tables WHERE name LIKE N'ArbuTest$L_nea Liquidaci_n$%';

IF @TLiq IS NULL OR @TLin IS NULL
    SELECT 'No se encontraron las tablas de liquidación' AS Aviso;
ELSE
BEGIN
    -- CAST a nvarchar(max) en el primer trozo: sin eso la concatenación se resuelve en nvarchar(4000)
    -- y el SQL se corta sin avisar.
    SET @sql = CAST(N'
    WITH SinFase AS (
        SELECT DISTINCT pp.[No_ Empleado] AS Emp
        FROM   [dbo].[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
        WHERE  (pp.[Fecha Baja] = ''1753-01-01'' OR pp.[Fecha Baja] >= @Desde)
          AND  pp.[Fecha Alta Asignación] <= @Hasta
          AND  NOT EXISTS (
                   SELECT 1
                   FROM   [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
                   WHERE  f.[No_ Empleado] = pp.[No_ Empleado]
                     AND  f.[Fecha Alta] <= @Hasta
                     AND  (f.[Fecha Baja] = ''1753-01-01'' OR f.[Fecha Baja] >= @Desde))
    ),
    Cab AS (
        SELECT h.[No_] AS NoLiq, h.[No_ Empleado] AS Legajo, h.[Nombre Empleado] AS Nombre,
               h.[Cód_ Tipo Liq_] AS TipoLiq, h.[No_ Proyecto] AS Proyecto,
               h.[Estado] AS EstadoLiq, h.[Total Haberes] AS Haberes,
               (SELECT COUNT(*) FROM [dbo].' AS nvarchar(max)) + @TLin + N' l
                 WHERE l.[No_ Liquidación] = h.[No_]) AS Lineas
        FROM   [dbo].' + @TLiq + N' h
        JOIN   SinFase s ON s.Emp = h.[No_ Empleado]
        WHERE  h.[Fecha Liquidación] BETWEEN @Desde AND @Hasta
    )
    SELECT ''3.a RESUMEN'' AS Bloque, COUNT(*) AS Liquidaciones,
           SUM(CASE WHEN Lineas = 0 THEN 1 ELSE 0 END) AS SinNingunaLinea,
           SUM(Haberes) AS TotalHaberes
    FROM   Cab;

    WITH SinFase AS (
        SELECT DISTINCT pp.[No_ Empleado] AS Emp
        FROM   [dbo].[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
        WHERE  (pp.[Fecha Baja] = ''1753-01-01'' OR pp.[Fecha Baja] >= @Desde)
          AND  pp.[Fecha Alta Asignación] <= @Hasta
          AND  NOT EXISTS (
                   SELECT 1
                   FROM   [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
                   WHERE  f.[No_ Empleado] = pp.[No_ Empleado]
                     AND  f.[Fecha Alta] <= @Hasta
                     AND  (f.[Fecha Baja] = ''1753-01-01'' OR f.[Fecha Baja] >= @Desde))
    )
    SELECT h.[No_] AS NoLiq, h.[No_ Empleado] AS Legajo, h.[Nombre Empleado] AS Nombre,
           h.[Cód_ Tipo Liq_] AS TipoLiq, h.[No_ Proyecto] AS Proyecto,
           h.[Estado] AS EstadoLiq, h.[Total Haberes] AS Haberes,
           (SELECT COUNT(*) FROM [dbo].' + @TLin + N' l
             WHERE l.[No_ Liquidación] = h.[No_]) AS Lineas
    FROM   [dbo].' + @TLiq + N' h
    JOIN   SinFase s ON s.Emp = h.[No_ Empleado]
    WHERE  h.[Fecha Liquidación] BETWEEN @Desde AND @Hasta
    ORDER  BY h.[No_ Empleado];';

    EXEC sp_executesql @sql, N'@Desde date, @Hasta date', @Desde = @Desde, @Hasta = @Hasta;
END;

------------------------------------------------------------------------------------------------
-- 4. EL ESPEJO — fases abiertas de gente que ya no está, y estados abiertos fuera de fase
------------------------------------------------------------------------------------------------
-- 4.a Fases abiertas cuya baja nunca migró: gente con la fase abierta que hace más de dos años que
--     no registra un estado operativo.
--
--     EL EXISTS DE ARRIBA NO ESTÁ DE ADORNO. La primera versión pedía sólo que NO hubiera estados
--     recientes, y devolvió 54 filas que eran todas 80xxx y 90xxx con UltimoEstado en NULL: los
--     administrativos no tienen NINGÚN estado operativo —los estados son de embarcados— así que
--     "hace dos años que no pasa nada" los describe a todos, incluidos los que trabajan hoy.
--     Pedir que haya al menos un estado limita la pregunta a la población donde significa algo.
SELECT f.[No_ Empleado] AS Legajo,
       em.[First Name] + ' ' + em.[Last Name] AS Nombre,
       f.[No_ Fase], f.[Fecha Alta],
       (SELECT MAX(e.[Fecha Inicio])
          FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
         WHERE e.[No_ Empleado] = f.[No_ Empleado] AND e.[Tipo Entidad] = 0) AS UltimoEstado
FROM   [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
LEFT JOIN [dbo].[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972] em
       ON em.[No_] = f.[No_ Empleado]
WHERE  f.[Fecha Baja] = '1753-01-01'
  AND  EXISTS (
           SELECT 1
           FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
           WHERE  e.[No_ Empleado] = f.[No_ Empleado] AND e.[Tipo Entidad] = 0)
  AND  NOT EXISTS (
           SELECT 1
           FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
           WHERE  e.[No_ Empleado] = f.[No_ Empleado] AND e.[Tipo Entidad] = 0
             AND  e.[Fecha Inicio] >= DATEADD(year, -2, @Hasta))
ORDER  BY UltimoEstado;

-- 4.b Estados abiertos que no caen en ninguna fase abierta: los 15 del bloque 6.b de MigrarEstados_2.
SELECT e.[No_ Empleado] AS Legajo, e.[Cód_ Estado] AS Estado, e.[Fecha Inicio] AS Desde,
       e.[No_ Proyecto] AS Proyecto
FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
WHERE  e.[Tipo Entidad] = 0
  AND  e.[Fecha Fin] = '1753-01-01'
  AND  NOT EXISTS (
           SELECT 1
           FROM   [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
           WHERE  f.[No_ Empleado] = e.[No_ Empleado]
             AND  f.[Fecha Alta] <= e.[Fecha Inicio]
             AND  f.[Fecha Baja] = '1753-01-01')
ORDER  BY e.[No_ Empleado];

------------------------------------------------------------------------------------------------
-- 5. CORRECCIÓN — cerrar la asignación el día de la baja  (COMENTADO)
------------------------------------------------------------------------------------------------
-- Mirar primero el bloque 2. Esto cierra cada asignación abierta en la fecha de baja de la última
-- fase del empleado. No toca las asignaciones de gente que sigue (última fase abierta) ni las que
-- ya tienen fecha de baja.
--
-- Por SQL y no por AL por el mismo motivo que la migración: el OnModify de "Personal Proyecto"
-- sincroniza estados, y acá los estados ya vienen de Meta4.
--
-- Esto limpia el dato de hoy; NO evita que vuelva a ensuciarse. Lo que lo evita es el filtro por
-- fase en AplicarFiltroPersonal.
/*
BEGIN TRANSACTION;

WITH UltimaFase AS (
    SELECT f.[No_ Empleado] AS Emp, f.[Fecha Baja] AS FaseBaja,
           ROW_NUMBER() OVER (PARTITION BY f.[No_ Empleado] ORDER BY f.[No_ Fase] DESC) AS Orden
    FROM   [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
)
UPDATE pp
SET    pp.[Fecha Baja] = uf.FaseBaja,
       pp.[$systemModifiedAt] = SYSUTCDATETIME()
FROM   [dbo].[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
JOIN   UltimaFase uf ON uf.Emp = pp.[No_ Empleado] AND uf.Orden = 1
WHERE  pp.[Fecha Baja] = '1753-01-01'
  AND  uf.FaseBaja <> '1753-01-01'
  AND  pp.[Fecha Alta Asignación] <= uf.FaseBaja;

PRINT 'Asignaciones cerradas: ' + CAST(@@ROWCOUNT AS varchar(10));

-- COMMIT TRANSACTION;  /  ROLLBACK TRANSACTION;
*/
