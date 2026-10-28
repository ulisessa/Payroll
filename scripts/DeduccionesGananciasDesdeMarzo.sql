/* DEDUCCIONES DE GANANCIAS DE LOS EMPLEADOS: RIGEN DESDE MARZO (23/10/2026). Las filas de "Ded. Ganancias Empleado" se cargaron el 22/10 con vigencia desde el 1/1 y el 1/2, y al recalcular enero y febrero BC deducía lo que Meta4 no
   deducía (04455: Ganancias -153.131 en enero y -297.774 en febrero; 04921: -63.960). Indicación del usuario: rigen desde marzo; se borran las de enero y febrero.
   Para no perder una deducción que sólo tiene fila en enero o febrero, se hace por (empleado, tipo):
     - si ya hay una fila del 1/3 en adelante, se borran las de enero y febrero;
     - si no, la última fila de enero o febrero (la que rige en marzo) se pasa al 1/3 y se borran las anteriores.
   Antes de correr se guardan las filas en un CSV fuera del repo (datos de empleados).
   Rollback: volver a cargar las filas del CSV.
   Después: reiniciar el servicio y recalcular, en orden, enero a abril de los empleados con deducciones. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @T nvarchar(300) = N'dbo.[ArbuTest$Ded_ Ganancias Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
SELECT COUNT(*) AS filas_antes FROM dbo.[ArbuTest$Ded_ Ganancias Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890];
-- 1. La última fila anterior a marzo de cada (empleado, tipo) sin fila posterior se pasa al 1/3.
;WITH ult AS (
  SELECT [No_ Empleado] e,[Cód_ Tipo] t,MAX([Vigencia Desde]) d FROM dbo.[ArbuTest$Ded_ Ganancias Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Vigencia Desde]<'20260301' GROUP BY [No_ Empleado],[Cód_ Tipo])
SELECT u.e,u.t,u.d INTO #repromover FROM ult u
WHERE NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Ded_ Ganancias Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] x WHERE x.[No_ Empleado]=u.e AND x.[Cód_ Tipo]=u.t AND x.[Vigencia Desde]>='20260301');
SELECT COUNT(*) AS se_pasan_al_1_3 FROM #repromover;
-- se borran primero las filas de enero y febrero que NO son la que se pasa (y las que tienen reemplazo posterior)
DELETE x FROM dbo.[ArbuTest$Ded_ Ganancias Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] x
 WHERE x.[Vigencia Desde]<'20260301' AND NOT EXISTS (SELECT 1 FROM #repromover r WHERE r.e=x.[No_ Empleado] AND r.t=x.[Cód_ Tipo] AND r.d=x.[Vigencia Desde]);
SELECT @@ROWCOUNT AS borradas;
UPDATE x SET [Vigencia Desde]='20260301',[$systemModifiedAt]=SYSUTCDATETIME()
  FROM dbo.[ArbuTest$Ded_ Ganancias Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] x JOIN #repromover r ON r.e=x.[No_ Empleado] AND r.t=x.[Cód_ Tipo] AND r.d=x.[Vigencia Desde];
SELECT @@ROWCOUNT AS repromovidas;
SELECT COUNT(*) AS filas_despues, SUM(CASE WHEN [Vigencia Desde]<'20260301' THEN 1 ELSE 0 END) AS anteriores_a_marzo FROM dbo.[ArbuTest$Ded_ Ganancias Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890];
COMMIT;
