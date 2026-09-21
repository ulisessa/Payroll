/*
    RELLENAR CON "ACT" LOS HUECOS DEL HISTORIAL DE TIERRA

    EL PROBLEMA. Después de MigrarAusentismos_2, los administrativos tienen estados — pero SÓLO sus
    ausencias. Su historial son islas: unas vacaciones en 2020, otras en 2021, y entre medio nada. El
    de un embarcado, en cambio, es denso: cada día está cubierto por navegación, franco o puerto.

    QUÉ SE ROMPE CON ISLAS, y no es sólo cosmético:
      · "Estado Actual" en la ficha muestra la última ausencia. El legajo 90016 figura en Vacaciones
        desde el 1/1/2026 aunque terminaron el 4/2.
      · GetEstado(fecha) no encuentra nada para cualquier día fuera de una ausencia, y
        ValidarEstadoExiste corta el cálculo con "el empleado no tiene estado".
      · DIAS_VAC_PERIODO y todo lo que cuenta días por intersección de estados mide sobre huecos.

    LA REGLA. Todo día dentro de una fase de alta que no esté cubierto por una ausencia es ACT.

    EL RELLENO NO CRUZA UNA BAJA — y esto ya lo pagamos caro. El relleno "OR" de MigrarEstados_2
    tapaba el hueco entre dos estados sin mirar las fases, y dejó 28 estados de hasta 54 días sobre
    períodos en que la persona no estaba en la empresa; el de 04513 se descubrió porque el motor le
    liquidaba días de un mes en que estaba de baja. Acá los tramos se generan DENTRO de cada fase,
    nunca entre una baja y el reingreso siguiente.

    EL ÚLTIMO TRAMO DE UNA FASE ABIERTA QUEDA ABIERTO. Es lo que hace que "Estado Actual" diga ACT y
    no la última ausencia. Un estado abierto es peligroso —se solapa con cualquier período
    posterior— pero acá es lo correcto: la persona efectivamente sigue activa. Lo que no puede
    quedar abierto es el tramo final de una fase CERRADA, y por eso se cierra en la baja.

    ORDEN: 1 y 2 miden, el 3 inserta, el 4 verifica.
*/

USE [Migr2013R2];
GO
SET NOCOUNT ON;
GO

SELECT 'Conexión correcta: SQL Server — base ' + DB_NAME() AS GUARDIAN;

------------------------------------------------------------------------------------------------
-- 1. PRE-VUELO
------------------------------------------------------------------------------------------------

