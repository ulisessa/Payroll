/* CATEGORÍA SUPERIOR (1603) PARA OFICIALES 175/75 (22/10/2026). El 1603 y PCT_PUESTO sólo estaban habilitados para el convenio 729/15 (Concepto CCT Vigente), por eso 04826 (categoría OF04, puesto OF02) cobraba cero y
   el complemento del grossing-up de su 2033 absorbía la diferencia (BC 1.808.236 contra 1.708.710 de Meta4: 99.526 de más, lo que vale su 1603 de 99.540). Las escalas por categoría ya existían como parámetro
   PCT_ESCALA_CONV (175/75: OF01 1,15; OF02 1; OF03 0,9; OF04 0,85), así que NO hacía falta tocar "% Escala" de Categoría CCT, que cargué por error con EscalaOficialesPorCategoriaMeta4.sql y se devuelve a 100 acá.
   Cambios: (1) 1603 y PCT_PUESTO habilitados para 175/75 desde el 1/4/2026 (Meta4 la paga desde marzo: queda marzo para revisar); no se agrega 768/19 porque le faltan los parámetros PCT_ESCALA_CONV de OF02 y OF04
   y la división daría cero. (2) 1603 (vigencia del 1/4, de hoy): IF(#PCT_PUESTO = 0, 0, ...): un puesto sin escala (03664 tiene FE02, del convenio ESP, sin PCT_ESCALA_CONV) daría PCT_PUESTO 0 y un 1603 igual a menos la base.
   (3) Categoría CCT, "% Escala" de las categorías OF vuelve a 100.
   Rollback: borrar las dos filas de Concepto CCT Vigente de 175/75, sacar el IF del 1603 y volver las escalas a 115/100/90/85/77,83 (no hace falta).
   Después: reiniciar el servicio y recalcular abril de 04826 (cierre, pilotaje y regular) y de 03664. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto CCT Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Concepto] IN (N'1603',N'PCT_PUESTO') AND [Cód_ Convenio]=N'175/75')
BEGIN PRINT 'Ya aplicado'; ROLLBACK; RETURN; END;
DECLARE @T nvarchar(300)=N'dbo.[ArbuTest$Concepto CCT Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]', @cc nvarchar(max), @sql nvarchar(max);
SET @cc = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%' AND c.name NOT IN (N'Vigencia Desde',N'Cód_ Convenio'));
SET @sql = N'INSERT ' + @T + N' ([Vigencia Desde],[Cód_ Convenio],' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ''20260401'',N''175/75'',' + @cc
  + N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'' FROM ' + @T + N' WHERE [Cód_ Concepto] IN (N''1603'',N''PCT_PUESTO'') AND [Cód_ Convenio]=N''729/15'';';
EXEC sp_executesql @sql;
SELECT @@ROWCOUNT AS filas_esperado_2;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Fórmula]=N'IF(#PCT_PUESTO = 0, 0, ' + [Fórmula] + N')', [$systemModifiedAt]=SYSUTCDATETIME()
 WHERE [Código]=N'1603' AND [Vigencia Desde]='20260401' AND [Vigencia Hasta]='17530101' AND [Fórmula] NOT LIKE N'IF(#PCT_PUESTO = 0%';
SELECT @@ROWCOUNT AS c1603_esperado_1;
UPDATE dbo.[ArbuTest$Categoría CCT$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [_ Escala]=100, [$systemModifiedAt]=SYSUTCDATETIME() WHERE [Código] LIKE N'OF%' AND [_ Escala]<>100;
SELECT @@ROWCOUNT AS escalas_devueltas_esperado_8;
SELECT [Cód_ Concepto] c,[Cód_ Convenio] cv,[Cód_ Categoría] ct,CONVERT(varchar(10),[Vigencia Desde],120) d FROM dbo.[ArbuTest$Concepto CCT Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Concepto] IN (N'1603',N'PCT_PUESTO');
COMMIT;
