/*
    GUARDIA EN PUERTO, DIQUE Y PILOTAJE NO SON MAREA

    EL ERROR. MigrarEstados decidió el proyecto de cada estado con "Devenga Francos":

        Devenga Francos = Sí  (DQ GP NV PI PL PS)  ->  PP-<buque>-<marea>
        Devenga Francos = No  (FR OR OI AU*)       ->  PN-<buque>-NOMINA

    Esa bandera contesta "¿se trabaja?", no "¿está en una marea?". Coinciden para NV (navegación),
    PS (puerto salida) y PL (puerto llegada). NO coinciden para GP (guardia en puerto), DQ (dique) y
    PI (pilotaje): se trabaja y se devengan francos, pero en tierra, fuera del viaje.

    LO QUE DEJÓ. 12.324 guardias en puerto colgadas del proyecto de la marea anterior, una de ellas
    3.904 días después del arribo — porque el ID_MAREA de Meta4 se congela cuando el barco llega y la
    tripulación queda en tierra. Más 2.120 pilotajes y 1.038 diques.

    CÓMO SE DISTINGUE EN LOS DATOS, y es lo que confirmó el diagnóstico:
        PL después del arribo   1.587 estados, NINGUNO a más de 3 días   -> evento de borde: es marea
        PS antes de la zarpada 10.004 estados, 9.221 a 3 días o menos    -> evento de borde: es marea
        GP después del arribo  12.324 estados, cola hasta 3.904 días     -> no es un borde: es tierra

    DE ACÁ EN ADELANTE lo decide la configuración, no el código: el campo "Transcurre en Marea" de
    "Cód. Estado Empleado", que lee ResolverProyectoInactividad (Cod50017). El bloque 1 lo carga.

    ORDEN: 1 marca el catálogo, 2 y 3 miden, 4 mueve los estados, 5 rehace las asignaciones.
    Los UPDATE de los bloques 4 y 5 están comentados.
*/

USE [Migr2013R2];
GO
SET NOCOUNT ON;
GO

SELECT 'Conexión correcta: SQL Server — base ' + DB_NAME() AS GUARDIAN;

