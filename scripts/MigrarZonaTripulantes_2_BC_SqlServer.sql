/*
    PASO 2 de 2 — se ejecuta en la conexión **BC** (SQL Server).

    Toma dbo.MIG_ZonaTripulantesM4 (cargada con MigrarZonaTripulantes_1_Meta4_Oracle.sql) y la convierte
    en vigencias del atributo ZONA_DESFAVORABLE (COD_ZONA) de los tripulantes. Con eso CRED_IVA_814
    calcula el crédito fiscal IVA de las contribuciones como Meta4, y CNT_SAC_DEV le resta la alícuota.
    Pedido por el usuario el 26/10/2026; ver Vault/04 Integraciones/Asiento de sueldos.md.

    QUÉ NO MUEVE. Para los convenios de la tripulación (729/15, 175/75, 768/19, ESP) no hay
    PCT_ZONA_DESF, así que el 2703 (adicional por zona) sigue sin pagar; y el 2704 da cero y no se
    imprime. El bloque de controles lo verifica: ningún tripulante tiene convenio FA ni 372/04, que
    son los que sí tienen porcentaje. Ver la lección atributo-cargado-que-nadie-lee: el atributo es el
    domicilio para el adicional y acá pasa a ser también la zona DGI.

    LOS TRAMOS. Por empleado, en orden de fecha de imputación de Meta4: cada vez que la zona cambia
    arranca un tramo nuevo ESE día (el del 802 que pasó a Mar del Plata: cierre del 13/3 en 29,
    regular del 25/3 en 07, y el cierre de marea de BC del 22/3 queda en 29). El primero arranca el
    1/1/2026; cada uno cierra el día antes del siguiente; el último queda abierto. Meta4 da la zona
    con dos dígitos (07) y el valor de BC es 7: se traduce por número.

    LAS FILAS QUE YA ESTABAN. 47 tripulantes ya tenían la zona desde el 1/1/2026. Si coincide con los
    tramos, no se toca; si no (dos, que tenían cargada la última zona de Meta4 para todo el año), se
    reemplazan sus filas desde 2026. Es un DELETE: hasta publicar o reiniciar el servicio, BC puede
    seguir viendo la fila vieja (lección sql-directo-deja-cache-rancia).

    POR QUÉ POR SQL Y NO POR AL. Lo que el OnInsert de Atributo Entidad Liq. calcularía se calcula acá:
    el cierre contra la siguiente (SincronizarContiguidad), el Valor Numérico del Valor Atributo
    (RecalcularValorNumerico, tipo Lista) y el padre, que la zona no tiene.

    @Aplicar = 0 (por defecto) muestra todo y vuelve atrás.
*/
SET XACT_ABORT ON; SET NOCOUNT ON;
DECLARE @Aplicar bit = 0;
DECLARE @Desde date = '20260101';
DECLARE @Tipo nvarchar(20) = N'ZONA_DESFAVORABLE';

SELECT 'Conexión correcta: SQL Server — base ' + DB_NAME() AS GUARDIAN;
IF OBJECT_ID(N'dbo.MIG_ZonaTripulantesM4') IS NULL
BEGIN RAISERROR('Falta dbo.MIG_ZonaTripulantesM4: cargarla con la salida del paso 1.', 16, 1); RETURN; END;

BEGIN TRAN;

/* ---------- 1. Tramos ---------- */
IF OBJECT_ID('tempdb..#Tramo') IS NOT NULL DROP TABLE #Tramo;
WITH R AS (
    SELECT m.Emp, m.Fecha, m.TpImput, CAST(TRY_CAST(m.Zona AS int) AS nvarchar(20)) AS Zona
    FROM dbo.MIG_ZonaTripulantesM4 m
    WHERE m.Fecha >= @Desde AND m.Convenio IN (N'MR', N'OF', N'FE') AND TRY_CAST(m.Zona AS int) IS NOT NULL),
O AS (SELECT R.*, LAG(R.Zona) OVER (PARTITION BY R.Emp ORDER BY R.Fecha, R.TpImput) AS Prev FROM R),
C AS (SELECT O.Emp, O.Fecha, O.Zona FROM O WHERE O.Prev IS NULL OR O.Prev <> O.Zona),
S AS (SELECT C.Emp, C.Zona, C.Fecha AS PrimerRegistro,
             CASE WHEN ROW_NUMBER() OVER (PARTITION BY C.Emp ORDER BY C.Fecha) = 1 THEN @Desde ELSE C.Fecha END AS VigDesde,
             LEAD(C.Fecha) OVER (PARTITION BY C.Emp ORDER BY C.Fecha) AS Sig
      FROM C)
