/* PILOTAJE DE ABRIL (22/10/2026), primera comparación contra la corrida de Meta4 (TP_IMPUT 12): tres diferencias de fórmula.
   1. 1083 (sueldo de puerto): sumaba DIAS_GP_PERIODO, que es del período y no del pilotaje (03664: 5 días de GP => 360.000 contra 60.000 de Meta4, 1 día). En PILOTAJE sólo cuenta DIAS_PUERTO.
      Vigencia nueva del 1/4/2026 (la del 1/1/2026 se cierra el 31/3).
   2. 1053 (antigüedad): sumaba DIAS_PROYECTO, DIAS_GP_PERIODO, francos, órdenes y dique del período. Meta4 paga la antigüedad de 5 + 1 días (pilotaje + puerto). En PILOTAJE (fuera de 130/75 y 372/04, que
      tienen su propia rama) = PRECIO_NAV / 30 * % antigüedad * (DIAS_PUERTO + #DIAS_PILOT_PAGO) * COEF_PESQUERIA. Se edita en el lugar la vigencia del 1/4/2026, que es nueva de este mes.
   3. 1603 (categoría superior): Meta4 incluye el sueldo de pilotaje en la base. Se suma #1043 a los dos paréntesis (en las demás liquidaciones el 1043 vale 0). Vigencia nueva del 1/4/2026.
   Rollback: borrar las vigencias del 1/4/2026 de 1083 y 1603 y reabrir las anteriores (Vigencia Hasta = 1753-01-01); 1053: sacar el IF(TIPO_LIQ = 'PILOTAJE' ...) exterior.
   Después: reiniciar el servicio y recalcular el PILOTAJE de abril. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @T nvarchar(300) = N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] IN ('1083','1603') AND [Vigencia Desde]='20260401')
BEGIN PRINT 'Ya aplicado'; ROLLBACK; RETURN; END;
DECLARE @cc nvarchar(max), @sql nvarchar(max), @cod nvarchar(20), @old nvarchar(200), @new nvarchar(200);
SET @cc = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%' AND c.name NOT IN (N'Vigencia Desde', N'Fórmula'));
DECLARE cur CURSOR LOCAL FAST_FORWARD FOR SELECT * FROM (VALUES
 (N'1083', N'DIAS_PUERTO + DIAS_GP_PERIODO', N'DIAS_PUERTO + IF(TIPO_LIQ = ''PILOTAJE'', 0, DIAS_GP_PERIODO)'),
 (N'1603', N'#1013 + #1083 +', N'#1013 + #1043 + #1083 +')) v(c,o,n);
OPEN cur; FETCH NEXT FROM cur INTO @cod, @old, @new;
WHILE @@FETCH_STATUS = 0
BEGIN
  SET @sql = N'INSERT ' + @T + N' ([Vigencia Desde],[Fórmula],' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ''20260401'',REPLACE([Fórmula],@o,@n),' + @cc
    + N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'' FROM ' + @T + N' WHERE [Código]=@c AND [Vigencia Hasta]=''17530101'';';
  EXEC sp_executesql @sql, N'@o nvarchar(200),@n nvarchar(200),@c nvarchar(20)', @o=@old, @n=@new, @c=@cod;
  UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Vigencia Hasta]='20260331', [$systemModifiedAt]=SYSUTCDATETIME() WHERE [Código]=@cod AND [Vigencia Hasta]='17530101' AND [Vigencia Desde]<'20260401';
  FETCH NEXT FROM cur INTO @cod, @old, @new;
END
CLOSE cur; DEALLOCATE cur;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Fórmula] =
  N'IF(TIPO_LIQ = ''PILOTAJE'' AND CONVENIO <> ''130/75'' AND CONVENIO <> ''372/04'',' + CHAR(13)+CHAR(10)
  + N'    round(PRECIO_NAV / 30 * IFZERO(#PCT_ANTIG_OFICIALES, #PCT_ANTIG_SOMU) / 100 * (DIAS_PUERTO + #DIAS_PILOT_PAGO) * #COEF_PESQUERIA, PRECISION_REDONDEO),' + CHAR(13)+CHAR(10)
  + [Fórmula] + N')', [$systemModifiedAt]=SYSUTCDATETIME()
 WHERE [Código]=N'1053' AND [Vigencia Desde]='20260401' AND [Vigencia Hasta]='17530101' AND [Fórmula] NOT LIKE N'IF(TIPO_LIQ = ''PILOTAJE''%';
SELECT @@ROWCOUNT AS c1053_esperado_1;
SELECT [Código], CONVERT(varchar(10),[Vigencia Desde],120) d, CONVERT(varchar(10),[Vigencia Hasta],120) h, [Orden Cálculo] o, CASE WHEN [Fórmula] LIKE N'%#1043%' OR [Fórmula] LIKE N'%PILOTAJE%' THEN 'ok' ELSE 'SIN CAMBIO' END cambio
 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] IN ('1053','1083','1603') AND [Vigencia Hasta] IN ('17530101','20260331') AND [Vigencia Desde]>='20260101' ORDER BY 1,2;
COMMIT;
