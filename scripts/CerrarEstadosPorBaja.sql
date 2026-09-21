/*
    CERRAR LOS ESTADOS QUE QUEDARON PASADOS DE LA BAJA

    La regla: si la fase tiene fecha de baja, ningún estado que empiece dentro de esa fase puede
    terminar después de ella. Un estado sin fecha fin no vale "hasta la baja" — vale hasta el
    31/12/9999, que es lo que devuelve FechaFinEfectiva cuando no hay un estado siguiente. De ahí
    salen los Francos abiertos desde 2001 que se solapan con enero de 2026.

    De acá en adelante lo sostiene la tabla: "Fase Alta Empleado".CerrarEstadosPorBaja, en OnInsert y
    OnModify. Este script arregla lo que la migración ya dejó escrito.

    ALCANCE — sólo los estados que EMPIEZAN dentro de la fase. El que arranca DESPUÉS de la baja no
    es asunto de esa fase: es otro error, y el bloque 4 lo lista aparte en vez de taparlo.

    Bloques 1 a 3 leen. El 4 lista lo que esto NO arregla. El UPDATE del bloque 5 está comentado.
*/

USE [Migr2013R2];
GO
SET NOCOUNT ON;
GO

SELECT 'Conexión correcta: SQL Server — base ' + DB_NAME() AS GUARDIAN;