SELECT S.Emp, S.Zona, S.PrimerRegistro, S.VigDesde, CASE WHEN S.Sig IS NULL THEN CAST('17530101' AS date) ELSE DATEADD(day, -1, S.Sig) END AS VigHasta
INTO #Tramo FROM S;

-- El primero arranca en el alta si el tripulante entró en 2026 (TIPOEMPLEADO = TRIPUL arranca ahí):
-- una zona anterior al alta no le sirve a ninguna liquidación y deja al atributo diciendo algo de
-- alguien que todavía no era empleado. Es el alta de la fase vigente en la fecha del PRIMER registro
-- de Meta4, no la última: un reingreso de mayo no puede dejar sin zona las liquidaciones de enero.
-- Si no hay ninguna fase abierta a esa fecha es porque Meta4 imputa la mensual el 25 y el alta fue
-- después (entró el 27/3, primer registro el 25/3): entonces la primera alta de 2026.
UPDATE t SET t.VigDesde = COALESCE(f.Alta, g.Alta)
FROM #Tramo t
CROSS APPLY (SELECT MAX(fa.[Fecha Alta]) AS Alta FROM dbo.[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] fa
             WHERE fa.[No_ Empleado] = t.Emp AND fa.[Fecha Alta] <= t.PrimerRegistro) f
CROSS APPLY (SELECT MIN(fa.[Fecha Alta]) AS Alta FROM dbo.[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] fa
             WHERE fa.[No_ Empleado] = t.Emp AND fa.[Fecha Alta] > @Desde) g
WHERE t.VigDesde = @Desde AND COALESCE(f.Alta, g.Alta) > @Desde;
-- Ningún tramo puede quedar arrancando después de terminar (el alta cayó después del cambio de zona).
IF EXISTS (SELECT 1 FROM #Tramo WHERE VigHasta <> '17530101' AND VigHasta < VigDesde)
BEGIN SELECT * FROM #Tramo WHERE VigHasta <> '17530101' AND VigHasta < VigDesde;
      RAISERROR('El alta quedó después del fin del primer tramo.', 16, 1); ROLLBACK; RETURN; END;
ALTER TABLE #Tramo DROP COLUMN PrimerRegistro;

SELECT COUNT(DISTINCT Emp) AS Tripulantes, COUNT(*) AS Tramos,
       SUM(CASE WHEN Zona = N'7' THEN 1 ELSE 0 END) AS En_07, SUM(CASE WHEN Zona = N'29' THEN 1 ELSE 0 END) AS En_29,
       SUM(CASE WHEN Zona NOT IN (N'7', N'29') THEN 1 ELSE 0 END) AS Otras_zonas
FROM #Tramo;

/* ---------- 2. Controles que pueden fallar ---------- */
-- Todos son tripulantes en BC a la fecha de su tramo.
IF EXISTS (SELECT 1 FROM #Tramo t WHERE NOT EXISTS (
        SELECT 1 FROM dbo.[ArbuTest$Atributo Entidad Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] a
        WHERE a.[Tipo Entidad] = 0 AND a.[Cód_ Entidad] = t.Emp AND a.[Cód_ Tipo Atributo] = N'TIPOEMPLEADO' AND a.[Cód_ Valor] = N'TRIPUL'
          AND a.[Vigencia Desde] <= t.VigDesde AND (a.[Vigencia Hasta] = '17530101' OR a.[Vigencia Hasta] >= t.VigDesde)))
BEGIN SELECT t.* FROM #Tramo t WHERE NOT EXISTS (
        SELECT 1 FROM dbo.[ArbuTest$Atributo Entidad Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] a
        WHERE a.[Tipo Entidad] = 0 AND a.[Cód_ Entidad] = t.Emp AND a.[Cód_ Tipo Atributo] = N'TIPOEMPLEADO' AND a.[Cód_ Valor] = N'TRIPUL'
          AND a.[Vigencia Desde] <= t.VigDesde AND (a.[Vigencia Hasta] = '17530101' OR a.[Vigencia Hasta] >= t.VigDesde));
      RAISERROR('Hay tramos de empleados que no son TRIPUL en BC.', 16, 1); ROLLBACK; RETURN; END;
-- Ninguno tiene un convenio con PCT_ZONA_DESF (el 2703 empezaría a pagar).
IF EXISTS (SELECT 1 FROM #Tramo t JOIN dbo.[ArbuTest$Atributo Entidad Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] a
             ON a.[Tipo Entidad] = 0 AND a.[Cód_ Entidad] = t.Emp AND a.[Cód_ Tipo Atributo] = N'CONVENIO'
            AND (a.[Vigencia Hasta] = '17530101' OR a.[Vigencia Hasta] >= @Desde)
           WHERE a.[Cód_ Valor] IN (SELECT p.[Cód_ Convenio] FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] p
                                    WHERE p.[Cód_ Parámetro] LIKE N'PCT[_]ZONA[_]DESF%' AND p.[Cód_ Convenio] <> N''))
