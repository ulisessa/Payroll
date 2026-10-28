/* ART (7050) CON EL BONO 4874 EN LA BASE, DESDE EL 1/3/2026.
   El 4874 (Bono Fin de Año STIA, 190.000 fijos en marzo, 12 empleados) es remunerativo pero no integra BASE_SS_TRAB (no tiene aportes ni contribuciones de SIPA/obra social, y en eso BC y Meta4 coinciden); Meta4 sí le cobra ART:
   PAT_ART de Meta4 = BC + 14.060 = 190.000 x 7,4 % en los 11 empleados con el bono que ya tenían todo lo demás igual (80002, 80267, 80316, 80344, 80668, 90319, 90414, 90419, 90440, 90444, 90447, 90449).
   El 7050 calcula (BASE_SS_TRAB + BASE_SS_VAC + NO_REMUNERATIVO) x PCT_ART. No se cambia a BASE_LRT (difiere de esa base en 89 liquidaciones de marzo, sobre todo cierres de marea) ni se suma el 4874 a NO_REMUNERATIVO (lo leen también el 7090 y el 7093,
   y entra en el bruto). Se agrega "+ #4874" a la base: una referencia # resuelve desde el 1/3 en adelante (ver SacDevengadoSinBono4874Abierta.sql) y vale 0 si el concepto no corrió.
   Cambio: vigencia nueva del 7050 desde el 1/3/2026, abierta (la del 1/1 se cierra el 28/2).
   Rollback: borrar la fila del 2026-03-01 y reabrir la del 2026-01-01 (Vigencia Hasta 1753-01-01).
   Después: reiniciar el servicio y recalcular marzo de los 12 empleados con el 4874. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @C nvarchar(300) = N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'7050' AND [Vigencia Desde]='20260301')
BEGIN PRINT 'Ya existe'; ROLLBACK; RETURN; END;
DECLARE @sys nvarchar(400) = N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000''';
DECLARE @sysc nvarchar(200) = N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]';
DECLARE @cc nvarchar(max), @sql nvarchar(max);
SET @cc = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@C) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%' AND c.name NOT IN (N'Vigencia Desde', N'Vigencia Hasta', N'Fórmula'));
SET @sql = N'INSERT ' + @C + N' ([Vigencia Desde],[Vigencia Hasta],[Fórmula],' + @cc + @sysc + N') SELECT ''20260301'',''17530101'',
   REPLACE([Fórmula], N''+ NO_REMUNERATIVO)'', N''+ NO_REMUNERATIVO + #4874)''),' + @cc + @sys
  + N' FROM ' + @C + N' WHERE [Código]=N''7050'' AND [Vigencia Desde]=''20260101'' AND [Vigencia Hasta]=''17530101'';';
EXEC sp_executesql @sql;
SELECT @@ROWCOUNT AS Alta_esperado_1;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Vigencia Hasta]='20260228', [$systemModifiedAt]=SYSUTCDATETIME() WHERE [Código]=N'7050' AND [Vigencia Desde]='20260101' AND [Vigencia Hasta]='17530101';
SELECT @@ROWCOUNT AS Cerrada_esperado_1;
SELECT CONVERT(varchar(10),[Vigencia Desde],120) d,CONVERT(varchar(10),[Vigencia Hasta],120) h,[Fórmula] FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'7050' ORDER BY 1;
COMMIT;
