/* GANANCIAS: SERVICIO DOMÉSTICO DE 90184 EN MARZO DE 2026 (GAS_DOM_HIST).
   Meta4 (M4_ACUMULADO_RL.DED_SER_DOM_ST) deduce a 90184 el servicio doméstico ACUMULADO: 281.741,78 en febrero y 563.483,56 en marzo (281.741,78 por mes). BC sólo tenía cargado febrero
   (GAS_DOM_HIST_90184, 2026-02-01), así que en marzo la base de impuesto quedaba 563.483,56 por encima de la de Meta4 y el descuento 174.680 por encima (enero y febrero coinciden).
   Mismo patrón que GAS_MED_HIST / GAS_EDU_HIST de 90454: el IMPORTE ACUMULADO REAL aplicado en el mes exacto, sin arrastrarse al mes siguiente (la fuente GASTOS_IG4_HIST filtra Vigencia Desde = {PERIODO_DESDE}).
   Cambio: una fila de Parámetro Vigente, copia de la de febrero con Vigencia Desde 2026-03-01 y Valor 563483.56.
   Rollback: borrar la fila GAS_DOM_HIST_90184 del 2026-03-01.
   Después: reiniciar el servicio y recalcular marzo de 90184 (REGULAR). */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Parámetro]=N'GAS_DOM_HIST_90184' AND [Vigencia Desde]='20260301')
BEGIN PRINT 'Ya existe'; ROLLBACK; RETURN; END;
DECLARE @P nvarchar(300) = N'dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @sys nvarchar(400) = N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000''';
DECLARE @sysc nvarchar(200) = N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]';
DECLARE @cc nvarchar(max), @sql nvarchar(max);
SET @cc = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@P) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%' AND c.name NOT IN (N'Vigencia Desde', N'Valor'));
SET @sql = N'INSERT ' + @P + N' ([Vigencia Desde],[Valor],' + @cc + @sysc + N') SELECT ''20260301'',563483.56,' + @cc + @sys
  + N' FROM ' + @P + N' WHERE [Cód_ Parámetro]=N''GAS_DOM_HIST_90184'' AND [Vigencia Desde]=''20260201'';';
EXEC sp_executesql @sql;
SELECT @@ROWCOUNT AS Alta_esperado_1;
SELECT [Cód_ Parámetro], CONVERT(varchar(10),[Vigencia Desde],120) d, [Valor] FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Parámetro]=N'GAS_DOM_HIST_90184' ORDER BY 2;
COMMIT;