-- 1.a ¿EXISTE "ACT" Y CÓMO ESTÁ CONFIGURADO?
--     Las dos banderas importan y por motivos distintos:
--       · "Devenga Francos" tiene que estar en NO. Si estuviera en Sí, cada día de oficina de un
--         administrativo devengaría francos, que es una figura de embarcados.
--       · "Transcurre en Marea" tiene que estar en NO, porque si no ResolverProyectoInactividad no
--         mandaría al proyecto de nómina el estado siguiente.
SELECT [Código], [Descripción], [Tipo Estado], [Devenga Francos], [Transcurre en Marea], [Activo]
FROM   [dbo].[ArbuTest$Cód_ Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
WHERE  [Código] = 'ACT';

-- 1.b CUÁNTOS LEGAJOS DE TIERRA Y CUÁNTAS FASES entran en el relleno.
SELECT COUNT(DISTINCT f.[No_ Empleado]) AS Legajos,
       COUNT(*)                         AS Fases,
       SUM(CASE WHEN f.[Fecha Baja] = '1753-01-01' THEN 1 ELSE 0 END) AS FasesAbiertas
FROM   [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
WHERE  f.[No_ Empleado] LIKE '8%' OR f.[No_ Empleado] LIKE '9%';

-- 1.c LEGAJOS DE TIERRA SIN NINGUNA FASE. No se pueden rellenar: sin fase no hay marco, y un ACT
--     fuera de fase es exactamente el estado huérfano que estuvimos limpiando.
SELECT DISTINCT e.[No_ Empleado]
FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
WHERE  e.[Tipo Entidad] = 0
  AND  (e.[No_ Empleado] LIKE '8%' OR e.[No_ Empleado] LIKE '9%')
  AND  NOT EXISTS (SELECT 1 FROM [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
                   WHERE f.[No_ Empleado] = e.[No_ Empleado]);

------------------------------------------------------------------------------------------------
-- 2. LOS TRAMOS QUE SE VAN A CREAR
------------------------------------------------------------------------------------------------
-- Cuatro casos, y se ven mejor dibujados sobre una fase:
--
--     alta ├─── a ───┤ausencia├─── b ───┤ausencia├─── c ───┤ baja
--
--   a. inicial   — de la fase hasta el día antes de la primera ausencia
--   b. intermedio— entre el fin de una ausencia y el inicio de la siguiente
--   c. final     — del fin de la última ausencia hasta la baja (o abierto si la fase lo está)
--   d. completo  — la fase entera, cuando no hay ninguna ausencia adentro
--
-- Esta vista se usa en el bloque 3; acá se cuenta primero.
--
-- El GO de acá abajo no es adorno: CREATE VIEW tiene que ser el primer statement de su lote.
GO
CREATE OR ALTER VIEW dbo.VW_TramosActivoTierra AS
WITH Fases AS (
    SELECT f.[No_ Empleado] AS Emp, f.[No_ Fase] AS Fase, f.[Fecha Alta] AS Alta,
           CASE WHEN f.[Fecha Baja] = '1753-01-01' THEN NULL ELSE f.[Fecha Baja] END AS Baja
    FROM   [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
    WHERE  f.[No_ Empleado] LIKE '8%' OR f.[No_ Empleado] LIKE '9%'
),
-- Las ausencias de cada fase, ya emparejadas con la siguiente. LEFT JOIN: una fase sin ausencias
-- igual tiene que producir su tramo completo.
Aus AS (
    SELECT fa.Emp, fa.Fase, fa.Alta, fa.Baja,
           e.[Fecha Inicio] AS Desde,
           CASE WHEN e.[Fecha Fin] = '1753-01-01' THEN NULL ELSE e.[Fecha Fin] END AS Hasta,
           ROW_NUMBER() OVER (PARTITION BY fa.Emp, fa.Fase ORDER BY e.[Fecha Inicio])  AS Orden,
           LEAD(e.[Fecha Inicio]) OVER (PARTITION BY fa.Emp, fa.Fase
                                        ORDER BY e.[Fecha Inicio])                     AS SigDesde
    FROM   Fases fa
    LEFT JOIN [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
           ON  e.[Tipo Entidad] = 0
           AND e.[No_ Empleado] = fa.Emp
           AND e.[Fecha Inicio] >= fa.Alta
           AND (fa.Baja IS NULL OR e.[Fecha Inicio] <= fa.Baja)
)
-- a. TRAMO INICIAL
SELECT Emp, Alta AS Desde, DATEADD(day, -1, Desde) AS Hasta, 'a. inicial' AS Tramo
FROM   Aus
WHERE  Orden = 1 AND Desde > Alta
UNION ALL
-- b. TRAMO INTERMEDIO. Sólo si hay un día libre entre una ausencia y la siguiente.
SELECT Emp, DATEADD(day, 1, Hasta), DATEADD(day, -1, SigDesde), 'b. intermedio'
FROM   Aus
WHERE  SigDesde IS NOT NULL AND Hasta IS NOT NULL
  AND  DATEADD(day, 1, Hasta) <= DATEADD(day, -1, SigDesde)
UNION ALL
-- c. TRAMO FINAL. Con la fase abierta queda abierto (1753 = en blanco); con la fase cerrada, hasta
--    la baja.
SELECT Emp, DATEADD(day, 1, Hasta),
       CASE WHEN Baja IS NULL THEN CAST('1753-01-01' AS date) ELSE Baja END,
       'c. final'
FROM   Aus
WHERE  SigDesde IS NULL AND Hasta IS NOT NULL
  AND  (Baja IS NULL OR DATEADD(day, 1, Hasta) <= Baja)
UNION ALL
-- d. FASE SIN NINGUNA AUSENCIA.
SELECT Emp, Alta,
       CASE WHEN Baja IS NULL THEN CAST('1753-01-01' AS date) ELSE Baja END,
       'd. fase completa'
FROM   Aus
WHERE  Desde IS NULL;
GO

-- 2.a CUÁNTOS TRAMOS SALEN, por tipo.
SELECT Tramo, COUNT(*) AS Tramos, COUNT(DISTINCT Emp) AS Legajos,
       SUM(CASE WHEN Hasta = '1753-01-01' THEN 1 ELSE 0 END) AS Abiertos
FROM   dbo.VW_TramosActivoTierra
GROUP  BY Tramo
ORDER  BY Tramo;

-- 2.b TRAMOS INVERTIDOS. Tiene que dar CERO: un tramo que termina antes de empezar es un error de
--     las condiciones de arriba, no del dato.
SELECT COUNT(*) AS TramosInvertidos
FROM   dbo.VW_TramosActivoTierra
WHERE  Hasta <> '1753-01-01' AND Hasta < Desde;

-- 2.c TRAMOS QUE SE PISAN CON UN ESTADO EXISTENTE. Tiene que dar CERO — si no, la construcción de
--     los tramos dejó pasar algo y el relleno duplicaría días.
SELECT COUNT(*) AS PisanUnaAusencia
FROM   dbo.VW_TramosActivoTierra t
JOIN   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
       ON  e.[Tipo Entidad] = 0
       AND e.[No_ Empleado] = t.Emp
       AND e.[Fecha Inicio] <= CASE WHEN t.Hasta = '1753-01-01' THEN '9999-12-31' ELSE t.Hasta END
       AND (e.[Fecha Fin] = '1753-01-01' OR e.[Fecha Fin] >= t.Desde);

-- 2.d MÁS DE UN TRAMO ABIERTO POR EMPLEADO. Tiene que dar CERO: una persona no puede estar activa
--     desde dos fechas distintas a la vez.
SELECT COUNT(*) AS LegajosConVariosAbiertos
FROM  (SELECT Emp FROM dbo.VW_TramosActivoTierra
       WHERE Hasta = '1753-01-01'
       GROUP BY Emp HAVING COUNT(*) > 1) x;

------------------------------------------------------------------------------------------------
-- 3. LA INSERCIÓN  (COMENTADA — descomentar con el bloque 2 en cero)
------------------------------------------------------------------------------------------------
-- El proyecto sale de "Proyectos Asignados" con la misma resolución que usó la migración de
-- ausencias: asignación vigente a la fecha del tramo y, si no hay, la primera del empleado.
/*
BEGIN TRANSACTION;

INSERT INTO [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
    ([No_ Empleado], [Fecha Inicio], [Cód_ Estado], [Fecha Fin],
     [Observaciones], [No_ Proyecto], [Tipo Entidad],
     [$systemId], [$systemCreatedAt], [$systemCreatedBy], [$systemModifiedAt], [$systemModifiedBy])
SELECT t.Emp,
       t.Desde,
       'ACT',
       t.Hasta,
       'Generado: tramo activo entre ausencias (' + t.Tramo + ').',
       COALESCE(vig.Proy, prim.Proy, ''),
       0,
       NEWID(), SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000',
                SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000'
FROM   dbo.VW_TramosActivoTierra t
OUTER APPLY (SELECT TOP 1 pp.[No_ Proyecto] AS Proy
             FROM   [dbo].[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
             WHERE  pp.[No_ Empleado] = t.Emp
               AND  pp.[Fecha Alta Asignación] <= t.Desde
               AND  (pp.[Fecha Baja] = '1753-01-01' OR pp.[Fecha Baja] >= t.Desde)
             ORDER  BY pp.[Fecha Alta Asignación] DESC) vig
OUTER APPLY (SELECT TOP 1 pp.[No_ Proyecto] AS Proy
             FROM   [dbo].[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
             WHERE  pp.[No_ Empleado] = t.Emp
             ORDER  BY pp.[Fecha Alta Asignación]) prim
WHERE  NOT EXISTS (SELECT 1 FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
                   WHERE e.[Tipo Entidad] = 0
                     AND e.[No_ Empleado] = t.Emp
                     AND e.[Fecha Inicio] = t.Desde);

PRINT 'Tramos ACT creados: ' + CAST(@@ROWCOUNT AS varchar(10));

-- COMMIT TRANSACTION;  /  ROLLBACK TRANSACTION;
*/

------------------------------------------------------------------------------------------------
-- 4. VERIFICACIÓN POSTERIOR
------------------------------------------------------------------------------------------------

-- 4.a Días sin cubrir dentro de una fase. Es el control que dice si el historial quedó continuo:
--     por cada ausencia, el estado anterior tiene que terminar justo el día antes.
SELECT COUNT(*) AS AusenciasSinEstadoAnterior
FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
WHERE  e.[Tipo Entidad] = 0
  AND  (e.[No_ Empleado] LIKE '8%' OR e.[No_ Empleado] LIKE '9%')
  AND  e.[Cód_ Estado] <> 'ACT'
  AND  EXISTS (SELECT 1 FROM [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
               WHERE f.[No_ Empleado] = e.[No_ Empleado]
                 AND f.[Fecha Alta] < e.[Fecha Inicio]
                 AND (f.[Fecha Baja] = '1753-01-01' OR f.[Fecha Baja] >= e.[Fecha Inicio]))
  AND  NOT EXISTS (SELECT 1 FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] p
                   WHERE p.[Tipo Entidad] = 0
                     AND p.[No_ Empleado] = e.[No_ Empleado]
                     AND p.[Fecha Fin] = DATEADD(day, -1, e.[Fecha Inicio]));

-- 4.b Estados solapados. Tiene que dar CERO.
SELECT COUNT(*) AS Solapados
FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] a
JOIN   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] b
       ON  b.[Tipo Entidad] = 0 AND a.[Tipo Entidad] = 0
       AND b.[No_ Empleado] = a.[No_ Empleado]
       AND b.[Fecha Inicio] > a.[Fecha Inicio]
       AND b.[Fecha Inicio] <= a.[Fecha Fin]
WHERE  a.[Fecha Fin] <> '1753-01-01'
  AND  (a.[No_ Empleado] LIKE '8%' OR a.[No_ Empleado] LIKE '9%');

-- 4.c El estado actual de cada administrativo con fase abierta. Tendría que ser ACT en casi todos:
--     si alguno sigue mostrando una ausencia vieja, su tramo final no se generó.
SELECT e.[Cód_ Estado], COUNT(*) AS Legajos
FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
WHERE  e.[Tipo Entidad] = 0
  AND  e.[Fecha Fin] = '1753-01-01'
  AND  (e.[No_ Empleado] LIKE '8%' OR e.[No_ Empleado] LIKE '9%')
GROUP  BY e.[Cód_ Estado]
ORDER  BY COUNT(*) DESC;

-- Limpieza: la vista fue sólo andamiaje de esta migración.
-- DROP VIEW dbo.VW_TramosActivoTierra;
