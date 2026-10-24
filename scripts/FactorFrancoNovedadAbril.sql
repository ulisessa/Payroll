/* VALOR DEL FRANCO DE ABRIL COMO EN META4, POR NOVEDAD (22/10/2026). Pedido del usuario. El +20 % de VALOR_FRANCO de los oficiales (vigencia 1/4/2026) lo pagó la corrida mensual de Meta4 del 25/4 con el valor VIEJO
   (116.025 / 122.850 / 136.500 / 156.975 por día = 2.550 / 2.700 / 3.000 / 3.450 USD x 1.365 / 30) y las finales del 23/4 y de mayo con el nuevo; BC no puede reproducir ese orden con fechas. 18 empleados, todos oficiales,
   dan en BC exactamente 1,2 veces lo de Meta4 (00406 00619 00794 01073 01477 02452 03039 03196 04313 04320 04582 04649 04710 04724 04791 04826 04868 04924). 02452 y 01477 son sólo dos de los 18.
   Las novedades NO pueden llevar plata en un concepto de consumo de francos (el importe de la novedad entra como DÍAS a consumir del saldo), así que se usa el factor que el consumo ya tiene: "Factor Importe Consumo" del 1063 opera sobre
   los pesos después del FIFO, sin tocar el saldo ni los lotes. Se agrega:
     1. Concepto informativo FACTOR_FRANCO (copia del 2041) y Fuente de Datos FACTOR_FRANCO_NOV (copia de IND_GUARDIA_2041: Cantidad de la novedad del empleado y el período, concepto FACTOR_FRANCO).
     2. 1063: vigencia nueva del 1/4/2026 con Factor Importe Consumo = IFZERO(FACTOR_FRANCO_NOV, 1) (la del 1/1 se cierra el 31/3). Sin novedad el factor es 1.
     3. 18 novedades FACTOR_FRANCO, Cantidad 1/1,2 (0,8333...), tipo REGULAR (04649: LIQ_FINAL), fecha 30/4, Pendientes.
   Rollback: anular las 18 novedades (Estado 2) y el factor vuelve a 1; para sacar todo, borrar la vigencia del 1/4 de 1063 (y reabrir la anterior), la fuente y sus 3 filtros y el concepto FACTOR_FRANCO.
   Después: reiniciar el servicio y recalcular la REGULAR de abril de los 17 y la final de 04649. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]='FACTOR_FRANCO') BEGIN PRINT 'Ya aplicado'; ROLLBACK; RETURN; END;
DECLARE @C nvarchar(300)=N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]', @cc nvarchar(max), @sql nvarchar(max);
DECLARE @sys nvarchar(400) = N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000''';
DECLARE @coma nvarchar(5) = N',';
/* 1. concepto FACTOR_FRANCO, copia del 2041 */
SET @cc = (SELECT STRING_AGG(QUOTENAME(c.name), @coma) FROM sys.columns c WHERE c.object_id=OBJECT_ID(@C) AND c.name<>'timestamp' AND c.name NOT LIKE '$system%' AND c.name NOT IN (N'Código',N'Vigencia Desde',N'Descripción',N'Nombre Impresión',N'Vigencia Hasta'));
SET @sql=N'INSERT '+@C+N' ([Código],[Vigencia Desde],[Vigencia Hasta],[Descripción],[Nombre Impresión],'+@cc+N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT N''FACTOR_FRANCO'',''20260401'',''17530101'',N''Factor del importe de francos (Meta4)'',N''Factor del importe de francos'','+@cc+@sys+N' FROM '+@C+N' WHERE [Código]=N''2041'' AND [Vigencia Hasta]=''17530101'';';
EXEC (@sql);
SELECT @@ROWCOUNT AS concepto_esperado_1;
/* 2. fuente de datos y sus filtros, copia de IND_GUARDIA_2041 */
DECLARE @F nvarchar(300)=N'dbo.[ArbuTest$Fuente Datos Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
SET @cc = (SELECT STRING_AGG(QUOTENAME(c.name), @coma) FROM sys.columns c WHERE c.object_id=OBJECT_ID(@F) AND c.name<>'timestamp' AND c.name NOT LIKE '$system%' AND c.name NOT IN (N'Nombre Variable',N'Descripción'));
SET @sql=N'INSERT '+@F+N' ([Nombre Variable],[Descripción],'+@cc+N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT N''FACTOR_FRANCO_NOV'',N''Factor del importe de francos de Meta4 (novedad FACTOR_FRANCO del empleado y el período)'','+@cc+@sys+N' FROM '+@F+N' WHERE [Nombre Variable]=N''IND_GUARDIA_2041'';';
EXEC (@sql);
SELECT @@ROWCOUNT AS fuente_esperado_1;
DECLARE @FL nvarchar(300)=N'dbo.[ArbuTest$Filtro Fuente Datos Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
SET @cc = (SELECT STRING_AGG(QUOTENAME(c.name), @coma) FROM sys.columns c WHERE c.object_id=OBJECT_ID(@FL) AND c.is_identity=0 AND c.name<>'timestamp' AND c.name NOT LIKE '$system%' AND c.name NOT IN (N'Nombre Variable',N'Filtro Valor'));
SET @sql=N'INSERT '+@FL+N' ([Nombre Variable],[Filtro Valor],'+@cc+N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT N''FACTOR_FRANCO_NOV'',CASE WHEN [No_ Campo]=10 THEN N''FACTOR_FRANCO'' ELSE [Filtro Valor] END,'+@cc+@sys+N' FROM '+@FL+N' WHERE [Nombre Variable]=N''IND_GUARDIA_2041'';';
EXEC (@sql);
SELECT @@ROWCOUNT AS filtros_esperado_3;
/* 3. 1063: vigencia nueva con el factor */
SET @cc = (SELECT STRING_AGG(QUOTENAME(c.name), @coma) FROM sys.columns c WHERE c.object_id=OBJECT_ID(@C) AND c.name<>'timestamp' AND c.name NOT LIKE '$system%' AND c.name NOT IN (N'Vigencia Desde',N'Factor Importe Consumo'));
SET @sql=N'INSERT '+@C+N' ([Vigencia Desde],[Factor Importe Consumo],'+@cc+N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ''20260401'',N''IFZERO(FACTOR_FRANCO_NOV, 1)'','+@cc+@sys+N' FROM '+@C+N' WHERE [Código]=N''1063'' AND [Vigencia Hasta]=''17530101'';';
EXEC (@sql);
SELECT @@ROWCOUNT AS c1063_esperado_1;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Vigencia Hasta]='20260331',[$systemModifiedAt]=SYSUTCDATETIME() WHERE [Código]=N'1063' AND [Vigencia Hasta]='17530101' AND [Vigencia Desde]<'20260401';
/* 4. novedades */
DECLARE @N nvarchar(300)=N'dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @tpl int=(SELECT TOP 1 [No_ Movimiento] FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Concepto]='2041' ORDER BY 1 DESC);
DECLARE @nv TABLE (emp nvarchar(20), tl nvarchar(20), nombre nvarchar(100), conv nvarchar(20), cat nvarchar(20));
INSERT @nv SELECT x.emp, x.tl, MAX(h.[Nombre Empleado]), MAX(h.[Cód_ Convenio]), MAX(h.[Cód_ Categoría])
 FROM (VALUES ('00406','REGULAR'),('00619','REGULAR'),('00794','REGULAR'),('01073','REGULAR'),('01477','REGULAR'),('02452','REGULAR'),('03039','REGULAR'),('03196','REGULAR'),('04313','REGULAR'),('04320','REGULAR'),
              ('04582','REGULAR'),('04649','LIQ_FINAL'),('04710','REGULAR'),('04724','REGULAR'),('04791','REGULAR'),('04826','REGULAR'),('04868','REGULAR'),('04924','REGULAR')) x(emp,tl)
 JOIN dbo.[ArbuTest$Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] h ON h.[No_ Empleado]=x.emp AND h.[Cód_ Período]='202604' AND h.[Cód_ Tipo Liq_]=x.tl GROUP BY x.emp,x.tl;
