/* VALOR_NAV_EMP_02452: 6.900 USD DESDE EL 1/4/2026 (22/10/2026). La planilla "A28 62 CLC producción.xlsx" lista a 02452 como Primer Oficial de Cubierta con 6.900 USD de asegurado (celda G14) y Meta4 pagó el 2003 del cierre de abril
   según esa planilla: "a pagar" 8.235.794 (7.848.750 de asegurado a 25 días + 387.044 de producción) - 487.800 de marzo = 7.747.994 ("dif total"), menos 5.654.700 de haberes = 2.093.294 (su "a cuenta" y el 2003 de Meta4), aunque el
   NTO_GARANTIZADO de su corrida diga 5.400 (la del cierre de marzo, A28/61, no lo lista, y el valor de marzo, 5.400, se mantiene). BC daba 387.044 (con 5.400: 6.142.500 + 387.044 - 487.800 menos haberes).
   Vigencia nueva desde el 1/4 (no se pisa la del 1/3). Rollback: borrar la fila del 2026-04-01 de VALOR_NAV_EMP_02452. Después: reiniciar el servicio y recalcular el cierre, la regular y el pilotaje de abril de 02452. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @T nvarchar(300) = N'dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Parámetro]=N'VALOR_NAV_EMP_02452' AND [Vigencia Desde]='20260401')
BEGIN PRINT 'Ya existe la vigencia del 1/4'; ROLLBACK; RETURN; END;
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%' AND c.name NOT IN (N'Vigencia Desde', N'Valor', N'Notas', N'En Uso'));
DECLARE @sql nvarchar(max) = N'INSERT ' + @T + N' ([Vigencia Desde],[Valor],[Notas],[En Uso],' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ''20260401'', 6900, N''CLC A28/62: 02452 Primer Oficial de Cubierta, 6.900 USD de asegurado en abril'', 0,' + @cc
  + N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'' FROM ' + @T + N' WHERE [Cód_ Parámetro]=N''VALOR_NAV_EMP_02452'' AND [Vigencia Desde]=''20260301'';';
EXEC (@sql);
SELECT @@ROWCOUNT AS Insertada_esperado_1;
SELECT [Cód_ Parámetro] p, CONVERT(varchar(10),[Vigencia Desde],120) d, CAST([Valor] AS decimal(10,2)) v FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Parámetro]=N'VALOR_NAV_EMP_02452';
COMMIT;
