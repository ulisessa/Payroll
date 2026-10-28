/* PRECIO DEL FRANCO DE TRES FINALES, COMO LA DECISIÓN MANUAL DE META4 (23/10/2026). El 23/4/2026 Meta4 cargó como incidencia del concepto 1062 (PR_FRANCO, M4T_VAL_INCIDENCIA, cargadas el 30/4) el precio del franco de
   tres finales: 04163 141.780, 04455 165.600 y 04836 141.780 pesos por día = 1,2 x el valor de convenio (OF04 3.060 USD al dólar de 1.390, OF02 3.600 al de 1.380). Es una decisión puntual de esos tres casos, no una regla:
   02450, que tuvo final el mismo día, se pagó al valor de convenio.
   En BC el precio de un franco sale del "Parámetro del valor" del concepto 1063 y, desde la 1.0.0.689, un valor cargado para el EMPLEADO (VALOR_FRANCO_<empleado>) le gana al del par del lote. Se hace:
     1. VALOR_FRANCO (catálogo de Parámetro): Sufijo Empleado = 1, para que admita filas por empleado.
     2. Tres filas de Parámetro Vigente, copia de la de 175/75 OF02 sin convenio ni categoría: VALOR_FRANCO_04163 y VALOR_FRANCO_04836 a 3.060 USD, VALOR_FRANCO_04455 a 3.600 USD, desde el 23/4/2026,
        mensuales y al TC_COMPRADOR como el resto (el divisor de 30 lo pone el concepto).
   Alcanza al 1063 y al 2803 de las tres finales (los dos valúan con el mismo precio); el 2083 se anula solo porque su fórmula resta lo que ya pagó el 1063.
   Rollback: borrar las tres filas y poner Sufijo Empleado = 0.
   Después: reiniciar el servicio y recalcular las finales de 04163, 04455 y 04836. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @P nvarchar(300) = N'dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Parámetro] IN ('VALOR_FRANCO_04163','VALOR_FRANCO_04455','VALOR_FRANCO_04836'))
BEGIN PRINT 'Ya aplicado'; ROLLBACK; RETURN; END;
UPDATE dbo.[ArbuTest$Parámetro$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Sufijo Empleado]=1, [$systemModifiedAt]=SYSUTCDATETIME() WHERE [Código]='VALOR_FRANCO';
SELECT @@ROWCOUNT AS catalogo_esperado_1;
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id=OBJECT_ID(@P) AND c.name<>'timestamp' AND c.is_identity=0 AND c.name NOT LIKE '$system%');
DECLARE @cs nvarchar(max), @sql nvarchar(max), @emp nvarchar(20), @val decimal(18,4);
DECLARE @L TABLE (emp nvarchar(20), val decimal(18,4));
INSERT @L VALUES ('04163',3060),('04455',3600),('04836',3060);
DECLARE cur CURSOR LOCAL FAST_FORWARD FOR SELECT emp,val FROM @L;
OPEN cur; FETCH NEXT FROM cur INTO @emp,@val;
WHILE @@FETCH_STATUS=0
BEGIN
  SET @cs=(SELECT STRING_AGG(CASE c.name
      WHEN N'Cód_ Parámetro' THEN N'N''VALOR_FRANCO_'+@emp+N'''' WHEN N'No_ Empleado' THEN N'N'''+@emp+N'''' WHEN N'Cód_ Convenio' THEN N'''''' WHEN N'Cód_ Categoría' THEN N''''''
      WHEN N'Vigencia Desde' THEN N'''20260423''' WHEN N'Valor' THEN CAST(@val AS nvarchar(30)) WHEN N'Nivel' THEN N'1' WHEN N'En Uso' THEN N'0'
      WHEN N'Descripción' THEN N'N''Precio del franco de la final: decisión manual de Meta4 (incidencia 1062 del 23/4/2026)'''
      WHEN N'Notas' THEN N'N''1,2 x el valor de convenio; decisión puntual de este caso, no una regla.'''
      ELSE QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id=OBJECT_ID(@P) AND c.name<>'timestamp' AND c.is_identity=0 AND c.name NOT LIKE '$system%');
  SET @sql=N'INSERT '+@P+N' ('+@cc+N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT TOP 1 '+@cs
    +N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'' FROM '+@P
    +N' WHERE [Cód_ Parámetro Base]=N''VALOR_FRANCO'' AND [Cód_ Convenio]=N''175/75'' AND [Cód_ Categoría]=N''OF02'' AND [Vigencia Desde]=''20260101'' AND [Sufijo Atributo 1]='''';';
  EXEC sp_executesql @sql;
  FETCH NEXT FROM cur INTO @emp,@val;
END
CLOSE cur; DEALLOCATE cur;
SELECT [Cód_ Parámetro] p,[No_ Empleado] e,CONVERT(varchar(10),[Vigencia Desde],120) d,CAST([Valor] AS decimal(12,2)) v,[Moneda] m,[Cód_ Variable TC] tc,[Nivel] n FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Parámetro] LIKE 'VALOR_FRANCO[_]0%' OR [Cód_ Parámetro]='VALOR_FRANCO_175/75_OF02';
COMMIT;
