/* FERIADOS DE GUARDIA OMITIDOS POR META4 EN LAS FINALES DE ABRIL (22/10/2026). 03104, 03791, 04046 y 04802 estuvieron de guardia en puerto (GP) hasta el 10/4 y se dieron de baja entre el 10 y el 14/4.
   BC les paga los feriados del 2 y 3/4 (1023: 2 días) y los suma al devengo de francos (1062); Meta4 calculó el precio (PR_DIA_FERIADO) pero con DIAS_FERIADO = 0 y devengó sólo 50 % de los días de puerto
   (DS_FRANCOS_DEV 5, 5, 4 y 5 contra 7, 7, 6 y 7 de BC). Indicación del usuario: es una omisión de Meta4, se replica como en enero (novedades 9741-9743).
   1. 1023: novedad en cero (importe y cantidad 0), tipo LIQ_FINAL, apaga el concepto.
   2. 1062: novedad por importe 5, 5, 4 y 5 (el importe de un concepto con rol Devengo es la cantidad de días del lote), tipo LIQ_FINAL, para que el devengo coincida con DS_FRANCOS_DEV de Meta4.
   Rollback: borrar las novedades con Observaciones 'Meta4 omitió el feriado de guardia (final de abril 2026)%'.
   Después: reiniciar el servicio y recalcular las LIQ_FINAL de abril de los cuatro. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @N nvarchar(300) = N'dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Observaciones] LIKE N'Meta4 omitió el feriado de guardia (final de abril 2026)%')
BEGIN PRINT 'Ya aplicado'; ROLLBACK; RETURN; END;
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@N) AND c.name <> 'timestamp' AND c.is_identity = 0 AND c.name NOT LIKE '$system%');
DECLARE @sql nvarchar(max), @cs nvarchar(max);
DECLARE @Lista TABLE (emp varchar(20), concepto varchar(10), importe decimal(18,4));
INSERT @Lista VALUES ('03104','1023',0),('03791','1023',0),('04046','1023',0),('04802','1023',0),('03104','1062',5),('03791','1062',5),('04046','1062',4),('04802','1062',5);
DECLARE @emp varchar(20), @con varchar(10), @imp decimal(18,4);
DECLARE cur CURSOR LOCAL FAST_FORWARD FOR SELECT emp, concepto, importe FROM @Lista;
OPEN cur; FETCH NEXT FROM cur INTO @emp, @con, @imp;
WHILE @@FETCH_STATUS = 0
BEGIN
  SET @cs = (SELECT STRING_AGG(CASE c.name
      WHEN N'No_ Empleado' THEN N'h.[No_ Empleado]' WHEN N'Nombre Empleado' THEN N'h.[Nombre Empleado]'
      WHEN N'Cód_ Convenio' THEN N'h.[Cód_ Convenio]' WHEN N'Cód_ Categoría' THEN N'h.[Cód_ Categoría]'
      WHEN N'Cód_ Concepto' THEN N'''' + @con + N'''' WHEN N'Importe' THEN CAST(@imp AS nvarchar(30)) WHEN N'Cantidad' THEN N'0'
      WHEN N'Fecha' THEN N'h.[Fecha Liquidación]' WHEN N'Cód_ Período' THEN N'h.[Cód_ Período]'
      WHEN N'Observaciones' THEN N'N''Meta4 omitió el feriado de guardia (final de abril 2026): ' + CASE WHEN @con = '1023' THEN N'se apaga el 1023.' ELSE N'devengo igual a DS_FRANCOS_DEV de Meta4.' END + N''''
      WHEN N'Estado' THEN N'0' WHEN N'No_ Liquidación' THEN N'''''' WHEN N'Motivo No Aplicada' THEN N'''''' WHEN N'Cód_ Tipo Liq_' THEN N'''LIQ_FINAL''' WHEN N'No_ Proyecto' THEN N''''''
      ELSE N'n.' + QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@N) AND c.name <> 'timestamp' AND c.is_identity = 0 AND c.name NOT LIKE '$system%');
  SET @sql = N'INSERT ' + @N + N' (' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ' + @cs
    + N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'' FROM ' + @N
    + N' n CROSS JOIN dbo.[ArbuTest$Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] h WHERE n.[No_ Movimiento]=9741 AND h.[No_ Empleado]=''' + @emp + N''' AND h.[Cód_ Tipo Liq_]=''LIQ_FINAL'' AND h.[Cód_ Período]=''202604'';';
  EXEC sp_executesql @sql;
  FETCH NEXT FROM cur INTO @emp, @con, @imp;
END
CLOSE cur; DEALLOCATE cur;
SELECT [No_ Movimiento] mv,[No_ Empleado] e,[Cód_ Concepto] c,[Importe] i,[Cantidad] q,[Cód_ Tipo Liq_] tl,[Cód_ Convenio] cv,[Cód_ Categoría] ct,CONVERT(varchar(10),[Fecha],120) f,[Estado] est FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Observaciones] LIKE N'Meta4 omitió el feriado de guardia (final de abril 2026)%' ORDER BY 2,3;
COMMIT;
