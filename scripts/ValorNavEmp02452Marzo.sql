/* VALOR_NAV_EMP_02452: 5.400 USD DESDE EL 1/3/2026 (ERA 6.900 DESDE EL 1/2).
   Meta4 (M4T_VAL_NETOS_GARANTIZADOS y M4T_HIST_PUESTOS): 02452 es CB03 desde el 12/9/2025 (antes CB01, 1/12/2024 al 11/9/2025) y el neto garantizado de CB03 en navegación y puerto es 5.400 (PT/CG, AG, desde 9/2023);
   6.900 es el de CB01. Meta4 liquidó con 5.400 todos los meses (NTO_GARANTIZADO de octubre de 2025 a marzo de 2026). El parámetro individual de BC tenía 6.900 desde febrero, que es el valor de la categoría anterior.
   Sólo se notó en marzo: la DEVENGADOS del 30 y 31/3 (2 días de puerto de la marea) pagaba un 2003 de 135.500 (623.300 de garantizado contra 487.800 ganados) y Meta4 cero (487.800 contra 487.800).
   Se carga una vigencia nueva desde el 1/3 (no se pisa la del 1/2, que ya está en uso). Enero y febrero no cambian.
   Rollback: borrar la fila del 2026-03-01 de VALOR_NAV_EMP_02452. Después: reiniciar el servicio y recalcular la DEVENGADOS de marzo de 02452. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @T nvarchar(300) = N'dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Parámetro]=N'VALOR_NAV_EMP_02452' AND [Vigencia Desde]='20260301')
BEGIN PRINT 'Ya existe la vigencia del 1/3'; ROLLBACK; RETURN; END;
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%' AND c.name NOT IN (N'Vigencia Desde', N'Valor', N'Notas', N'En Uso'));
DECLARE @sql nvarchar(max) = N'INSERT ' + @T + N' ([Vigencia Desde],[Valor],[Notas],[En Uso],' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ''20260301'', 5400, N''Meta4: 02452 es CB03 desde el 12/9/2025 y su neto garantizado es 5.400 (6.900 es el de CB01, la categoría anterior). Ver ValorNavEmp02452Marzo.sql'', 0,' + @cc
  + N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'' FROM ' + @T + N' WHERE [Cód_ Parámetro]=N''VALOR_NAV_EMP_02452'' AND [Vigencia Desde]=''20260201'';';
EXEC (@sql);
SELECT @@ROWCOUNT AS Insertada_esperado_1;
SELECT [Cód_ Parámetro] p, CONVERT(varchar(10),[Vigencia Desde],120) d, CAST([Valor] AS decimal(10,2)) v, Moneda, [Cód_ Variable TC] tc, [No_ Empleado] e FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Parámetro]=N'VALOR_NAV_EMP_02452';
COMMIT;