------------------------------------------------------------------------------------------------
-- 1. VOLUMEN — cuántos estados hay que recortar, abiertos y cerrados
------------------------------------------------------------------------------------------------
-- Se separan los dos casos porque no pesan igual: el abierto es el que hace daño —se solapa con
-- cualquier período posterior—, el cerrado de más es una diferencia de días acotada.
WITH Afectados AS (
    SELECT e.[No_ Empleado] AS Emp, e.[Fecha Inicio] AS Inicio, e.[Fecha Fin] AS Fin,
           f.[Fecha Baja] AS Baja,
           CASE WHEN e.[Fecha Fin] = '1753-01-01' THEN 'Abierto (sin fecha fin)'
                ELSE 'Cerrado después de la baja' END AS Caso
    FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
    JOIN   [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
           ON  f.[No_ Empleado] = e.[No_ Empleado]
           AND e.[Fecha Inicio] BETWEEN f.[Fecha Alta] AND f.[Fecha Baja]
    WHERE  e.[Tipo Entidad] = 0
      AND  f.[Fecha Baja] <> '1753-01-01'
      AND  (e.[Fecha Fin] = '1753-01-01' OR e.[Fecha Fin] > f.[Fecha Baja])
)
-- El CASE se calcula en el CTE: dentro del GROUP BY sería el Msg 144.
SELECT Caso,
       COUNT(*)                    AS Estados,
       COUNT(DISTINCT Emp)         AS Empleados,
       MAX(DATEDIFF(day, Baja, CASE WHEN Fin = '1753-01-01' THEN Baja ELSE Fin END)) AS MaxDiasDeMas
FROM   Afectados
GROUP  BY Caso
ORDER  BY Caso;

------------------------------------------------------------------------------------------------
-- 2. LOS ABIERTOS, UNO POR UNO — son los que rompen la liquidación
------------------------------------------------------------------------------------------------
SELECT e.[No_ Empleado] AS Legajo,
       em.[First Name] + ' ' + em.[Last Name] AS Nombre,
       e.[Cód_ Estado] AS Estado, e.[Fecha Inicio] AS EstadoDesde,
       e.[No_ Proyecto] AS Proyecto,
       f.[No_ Fase] AS Fase, f.[Fecha Alta] AS FaseAlta, f.[Fecha Baja] AS FaseBaja,
       f.[Cód_ Motivo Baja] AS MotivoBaja,
       DATEDIFF(day, e.[Fecha Inicio], f.[Fecha Baja]) AS DiasQueQuedan
FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
JOIN   [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
       ON  f.[No_ Empleado] = e.[No_ Empleado]
       AND e.[Fecha Inicio] BETWEEN f.[Fecha Alta] AND f.[Fecha Baja]
LEFT JOIN [dbo].[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972] em
       ON em.[No_] = e.[No_ Empleado]
WHERE  e.[Tipo Entidad] = 0
  AND  f.[Fecha Baja] <> '1753-01-01'
  AND  e.[Fecha Fin] = '1753-01-01'
ORDER  BY e.[No_ Empleado], e.[Fecha Inicio];

------------------------------------------------------------------------------------------------
-- 3. LOS CERRADOS DE MÁS — por cuántos días se pasan
------------------------------------------------------------------------------------------------
-- Si la mayoría se pasa UN día, es el mismo desfasaje de bordes que ya apareció en la migración de
-- estados y el recorte es cosmético. Si hay meses, hay que mirarlos antes de tocar.
WITH Afectados AS (
    SELECT DATEDIFF(day, f.[Fecha Baja], e.[Fecha Fin]) AS DiasDeMas
    FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
    JOIN   [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
           ON  f.[No_ Empleado] = e.[No_ Empleado]
           AND e.[Fecha Inicio] BETWEEN f.[Fecha Alta] AND f.[Fecha Baja]
    WHERE  e.[Tipo Entidad] = 0
      AND  f.[Fecha Baja] <> '1753-01-01'
      AND  e.[Fecha Fin] <> '1753-01-01'
      AND  e.[Fecha Fin] > f.[Fecha Baja]
),
Bucket AS (
    SELECT CASE WHEN DiasDeMas = 1   THEN '1 día'
                WHEN DiasDeMas <= 7  THEN '2 a 7 días'
                WHEN DiasDeMas <= 31 THEN '8 a 31 días'
                WHEN DiasDeMas <= 365 THEN '1 a 12 meses'
                ELSE                      'más de un año' END AS Tramo,
           DiasDeMas
    FROM   Afectados
)
SELECT Tramo, COUNT(*) AS Estados, MIN(DiasDeMas) AS Min_, MAX(DiasDeMas) AS Max_
FROM   Bucket
GROUP  BY Tramo
ORDER  BY MIN(DiasDeMas);

------------------------------------------------------------------------------------------------
-- 4. LO QUE ESTO NO ARREGLA — estados que arrancan DESPUÉS de toda fase
------------------------------------------------------------------------------------------------
-- El legajo 02678 es el ejemplo: fase cerrada el 23/2/2001 y un Franco que arranca el 12/3/2001,
-- diecisiete días después. No hay fase que lo contenga, así que no hay baja contra la cual
-- recortarlo: o el estado no debería existir, o falta la fase. Se decide a mano, de a uno.
SELECT e.[No_ Empleado] AS Legajo,
       em.[First Name] + ' ' + em.[Last Name] AS Nombre,
       e.[Cód_ Estado] AS Estado, e.[Fecha Inicio] AS EstadoDesde,
       CASE WHEN e.[Fecha Fin] = '1753-01-01' THEN NULL ELSE e.[Fecha Fin] END AS EstadoHasta,
       e.[No_ Proyecto] AS Proyecto,
       (SELECT MAX(f2.[Fecha Baja])
          FROM [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f2
         WHERE f2.[No_ Empleado] = e.[No_ Empleado]
           AND f2.[Fecha Baja] <> '1753-01-01') AS UltimaBaja
FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
LEFT JOIN [dbo].[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972] em
       ON em.[No_] = e.[No_ Empleado]
WHERE  e.[Tipo Entidad] = 0
  AND  NOT EXISTS (
           SELECT 1
           FROM   [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
           WHERE  f.[No_ Empleado] = e.[No_ Empleado]
             AND  f.[Fecha Alta] <= e.[Fecha Inicio]
             AND  (f.[Fecha Baja] = '1753-01-01' OR f.[Fecha Baja] >= e.[Fecha Inicio]))
ORDER  BY e.[No_ Empleado], e.[Fecha Inicio];

------------------------------------------------------------------------------------------------
-- 4.b LOS HUÉRFANOS, CLASIFICADOS — de qué lado caen y a qué distancia
------------------------------------------------------------------------------------------------
-- El bloque 4 los lista pero no los separa, y a ojo son al menos cuatro problemas distintos. Esto
-- los cuenta contra la fase MÁS CERCANA:
--   · "un día después de la baja" con estado OR  → órdenes posteriores al egreso. Es un hecho del
--     negocio, no un error de dato: la regla del modelo es la que no lo contempla.
--   · "antes del alta"                          → la fase arrancó tarde, o falta una fase anterior.
--   · "sin ninguna fase"                        → legajos nuevos cuya alta nunca migró.
--   · el resto, meses o años de distancia       → caen en el hueco entre dos fases.
--
-- Medido el 14/9/2026: los bloques 1 a 3 dieron vacíos, así que TODO lo que queda fuera de fase
-- está acá — el tope por fase de la migración ya cerró los que caían dentro.
WITH Huerfanos AS (
    SELECT e.[No_ Empleado] AS Emp, e.[Fecha Inicio] AS Inicio, e.[Cód_ Estado] AS Cod
    FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
    WHERE  e.[Tipo Entidad] = 0
      AND  NOT EXISTS (
               SELECT 1
               FROM   [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
               WHERE  f.[No_ Empleado] = e.[No_ Empleado]
                 AND  f.[Fecha Alta] <= e.[Fecha Inicio]
                 AND  (f.[Fecha Baja] = '1753-01-01' OR f.[Fecha Baja] >= e.[Fecha Inicio]))
),
-- LEFT JOIN y no JOIN: sin él se pierden justo los que no tienen NINGUNA fase, que son un caso en
-- sí mismo y no una distancia grande.
Pareado AS (
    SELECT h.Emp, h.Inicio, h.Cod,
           CASE WHEN f.[No_ Empleado] IS NULL THEN NULL
                WHEN h.Inicio < f.[Fecha Alta]
                     THEN DATEDIFF(day, h.Inicio, f.[Fecha Alta])
                WHEN f.[Fecha Baja] <> '1753-01-01' AND h.Inicio > f.[Fecha Baja]
                     THEN DATEDIFF(day, f.[Fecha Baja], h.Inicio)
                ELSE 0 END AS Dist,
           CASE WHEN f.[No_ Empleado] IS NULL       THEN 'sin ninguna fase'
                WHEN h.Inicio < f.[Fecha Alta]      THEN 'antes del alta'
                ELSE                                     'después de la baja' END AS Lado
    FROM   Huerfanos h
    LEFT JOIN [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
           ON f.[No_ Empleado] = h.Emp
),
MasCercana AS (
    SELECT Emp, Inicio, Cod, Dist, Lado,
           ROW_NUMBER() OVER (PARTITION BY Emp, Inicio ORDER BY Dist) AS Orden
    FROM   Pareado
),
Tramos AS (
    SELECT Emp, Cod, Lado, Dist,
           CASE WHEN Dist IS NULL  THEN '—'
                WHEN Dist = 1      THEN '1 día'
                WHEN Dist <= 7     THEN '2 a 7 días'
                WHEN Dist <= 31    THEN '8 a 31 días'
                WHEN Dist <= 365   THEN '1 a 12 meses'
                ELSE                    'más de un año' END AS Tramo
    FROM   MasCercana
    WHERE  Orden = 1
)
SELECT Lado, Tramo, COUNT(*) AS Estados, COUNT(DISTINCT Emp) AS Empleados
FROM   Tramos
GROUP  BY Lado, Tramo
ORDER  BY Lado, MIN(COALESCE(Dist, -1));

-- 4.c LO MISMO, ABIERTO POR CÓDIGO DE ESTADO.
--     Es lo que dice si un lado es UN fenómeno o varios mezclados: si "después de la baja, 1 día"
--     es casi todo OR, se resuelve con una regla; si está repartido, hay que mirar de a uno.
WITH Huerfanos AS (
    SELECT e.[No_ Empleado] AS Emp, e.[Fecha Inicio] AS Inicio, e.[Cód_ Estado] AS Cod
    FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
    WHERE  e.[Tipo Entidad] = 0
      AND  NOT EXISTS (
               SELECT 1
               FROM   [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
               WHERE  f.[No_ Empleado] = e.[No_ Empleado]
                 AND  f.[Fecha Alta] <= e.[Fecha Inicio]
                 AND  (f.[Fecha Baja] = '1753-01-01' OR f.[Fecha Baja] >= e.[Fecha Inicio]))
),
Pareado AS (
    SELECT h.Emp, h.Inicio, h.Cod,
           CASE WHEN f.[No_ Empleado] IS NULL THEN NULL
                WHEN h.Inicio < f.[Fecha Alta]
                     THEN DATEDIFF(day, h.Inicio, f.[Fecha Alta])
                WHEN f.[Fecha Baja] <> '1753-01-01' AND h.Inicio > f.[Fecha Baja]
                     THEN DATEDIFF(day, f.[Fecha Baja], h.Inicio)
                ELSE 0 END AS Dist,
           CASE WHEN f.[No_ Empleado] IS NULL       THEN 'sin ninguna fase'
                WHEN h.Inicio < f.[Fecha Alta]      THEN 'antes del alta'
                ELSE                                     'después de la baja' END AS Lado
    FROM   Huerfanos h
    LEFT JOIN [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
           ON f.[No_ Empleado] = h.Emp
),
MasCercana AS (
    SELECT Emp, Inicio, Cod, Dist, Lado,
           ROW_NUMBER() OVER (PARTITION BY Emp, Inicio ORDER BY Dist) AS Orden
    FROM   Pareado
)
SELECT Lado, Cod AS Estado, COUNT(*) AS Estados,
       MIN(Dist) AS DistMin, MAX(Dist) AS DistMax
FROM   MasCercana
WHERE  Orden = 1
GROUP  BY Lado, Cod
ORDER  BY Lado, COUNT(*) DESC;

------------------------------------------------------------------------------------------------
-- 4.d LOS RELLENOS QUE CRUZARON UNA BAJA — hay que borrarlos
------------------------------------------------------------------------------------------------
-- QUÉ SON. El bloque 2.b de MigrarEstados_2 tapa los huecos que deja Meta4 entre dos estados con un
-- 'OR' que dice "Generado por la migración" en Observaciones. El hueco entre una BAJA y el REINGRESO
-- no es un hueco a tapar: la persona no estaba en la empresa. Por eso ese INSERT exige una fase que
-- contenga las DOS puntas del relleno.
--
-- POR QUÉ HAY 26 IGUAL. Esa condición se agregó DESPUÉS de una corrida que ya había insertado los
-- rellenos sin ella. Con el script como está hoy no pueden volver a generarse: para 04513, la fase
-- 11 cierra el 31/3/2026 y la 12 abre el 25/5/2026, así que ninguna contiene el relleno del 1/4 al
-- 24/5 y el EXISTS da falso. Son residuo, no un defecto vigente.
--
-- POR QUÉ IMPORTAN. Un OR de 54 días sobre un período en que la persona estaba de baja son 54 días
-- que el motor cuenta como trabajados.
--
-- EL CRITERIO DEL BORRADO son las dos condiciones juntas: generado por la migración Y fuera de toda
-- fase. Un relleno que sí cae dentro de una fase es legítimo y no se toca; un estado de Meta4 fuera
-- de fase es otro problema —los 78 del 4.b— y tampoco se toca acá.
SELECT e.[No_ Empleado] AS Legajo, e.[Cód_ Estado] AS Estado,
       e.[Fecha Inicio] AS Desde,
       CASE WHEN e.[Fecha Fin] = '1753-01-01' THEN NULL ELSE e.[Fecha Fin] END AS Hasta,
       DATEDIFF(day, e.[Fecha Inicio], e.[Fecha Fin]) + 1 AS Dias,
       e.[No_ Proyecto] AS Proyecto, e.[Observaciones]
FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
WHERE  e.[Tipo Entidad] = 0
  AND  e.[Observaciones] LIKE 'Generado por la migración%'
  AND  NOT EXISTS (
           SELECT 1
           FROM   [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
           WHERE  f.[No_ Empleado] = e.[No_ Empleado]
             AND  f.[Fecha Alta] <= e.[Fecha Inicio]
             AND  (f.[Fecha Baja] = '1753-01-01' OR f.[Fecha Baja] >= e.[Fecha Inicio]))
ORDER  BY e.[No_ Empleado], e.[Fecha Inicio];

-- 4.d.2 EL BORRADO  (COMENTADO). Mirar la lista de arriba primero.
--
-- No hace falta recomponer la contigüidad después. El relleno arranca el día siguiente al fin del
-- estado anterior, así que borrarlo deja a ese estado terminando donde ya terminaba —en la baja— y
-- el hueco que queda es el correcto: los días en que la persona no estaba.
/*
BEGIN TRANSACTION;

DELETE e
FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
WHERE  e.[Tipo Entidad] = 0
  AND  e.[Observaciones] LIKE 'Generado por la migración%'
  AND  NOT EXISTS (
           SELECT 1
           FROM   [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
           WHERE  f.[No_ Empleado] = e.[No_ Empleado]
             AND  f.[Fecha Alta] <= e.[Fecha Inicio]
             AND  (f.[Fecha Baja] = '1753-01-01' OR f.[Fecha Baja] >= e.[Fecha Inicio]));

PRINT 'Rellenos borrados: ' + CAST(@@ROWCOUNT AS varchar(10));

-- 4.d.3 CONTROL — tiene que dar cero. Y el 4.b de arriba tiene que perder la fila
--       "después de la baja / 1 día", que son exactamente estos.
SELECT COUNT(*) AS DeberiaSerCero
FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
WHERE  e.[Tipo Entidad] = 0
  AND  e.[Observaciones] LIKE 'Generado por la migración%'
  AND  NOT EXISTS (
           SELECT 1
           FROM   [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
           WHERE  f.[No_ Empleado] = e.[No_ Empleado]
             AND  f.[Fecha Alta] <= e.[Fecha Inicio]
             AND  (f.[Fecha Baja] = '1753-01-01' OR f.[Fecha Baja] >= e.[Fecha Inicio]));

-- COMMIT TRANSACTION;  /  ROLLBACK TRANSACTION;
*/

------------------------------------------------------------------------------------------------
-- 5. EL RECORTE  (COMENTADO)
------------------------------------------------------------------------------------------------
-- NOTA del 14/9/2026: los bloques 1 a 3 dieron VACÍOS. El tope por fase del bloque 6 de
-- MigrarEstados_2 ya había cerrado todos los estados que caían dentro de una fase cerrada, así que
-- este UPDATE no tiene nada que hacer. Se conserva porque el caso vuelve con cada carga nueva de
-- fases por migración —el camino por AL sí está cubierto, por CerrarEstadosPorBaja—.
--
-- Mirar los bloques 1 a 3 antes. Pone la fecha fin del estado en la baja de la fase que lo contiene.
--
-- Por SQL y no por AL: el OnModify de "Estado Empleado" empuja el estado siguiente cuando cambia la
-- fecha fin, y acá no hay que arrastrar nada — lo que venga después pertenece a otra fase. Es la
-- misma razón por la que CerrarEstadosPorBaja usa Modify(false).
--
-- MIN(f.[Fecha Baja]) y no una sola fase: las fases no se superponen —lo valida la tabla— así que
-- hay exactamente una que contiene a cada estado, y el MIN es la forma de agregarla sin arriesgar
-- que un dato viejo con superposición multiplique la fila.
/*
BEGIN TRANSACTION;

WITH Tope AS (
    SELECT e.[No_ Empleado] AS Emp, e.[Fecha Inicio] AS Inicio,
           MIN(f.[Fecha Baja]) AS NuevoFin
    FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
    JOIN   [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
           ON  f.[No_ Empleado] = e.[No_ Empleado]
           AND e.[Fecha Inicio] BETWEEN f.[Fecha Alta] AND f.[Fecha Baja]
    WHERE  e.[Tipo Entidad] = 0
      AND  f.[Fecha Baja] <> '1753-01-01'
      AND  (e.[Fecha Fin] = '1753-01-01' OR e.[Fecha Fin] > f.[Fecha Baja])
    GROUP  BY e.[No_ Empleado], e.[Fecha Inicio]
)
UPDATE e
SET    e.[Fecha Fin] = t.NuevoFin,
       e.[$systemModifiedAt] = SYSUTCDATETIME()
FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
JOIN   Tope t ON t.Emp = e.[No_ Empleado] AND t.Inicio = e.[Fecha Inicio]
WHERE  e.[Tipo Entidad] = 0;

PRINT 'Estados recortados: ' + CAST(@@ROWCOUNT AS varchar(10));

-- 5.b CONTROL — después del UPDATE esto tiene que dar cero.
SELECT COUNT(*) AS DeberiaSerCero
FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
JOIN   [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
       ON  f.[No_ Empleado] = e.[No_ Empleado]
       AND e.[Fecha Inicio] BETWEEN f.[Fecha Alta] AND f.[Fecha Baja]
WHERE  e.[Tipo Entidad] = 0
  AND  f.[Fecha Baja] <> '1753-01-01'
  AND  (e.[Fecha Fin] = '1753-01-01' OR e.[Fecha Fin] > f.[Fecha Baja]);

-- COMMIT TRANSACTION;  /  ROLLBACK TRANSACTION;
*/