------------------------------------------------------------------------------------------------
-- 1. MARCAR EL CATÁLOGO  (requiere el build con el campo "Transcurre en Marea")
------------------------------------------------------------------------------------------------
-- Si esto da error de columna inexistente, falta publicar. El campo es nuevo en Tab60003.
--
-- Sólo NV, PS y PL. Todo lo demás queda en No, que es el valor por defecto de un booleano nuevo:
-- los estados de tierra (FR OR OI AU*) ya estaban bien y no cambian de proyecto.
SELECT [Código], [Descripción], [Devenga Francos], [Transcurre en Marea]
FROM   [dbo].[ArbuTest$Cód_ Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
ORDER  BY [Código];

/*
UPDATE [dbo].[ArbuTest$Cód_ Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
SET    [Transcurre en Marea] = 1
WHERE  [Código] IN ('NV', 'PS', 'PL');
*/

------------------------------------------------------------------------------------------------
-- 2. VOLUMEN — cuántos estados se mueven, por código
------------------------------------------------------------------------------------------------
-- Son los que están en un proyecto de marea y NO transcurren en marea. Se cuentan aparte los que
-- caen dentro de la ventana del Job: ésos parecían correctos y también están mal.
WITH Mover AS (
    SELECT e.[Cód_ Estado] AS Cod, e.[No_ Proyecto] AS Proy, e.[Fecha Inicio] AS Inicio,
           j.[Starting Date] AS Zarpada, j.[Ending Date] AS Arribo,
           CASE WHEN j.[Ending Date] = '1753-01-01'            THEN 'c. Marea sin arribo'
                WHEN e.[Fecha Inicio] > j.[Ending Date]        THEN 'a. Después del arribo'
                ELSE                                                'b. Dentro de la ventana' END AS Ubicacion
    FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
    JOIN   [dbo].[ArbuTest$Job$437dbf0e-84ff-417a-965d-ed2bb9650972] j ON j.[No_] = e.[No_ Proyecto]
    WHERE  e.[Tipo Entidad] = 0
      AND  e.[No_ Proyecto] LIKE 'PP-%'
      AND  e.[Cód_ Estado] IN ('GP', 'DQ', 'PI')
)
-- El CASE se resuelve en el CTE: dentro del GROUP BY sería el Msg 144.
SELECT Cod AS Estado, Ubicacion, COUNT(*) AS Estados, COUNT(DISTINCT Proy) AS Proyectos
FROM   Mover
GROUP  BY Cod, Ubicacion
ORDER  BY Cod, Ubicacion;

------------------------------------------------------------------------------------------------
-- 3. ¿EXISTE EL PROYECTO DESTINO? — antes de mover, verificar
------------------------------------------------------------------------------------------------
-- El destino es PN-<buque>-NOMINA, con el buque sacado del propio código del proyecto de marea:
-- PP-114-000311 -> PN-114-NOMINA. Si alguno de esos Job no existe, esas filas no se pueden mover y
-- hay que crearlos primero — igual que en la migración original.
WITH Destinos AS (
    SELECT DISTINCT
           e.[No_ Proyecto] AS ProyOrigen,
           'PN-' + SUBSTRING(e.[No_ Proyecto], 4, CHARINDEX('-', e.[No_ Proyecto], 4) - 4) + '-NOMINA' AS ProyDestino
    FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
    WHERE  e.[Tipo Entidad] = 0
      AND  e.[No_ Proyecto] LIKE 'PP-%-%'
      AND  e.[Cód_ Estado] IN ('GP', 'DQ', 'PI')
)
SELECT d.ProyDestino,
       COUNT(*) AS MareasQueLoNecesitan,
       MAX(CASE WHEN j.[No_] IS NULL THEN 'FALTA — hay que crearlo' ELSE 'existe' END) AS Estado
FROM   Destinos d
LEFT JOIN [dbo].[ArbuTest$Job$437dbf0e-84ff-417a-965d-ed2bb9650972] j ON j.[No_] = d.ProyDestino
GROUP  BY d.ProyDestino
ORDER  BY Estado DESC, d.ProyDestino;

------------------------------------------------------------------------------------------------
-- 3.b LOS BUQUES SIN PROYECTO DE NÓMINA — cuánto queda sin mover si no se crean
------------------------------------------------------------------------------------------------
-- Medido el 14/9/2026 faltan tres: PN-111, PN-112 y PN-127, de barcos que ya no pertenecen a la
-- empresa. La decisión no es sólo de volumen: mientras esos estados sigan colgados de una marea, el
-- control 4.b nunca da cero y cada auditoría futura los vuelve a mostrar. Crear los tres Job —en
-- estado cerrado, copiando la configuración de cualquier PN-<buque>-NOMINA existente— cuesta tres
-- altas y deja todos los controles limpios.
WITH Huerfanos AS (
    SELECT e.[Cód_ Estado] AS Cod, e.[No_ Empleado] AS Emp, e.[Fecha Inicio] AS Inicio,
           'PN-' + SUBSTRING(e.[No_ Proyecto], 4, CHARINDEX('-', e.[No_ Proyecto], 4) - 4) + '-NOMINA' AS ProyDestino
    FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
    WHERE  e.[Tipo Entidad] = 0
      AND  e.[No_ Proyecto] LIKE 'PP-%-%'
      AND  e.[Cód_ Estado] IN ('GP', 'DQ', 'PI')
)
SELECT h.ProyDestino,
       COUNT(*)                  AS EstadosSinMover,
       COUNT(DISTINCT h.Emp)     AS Empleados,
       MIN(h.Inicio)             AS Desde,
       MAX(h.Inicio)             AS Hasta
FROM   Huerfanos h
WHERE  NOT EXISTS (SELECT 1 FROM [dbo].[ArbuTest$Job$437dbf0e-84ff-417a-965d-ed2bb9650972] j
                   WHERE j.[No_] = h.ProyDestino)
GROUP  BY h.ProyDestino
ORDER  BY COUNT(*) DESC;

------------------------------------------------------------------------------------------------
-- 4. MOVER LOS ESTADOS  (COMENTADO)
------------------------------------------------------------------------------------------------
-- Correr el bloque 3 primero: si falta algún PN-<buque>-NOMINA, esas filas quedan sin mover.
--
-- Por SQL y no por AL: el OnModify de "Estado Empleado" empuja el estado siguiente y valida contra
-- liquidaciones. Acá no cambian las FECHAS, sólo el proyecto, así que la contigüidad del historial
-- no se toca — y no hay nada que empujar.
/*
BEGIN TRANSACTION;

UPDATE e
SET    e.[No_ Proyecto] = d.ProyDestino,
       e.[$systemModifiedAt] = SYSUTCDATETIME()
FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
CROSS APPLY (
    SELECT 'PN-' + SUBSTRING(e.[No_ Proyecto], 4, CHARINDEX('-', e.[No_ Proyecto], 4) - 4) + '-NOMINA' AS ProyDestino
) d
WHERE  e.[Tipo Entidad] = 0
  AND  e.[No_ Proyecto] LIKE 'PP-%-%'
  AND  e.[Cód_ Estado] IN ('GP', 'DQ', 'PI')
  AND  EXISTS (SELECT 1 FROM [dbo].[ArbuTest$Job$437dbf0e-84ff-417a-965d-ed2bb9650972] j
               WHERE j.[No_] = d.ProyDestino);

PRINT 'Estados movidos a nómina: ' + CAST(@@ROWCOUNT AS varchar(10));

-- 4.b CONTROL — tiene que quedar sólo lo que no tenía proyecto de nómina donde ir.
SELECT COUNT(*) AS QuedanEnMarea
FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
WHERE  [Tipo Entidad] = 0 AND [No_ Proyecto] LIKE 'PP-%' AND [Cód_ Estado] IN ('GP', 'DQ', 'PI');

-- COMMIT TRANSACTION;  /  ROLLBACK TRANSACTION;
*/

------------------------------------------------------------------------------------------------
-- 5. REHACER LAS ASIGNACIONES  (COMENTADO — correr DESPUÉS del bloque 4)
------------------------------------------------------------------------------------------------
-- Las asignaciones de "Personal Proyecto" se derivaron del primer y el último estado del empleado en
-- cada proyecto. Al mover los GP/DQ/PI, esas fechas cambian: la asignación a la marea tiene que
-- terminar en el último estado que SIGUE siendo de marea.
--
-- Esto es también lo que hace desaparecer solas buena parte de las 7.690 bajas posteriores al arribo
-- y de las 5.186 asignaciones que arrancaban después: no eran asignaciones mal fechadas, eran
-- asignaciones que no correspondían a ese proyecto.
--
-- No crea las asignaciones al proyecto de nómina que puedan faltar: eso lo hace MigrarPersonalProyecto_4,
-- que hay que volver a correr después de esto.
/*
BEGIN TRANSACTION;

WITH Reales AS (
    SELECT e.[No_ Empleado] AS Emp, e.[No_ Proyecto] AS Proy,
           MIN(e.[Fecha Inicio]) AS Desde,
           -- Si algún estado del par quedó abierto, la asignación queda abierta: el MAX sobre la
           -- fecha en blanco daría 1753 y no una fecha grande.
           CASE WHEN MAX(CASE WHEN e.[Fecha Fin] = '1753-01-01' THEN 1 ELSE 0 END) = 1
                THEN '1753-01-01'
                ELSE MAX(e.[Fecha Fin]) END AS Hasta
    FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
    WHERE  e.[Tipo Entidad] = 0 AND e.[No_ Proyecto] <> ''
    GROUP  BY e.[No_ Empleado], e.[No_ Proyecto]
)
UPDATE pp
SET    pp.[Fecha Alta Asignación] = r.Desde,
       pp.[Fecha Baja]            = r.Hasta,
       pp.[$systemModifiedAt]     = SYSUTCDATETIME()
FROM   [dbo].[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
JOIN   Reales r ON r.Emp = pp.[No_ Empleado] AND r.Proy = pp.[No_ Proyecto]
WHERE  pp.[Fecha Alta Asignación] <> r.Desde OR pp.[Fecha Baja] <> r.Hasta;

PRINT 'Asignaciones refechadas: ' + CAST(@@ROWCOUNT AS varchar(10));

-- 5.b LAS QUE QUEDARON SIN NINGÚN ESTADO. Al mover los GP/DQ/PI, un empleado cuya única presencia en
--     esa marea eran guardias en puerto ya no tiene nada que lo vincule: esa asignación hay que
--     borrarla, no refecharla.
--
--     EL FILTRO POR OBSERVACIONES NO ES DECORATIVO. MigrarPersonalProyecto_4 firma cada fila que
--     crea con "Generado por la migración a partir del historial de estados."; sin ese filtro, el
--     borrado alcanzaría también a una asignación cargada A MANO en BC cuyo estado alguien borró
--     después, que es un caso distinto y no se resuelve borrando la asignación. Es la misma guarda
--     que se usó para los rellenos OR en CerrarEstadosPorBaja.
SELECT COUNT(*) AS ASinRespaldo,
       COUNT(DISTINCT pp.[No_ Empleado]) AS Empleados,
       COUNT(DISTINCT pp.[No_ Proyecto]) AS Proyectos
FROM   [dbo].[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
WHERE  pp.[Observaciones] LIKE 'Generado por la migración%'
  AND  NOT EXISTS (
           SELECT 1 FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
           WHERE e.[Tipo Entidad] = 0
             AND e.[No_ Empleado] = pp.[No_ Empleado]
             AND e.[No_ Proyecto] = pp.[No_ Proyecto]);

-- 5.b.2 Las que NO tienen la firma de la migración. Tendría que dar cero o muy poco; si aparecen
--       muchas, son asignaciones cargadas a mano sin estado y es otro problema — mirarlas antes.
SELECT pp.[No_ Empleado] AS Legajo, pp.[No_ Proyecto] AS Proyecto,
       pp.[Fecha Alta Asignación] AS Desde, pp.[Fecha Baja] AS Hasta, pp.[Observaciones]
FROM   [dbo].[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
WHERE  pp.[Observaciones] NOT LIKE 'Generado por la migración%'
  AND  NOT EXISTS (
           SELECT 1 FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
           WHERE e.[Tipo Entidad] = 0
             AND e.[No_ Empleado] = pp.[No_ Empleado]
             AND e.[No_ Proyecto] = pp.[No_ Proyecto]);

-- 5.c EL BORRADO de las que sí tienen la firma.
--
--     Por SQL y no por AL: el OnDelete de "Personal Proyecto" llama a EliminarEstadoDeProyecto, que
--     borraría estados del empleado en ese proyecto. Acá justamente NO hay ninguno —por eso se
--     borra la fila— pero dejar correr el trigger sobre 900 filas es pedir un efecto que nadie
--     revisó.
DELETE pp
FROM   [dbo].[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
WHERE  pp.[Observaciones] LIKE 'Generado por la migración%'
  AND  NOT EXISTS (
           SELECT 1 FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e
           WHERE e.[Tipo Entidad] = 0
             AND e.[No_ Empleado] = pp.[No_ Empleado]
             AND e.[No_ Proyecto] = pp.[No_ Proyecto]);

PRINT 'Asignaciones sin respaldo borradas: ' + CAST(@@ROWCOUNT AS varchar(10));

-- COMMIT TRANSACTION;  /  ROLLBACK TRANSACTION;
*/
