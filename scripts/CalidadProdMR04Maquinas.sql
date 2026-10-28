/* CALIDAD DE PRODUCCIÓN (5 % DE A28/61 DESDE MARZO): EXCEPCIÓN PARA EL PUESTO MR04 (MARINERO DE MÁQUINAS, MQ05 EN META4).
   04526 y 03772 (puesto MR04 en BC, MQ05 en Meta4) cobraban en BC un 2498 de 3.799.477,96 y en Meta4 3.999.450,49 (TOTAL_VAL_NTO): BC / Meta4 = 0,95 exacto; -199.973 de bruto cada uno. Los otros 26 marineros
   de A28/61 (cubierta, CB07 en Meta4) coinciden con el 5 % aplicado; las excepciones de Máquinas que ya tenía BC eran sólo las de oficiales (OF02/OF04...) y Meta4 también exceptúa a los de Máquinas de marinería.
   Se mapea MQ05 -> MR04 en 18 de los 20 marineros de BC con ese puesto (los otros dos son CB05 en Meta4); en A28/61 el puesto MR04 son exactamente 04526 y 03772.
   Cambio: APLICA_CALIDAD_PROD_729/15_MR04 = 0 desde el 1/3/2026 (par convenio + puesto, como las de OF02/OF04), copia de APLICA_CALIDAD_PROD_175/75_OF02.
   Atención: afecta a cualquier MR04 de un proyecto con DTO_CALIDAD_PROD; hoy sólo A28/61 lo tiene y sólo estos dos son MR04. Si a futuro hay un MR04 que en Meta4 no sea de Máquinas hay que revisarlo.
   Rollback: borrar la fila del parámetro APLICA_CALIDAD_PROD_729/15_MR04. Después: reiniciar el servicio y recalcular el CIERRE_MAREA de marzo de 04526 y 03772. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @T nvarchar(300) = N'dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Parámetro]=N'APLICA_CALIDAD_PROD_729/15_MR04')
BEGIN PRINT 'Ya existe la excepción'; ROLLBACK; RETURN; END;
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%' AND c.name NOT IN (N'Cód_ Parámetro', N'Cód_ Convenio', N'Cód_ Categoría', N'En Uso', N'Notas'));
DECLARE @sql nvarchar(max) = N'INSERT ' + @T + N' ([Cód_ Parámetro],[Cód_ Convenio],[Cód_ Categoría],[En Uso],[Notas],' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT N''APLICA_CALIDAD_PROD_729/15_MR04'', N''729/15'', N''MR04'', 0, N''Máquinas (MQ05 en Meta4): sin el descuento de calidad. Ver CalidadProdMR04Maquinas.sql'',' + @cc
  + N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'' FROM ' + @T + N' WHERE [Cód_ Parámetro]=N''APLICA_CALIDAD_PROD_175/75_OF02'';';
EXEC (@sql);
SELECT @@ROWCOUNT AS Insertada_esperado_1;
SELECT [Cód_ Parámetro] p, CONVERT(varchar(10),[Vigencia Desde],120) d, CAST([Valor] AS decimal(10,2)) v, [Cód_ Convenio] cv, [Cód_ Categoría] ct, [Nivel] n FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Parámetro] IN (N'APLICA_CALIDAD_PROD_729/15_MR04', N'APLICA_CALIDAD_PROD_175/75_OF02');
COMMIT;
