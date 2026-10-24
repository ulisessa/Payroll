/* CUOTA MÉDICO ASISTENCIAL ACUMULADA DE 90454 AL CIERRE DE MARZO 2026 (IG_CMASIS_REMUN de Meta4 = 525.003,17).
   Febrero ya tenía su foto (GAS_MED_HIST_90454, vigencia 2026-02-01, 259.304,58); la fuente GASTOS_IG4_HIST lee la fila de Vigencia Desde = {PERIODO_DESDE}, así que marzo
   necesita la suya: sin ella la deducción de marzo es cero y el impuesto de 90454 queda alto (Meta4 la acumula mes a mes: 259.304,58 / 525.003,17 / 786.398,85 en abril).
   Es el valor ACUMULADO real a esa fecha, como el de febrero, no el del mes.
   Cambio: una fila en Parámetro Vigente copiada de la de febrero, con Vigencia Desde 2026-03-01 y el valor de marzo.
   Rollback: DELETE de esa fila (Cód. Parámetro GAS_MED_HIST_90454, Vigencia Desde 2026-03-01).
   Después: reiniciar el servicio y recalcular marzo de 90454 (la Regular y la final si la hubiera). */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @P nvarchar(300) = N'dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @sql nvarchar(max);
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Parámetro Base]=N'GAS_MED_HIST' AND [Cód_ Parámetro]=N'GAS_MED_HIST_90454' AND [Vigencia Desde]='20260301')
BEGIN PRINT 'Ya existe la fila de marzo'; ROLLBACK; RETURN; END;
DECLARE @pc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@P) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @ps nvarchar(max) = (SELECT STRING_AGG(CASE c.name
    WHEN N'Vigencia Desde' THEN N'''20260301'''
    WHEN N'Descripción' THEN N'N''Cuota médico asistencial acumulado original marzo 2026'''
    WHEN N'Valor' THEN N'525003.17'
    WHEN N'Notas' THEN N'N''Meta4 marzo 2026; IG_CMASIS_REMUN; tipo gasto BC 1; acumulado al cierre de marzo'''
    ELSE QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@P) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @sys nvarchar(400) = N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000''';
SET @sql = N'INSERT ' + @P + N' (' + @pc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ' + @ps + @sys
         + N' FROM ' + @P + N' WHERE [Cód_ Parámetro Base]=N''GAS_MED_HIST'' AND [Cód_ Parámetro]=N''GAS_MED_HIST_90454'' AND [Vigencia Desde]=''20260201'';';
EXEC (@sql);
SELECT @@ROWCOUNT AS Filas_esperado_1;
SELECT [Cód_ Parámetro] pc,CONVERT(varchar(10),[Vigencia Desde],120) d,CAST(Valor AS decimal(18,2)) v,[No_ Empleado] e FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Parámetro Base]=N'GAS_MED_HIST' ORDER BY 2;
COMMIT;
