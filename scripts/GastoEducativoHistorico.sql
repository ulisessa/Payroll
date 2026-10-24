/* GASTOS EDUCATIVOS DE 90454 (SIRADIG) EN GANANCIAS DE FEBRERO Y MARZO 2026: LA DEDUCCIÓN QUE META4 APLICÓ Y BC NO TENÍA.
   Febrero, 90454: el impuesto de BC quedaba 65.256 arriba de Meta4. La base imponible de Meta4 resta 343.453,50 más que la fórmula con las deducciones que BC ya cargaba
   (marzo: 515.180,25; abril: 686.907,00): exactamente 40 % de la ganancia no imponible acumulada (858.633,75 / 1.287.950,63 / 1.717.267,50 x 0,40).
   Es el concepto 5599 de Meta4 (DED_EDUC, "Deducción gastos educativos"): lee el gasto declarado en M4T_VAL_FASE_ALTA (SIRADIG; 90454 declaró 2.169.267,76 para 2026, vigencia 1/1 al 31/12) y lo topa:
        tope = ganancia no imponible acumulada x 40 %;   deducción = min(declarado, tope)
   Como lo declarado (2.169.267,76) supera el tope anual completo (2.060.721,02), manda el tope acumulado de cada mes. Enero no lo tuvo: Meta4 lo empezó a aplicar en febrero, ya acumulado desde enero.
   Se carga como las otras dos deducciones históricas (GAS_MED_HIST, GAS_DOM_HIST): el IMPORTE ACUMULADO REAL aplicado en el mes exacto, que la fórmula del 5010 reparte con el factor del mes (ver "Deducciones de Ganancias y familiares").
   Cambio:
     A. Parámetro base GAS_EDU_HIST (copia de GAS_MED_HIST).
     B. La fuente GASTOS_IG4_HIST suma también GAS_EDU_HIST (filtro de códigos: GAS_DOM_HIST|GAS_MED_HIST|GAS_EDU_HIST).
     C. Dos filas de Parámetro Vigente para 90454: 2026-02-01 = 343.453,50 y 2026-03-01 = 515.180,25.
   No toca el 5010 ni enero. Abril en adelante necesita su fila cuando se liquide (0,40 x ganancia no imponible acumulada de Meta4, mientras lo declarado no lo alcance).
   Rollback: borrar las dos filas de C, volver el filtro de B a 'GAS_DOM_HIST|GAS_MED_HIST' y borrar el parámetro base de A.
   Después: reiniciar el servicio y recalcular febrero y marzo de 90454. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @B nvarchar(300) = N'dbo.[ArbuTest$Parámetro$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @P nvarchar(300) = N'dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @sys nvarchar(400) = N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000''';
DECLARE @sql nvarchar(max);
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Parámetro$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'GAS_EDU_HIST')
BEGIN PRINT 'Ya existe GAS_EDU_HIST'; ROLLBACK; RETURN; END;

-- A. Parámetro base
DECLARE @bc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@B) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @bs nvarchar(max) = (SELECT STRING_AGG(CASE c.name
    WHEN N'Código' THEN N'N''GAS_EDU_HIST'''
    WHEN N'Descripción' THEN N'N''Gastos educativos histórico aplicado en Meta4'''
    WHEN N'Notas' THEN N'N''Deducción acumulada aplicada en el mes exacto (min(declarado SIRADIG, 40 % de la ganancia no imponible acumulada)); importe real en pesos. La FDS histórica no arrastra meses ni modifica la declaración actual.'''
    ELSE QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@B) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
SET @sql = N'INSERT ' + @B + N' (' + @bc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ' + @bs + @sys
         + N' FROM ' + @B + N' WHERE [Código]=N''GAS_MED_HIST'';';
EXEC (@sql);
SELECT @@ROWCOUNT AS Base_esperado_1;

-- B. Filtro de la fuente
UPDATE dbo.[ArbuTest$Filtro Fuente Datos Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
   SET [Filtro Valor]=N'GAS_DOM_HIST|GAS_MED_HIST|GAS_EDU_HIST', [$systemModifiedAt]=SYSUTCDATETIME()
 WHERE [Nombre Variable]=N'GASTOS_IG4_HIST' AND [No_ Línea]=770 AND [Filtro Valor]=N'GAS_DOM_HIST|GAS_MED_HIST';
SELECT @@ROWCOUNT AS Filtro_esperado_1;

-- C. Valores
DECLARE @pc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@P) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @m TABLE (d date, v decimal(18,2), n nvarchar(100));
INSERT @m VALUES ('20260201', 343453.50, N'febrero'), ('20260301', 515180.25, N'marzo');
DECLARE @d date, @v decimal(18,2), @n nvarchar(100);
DECLARE cur CURSOR FOR SELECT d, v, n FROM @m;
OPEN cur; FETCH cur INTO @d, @v, @n;
WHILE @@FETCH_STATUS = 0
BEGIN
  DECLARE @ps nvarchar(max) = (SELECT STRING_AGG(CASE c.name
      WHEN N'Cód_ Parámetro Base' THEN N'N''GAS_EDU_HIST'''
      WHEN N'Cód_ Parámetro' THEN N'N''GAS_EDU_HIST_90454'''
      WHEN N'Vigencia Desde' THEN N'''' + CONVERT(nvarchar(8), @d, 112) + N''''
      WHEN N'Descripción' THEN N'N''Gastos educativos acumulado aplicado ' + @n + N' 2026'''
      WHEN N'Valor' THEN CAST(@v AS nvarchar(30))
      WHEN N'Notas' THEN N'N''Meta4 ' + @n + N' 2026; DED_EDUC (5599) = 40 % x ganancia no imponible acumulada; declarado SIRADIG 2.169.267,76 (M4T_VAL_FASE_ALTA)'''
      ELSE QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@P) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
  SET @sql = N'INSERT ' + @P + N' (' + @pc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ' + @ps + @sys
           + N' FROM ' + @P + N' WHERE [Cód_ Parámetro Base]=N''GAS_MED_HIST'' AND [Cód_ Parámetro]=N''GAS_MED_HIST_90454'' AND [Vigencia Desde]=''20260201'';';
  EXEC (@sql);
  FETCH cur INTO @d, @v, @n;
END
CLOSE cur; DEALLOCATE cur;
SELECT [Cód_ Parámetro Base] pb,[Cód_ Parámetro] pc,CONVERT(varchar(10),[Vigencia Desde],120) d,CAST(Valor AS decimal(18,2)) v,[No_ Empleado] e FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Parámetro Base] IN (N'GAS_EDU_HIST',N'GAS_MED_HIST') ORDER BY 1,3;
SELECT [No_ Línea] ln,[Filtro Valor] f FROM dbo.[ArbuTest$Filtro Fuente Datos Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Nombre Variable]=N'GASTOS_IG4_HIST' AND [No_ Línea]=770;
COMMIT;