BEGIN RAISERROR('Hay tripulantes con un convenio que paga adicional por zona.', 16, 1); ROLLBACK; RETURN; END;
-- La zona existe como valor del atributo.
IF EXISTS (SELECT 1 FROM #Tramo t WHERE NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Valor Atributo Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] v
                                                      WHERE v.[Cód_ Tipo Atributo] = @Tipo AND v.[Cód_ Valor Padre] = N'' AND v.[Código] = t.Zona))
BEGIN SELECT DISTINCT t.Zona AS Zona_sin_valor FROM #Tramo t WHERE NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Valor Atributo Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] v
                                                      WHERE v.[Cód_ Tipo Atributo] = @Tipo AND v.[Cód_ Valor Padre] = N'' AND v.[Código] = t.Zona);
      RAISERROR('Hay zonas que no existen como valor de ZONA_DESFAVORABLE.', 16, 1); ROLLBACK; RETURN; END;
-- Tramos bien formados: contiguos y sin superponerse.
IF EXISTS (SELECT 1 FROM #Tramo t WHERE t.VigHasta <> '17530101' AND t.VigHasta < t.VigDesde)
BEGIN RAISERROR('Hay un tramo que termina antes de empezar.', 16, 1); ROLLBACK; RETURN; END;
-- Las filas que ya estaban: no se maneja una que arranque antes de 2026 (habría que cerrarla, no borrarla).
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Atributo Entidad Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] a
           WHERE a.[Tipo Entidad] = 0 AND a.[Cód_ Tipo Atributo] = @Tipo AND a.[Cód_ Entidad] IN (SELECT Emp FROM #Tramo)
             AND a.[Vigencia Desde] < @Desde AND (a.[Vigencia Hasta] = '17530101' OR a.[Vigencia Hasta] >= @Desde))
BEGIN RAISERROR('Hay tripulantes con una zona que arranca antes de 2026 y sigue vigente: revisar a mano.', 16, 1); ROLLBACK; RETURN; END;