SELECT COUNT(*) AS novedades_esperado_18 FROM @nv;
SET @cc = (SELECT STRING_AGG(QUOTENAME(c.name), @coma) FROM sys.columns c WHERE c.object_id=OBJECT_ID(@N) AND c.name<>'timestamp' AND c.is_identity=0 AND c.name NOT LIKE '$system%');
DECLARE @emp nvarchar(20),@tl nvarchar(20),@nombre nvarchar(100),@conv nvarchar(20),@cat nvarchar(20),@cs nvarchar(max);
DECLARE cur CURSOR FOR SELECT emp,tl,nombre,conv,cat FROM @nv;
OPEN cur; FETCH cur INTO @emp,@tl,@nombre,@conv,@cat;
WHILE @@FETCH_STATUS=0
BEGIN
  SET @cs=(SELECT STRING_AGG(CASE c.name WHEN N'No_ Empleado' THEN N'@emp' WHEN N'Nombre Empleado' THEN N'@nombre' WHEN N'Cód_ Convenio' THEN N'@conv' WHEN N'Cód_ Categoría' THEN N'@cat'
      WHEN N'Cód_ Período' THEN N'''202604''' WHEN N'Fecha' THEN N'''20260430''' WHEN N'Cód_ Concepto' THEN N'N''FACTOR_FRANCO''' WHEN N'Cantidad' THEN N'CAST(1 AS decimal(38,20))/CAST(1.2 AS decimal(38,20))'
      WHEN N'Importe' THEN N'0' WHEN N'Valor Unitario' THEN N'0' WHEN N'Unidad Cantidad' THEN N'''''' WHEN N'Observaciones' THEN N'N''Valor del franco de abril como Meta4: la corrida mensual del 25/4 pagó el valor anterior al +20 %'''
      WHEN N'Estado' THEN N'0' WHEN N'No_ Liquidación' THEN N'''''' WHEN N'Motivo No Aplicada' THEN N'''''' WHEN N'Cód_ Tipo Liq_' THEN N'@tl' WHEN N'No_ Proyecto' THEN N'''''' WHEN N'Recurrente' THEN N'0' WHEN N'Períodos Restantes' THEN N'0' WHEN N'Novedad Origen' THEN N'0'
      ELSE QUOTENAME(c.name) END, @coma) FROM sys.columns c WHERE c.object_id=OBJECT_ID(@N) AND c.name<>'timestamp' AND c.is_identity=0 AND c.name NOT LIKE '$system%');
  SET @sql=N'INSERT '+@N+N' ('+@cc+N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT '+@cs+@sys+N' FROM '+@N+N' WHERE [No_ Movimiento]='+CAST(@tpl AS nvarchar(20))+N';';
  EXEC sp_executesql @sql, N'@emp nvarchar(20),@tl nvarchar(20),@nombre nvarchar(100),@conv nvarchar(20),@cat nvarchar(20)', @emp,@tl,@nombre,@conv,@cat;
  FETCH cur INTO @emp,@tl,@nombre,@conv,@cat;
END
CLOSE cur; DEALLOCATE cur;
SELECT [Cód_ Tipo Liq_] tl,COUNT(*) n,CAST(MIN([Cantidad]) AS decimal(10,6)) q FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Concepto]='FACTOR_FRANCO' GROUP BY [Cód_ Tipo Liq_];
SELECT [Código],CONVERT(varchar(10),[Vigencia Desde],120) d,CONVERT(varchar(10),[Vigencia Hasta],120) h,[Factor Importe Consumo] f FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] IN ('1063','FACTOR_FRANCO') ORDER BY 1,2;
COMMIT;