/* ---------- 3. Qué cambia ---------- */
IF OBJECT_ID('tempdb..#Existente') IS NOT NULL DROP TABLE #Existente;
SELECT a.[Cód_ Entidad] AS Emp, a.[Cód_ Valor] AS Zona, a.[Vigencia Desde] AS VigDesde, a.[Vigencia Hasta] AS VigHasta
INTO #Existente
FROM dbo.[ArbuTest$Atributo Entidad Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] a
WHERE a.[Tipo Entidad] = 0 AND a.[Cód_ Tipo Atributo] = @Tipo AND a.[Cód_ Entidad] IN (SELECT Emp FROM #Tramo) AND a.[Vigencia Desde] >= @Desde;

IF OBJECT_ID('tempdb..#Estado') IS NOT NULL DROP TABLE #Estado;
SELECT e.Emp,
       CASE WHEN NOT EXISTS (SELECT 1 FROM #Existente x WHERE x.Emp = e.Emp) THEN N'NUEVO'
            WHEN NOT EXISTS (SELECT t.Zona, t.VigDesde, t.VigHasta FROM #Tramo t WHERE t.Emp = e.Emp
                             EXCEPT SELECT x.Zona, x.VigDesde, x.VigHasta FROM #Existente x WHERE x.Emp = e.Emp)
             AND NOT EXISTS (SELECT x.Zona, x.VigDesde, x.VigHasta FROM #Existente x WHERE x.Emp = e.Emp
                             EXCEPT SELECT t.Zona, t.VigDesde, t.VigHasta FROM #Tramo t WHERE t.Emp = e.Emp) THEN N'IGUAL'
            ELSE N'REEMPLAZA' END AS Estado
INTO #Estado
FROM (SELECT DISTINCT Emp FROM #Tramo) e;

SELECT Estado, COUNT(*) AS Tripulantes FROM #Estado GROUP BY Estado;
SELECT s.Emp, N'antes' AS Cual, x.Zona, x.VigDesde, x.VigHasta FROM #Estado s JOIN #Existente x ON x.Emp = s.Emp WHERE s.Estado = N'REEMPLAZA'
UNION ALL
SELECT s.Emp, N'después', t.Zona, t.VigDesde, t.VigHasta FROM #Estado s JOIN #Tramo t ON t.Emp = s.Emp WHERE s.Estado = N'REEMPLAZA'
ORDER BY 1, 2 DESC, 4;

/* ---------- 4. Escritura ---------- */
DELETE a FROM dbo.[ArbuTest$Atributo Entidad Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] a
JOIN #Estado s ON s.Emp = a.[Cód_ Entidad] AND s.Estado = N'REEMPLAZA'
WHERE a.[Tipo Entidad] = 0 AND a.[Cód_ Tipo Atributo] = @Tipo AND a.[Vigencia Desde] >= @Desde;
SELECT @@ROWCOUNT AS Filas_borradas;

INSERT dbo.[ArbuTest$Atributo Entidad Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
 ([Tipo Entidad],[Cód_ Entidad],[Cód_ Tipo Atributo],[Vigencia Desde],[Vigencia Hasta],[Cód_ Valor],[Valor Decimal],[Valor Texto],[Valor Fecha],
  [Valor Numérico],[Cód_ Valor Padre],[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy])
SELECT 0, t.Emp, @Tipo, t.VigDesde, t.VigHasta, t.Zona, 0, N'', '17530101', v.[Valor Numérico], N'',
       NEWID(), SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000', SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000'
FROM #Tramo t
JOIN #Estado s ON s.Emp = t.Emp AND s.Estado IN (N'NUEVO', N'REEMPLAZA')
JOIN dbo.[ArbuTest$Valor Atributo Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] v ON v.[Cód_ Tipo Atributo] = @Tipo AND v.[Cód_ Valor Padre] = N'' AND v.[Código] = t.Zona;
SELECT @@ROWCOUNT AS Filas_insertadas;

/* ---------- 5. Verificación: cada tripulante quedó exactamente con sus tramos ---------- */
IF EXISTS (SELECT t.Emp, t.Zona, t.VigDesde, t.VigHasta FROM #Tramo t
           EXCEPT
           SELECT a.[Cód_ Entidad], a.[Cód_ Valor], a.[Vigencia Desde], a.[Vigencia Hasta]
           FROM dbo.[ArbuTest$Atributo Entidad Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] a
           WHERE a.[Tipo Entidad] = 0 AND a.[Cód_ Tipo Atributo] = @Tipo AND a.[Vigencia Desde] >= @Desde)
   OR EXISTS (SELECT a.[Cód_ Entidad], a.[Cód_ Valor], a.[Vigencia Desde], a.[Vigencia Hasta]
           FROM dbo.[ArbuTest$Atributo Entidad Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] a
           WHERE a.[Tipo Entidad] = 0 AND a.[Cód_ Tipo Atributo] = @Tipo AND a.[Vigencia Desde] >= @Desde AND a.[Cód_ Entidad] IN (SELECT Emp FROM #Tramo)
           EXCEPT SELECT t.Emp, t.Zona, t.VigDesde, t.VigHasta FROM #Tramo t)
BEGIN RAISERROR('La verificación no cierra: los tramos cargados no son los calculados.', 16, 1); ROLLBACK; RETURN; END;
-- Cobertura: toda liquidación de 2026 de estos tripulantes tiene su zona a la fecha. Una sin zona
-- no da crédito IVA; se lista para revisar (no frena: puede ser una liquidación de una fase que
-- Meta4 ya no tiene, como un egreso de enero).
SELECT l.[No_ Empleado] AS Liquidacion_sin_zona, l.[Cód_ Período], l.[Cód_ Tipo Liq_], l.[Fecha Liquidación]
FROM dbo.[ArbuTest$Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] l
WHERE l.[No_ Empleado] IN (SELECT Emp FROM #Tramo) AND l.[Fecha Liquidación] >= @Desde AND l.[Cód_ Tipo Liq_] NOT IN (N'HIST_REMUN', N'SALDO_INICIAL')
  AND NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Atributo Entidad Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] a
                  WHERE a.[Tipo Entidad] = 0 AND a.[Cód_ Entidad] = l.[No_ Empleado] AND a.[Cód_ Tipo Atributo] = @Tipo
                    AND a.[Vigencia Desde] <= l.[Fecha Liquidación] AND (a.[Vigencia Hasta] = '17530101' OR a.[Vigencia Hasta] >= l.[Fecha Liquidación]))
ORDER BY 1, 4;
-- Ninguna fila de otro empleado se tocó.
SELECT COUNT(*) AS Filas_zona_no_tripulantes FROM dbo.[ArbuTest$Atributo Entidad Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] a
WHERE a.[Tipo Entidad] = 0 AND a.[Cód_ Tipo Atributo] = @Tipo AND a.[Cód_ Entidad] NOT IN (SELECT Emp FROM #Tramo);

IF @Aplicar = 1 BEGIN COMMIT; PRINT 'Aplicado. Publicar o reiniciar el servicio antes de recalcular (se borraron filas).'; END
ELSE BEGIN ROLLBACK; PRINT 'Prueba: se volvió todo atrás. Poner @Aplicar = 1 para confirmar.'; END;
