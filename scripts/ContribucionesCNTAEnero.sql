/* MODELO DE CONTRIBUCIONES DE META4 (5800 / 5802 / 5803 / 5804 / 5811 / 5821 / 5831 Y LOS CNT_*) ADELANTADO A ENERO DE 2026.
   Enero seguía con la rama vieja de 7000 / 7010 / 7060 / 7070 (BASE_SS - DED_CONT_PATR completa por mes): 11 empleados con mes parcial quedaban 500 a 1.300 pesos abajo de Meta4 en TOT_CONT_SUSS
   (04382, 04785, 04855, 03073, 04486, 04926, 04900, 04775, 04889, 04925, 04901). Meta4 reduce la detracción por los días trabajados (DIAS_REDUC_IMPO = 5802): round(DED / 30 x días), con un piso en la
   base mínima de obra social. El modelo ya estaba implementado desde el 1/2 (otra sesión, 16/10/2026) y cierra febrero completo; este script lo lleva a enero sin tocar su fórmula.
   Cambio, todo con vigencias nuevas (nada se pisa):
     A. Los 13 conceptos nuevos (CNT_APLICA, 3610, 5800, 5802, 5803, 5804, 5831, CNT_SALDO, CNT_RED_SUELDO, CNT_BASE_PRUEBA, 5811, CNT_FRAC_SAC, 5821): copia de la 2026-02-01 con vigencia 2026-01-01..2026-01-31.
     B. 7000, 7010, 7060, 7070: copia de la 2026-02-01 con vigencia 2026-01-02..2026-01-31; la 2026-01-01 se cierra el 1/1.
     C. Parámetros CNT_* (CNT_COEF_JORNADA, CNT_EMBARCADO, CNT_MENSUAL, CNT_MIN_BASE): copia con Vigencia Desde 2026-01-01.
   SUPUESTO sin confirmar: CNT_MIN_BASE (base mínima de obra social, concepto 605 "toma el valor de sociedad") se copia de febrero (120.997); el de enero puede ser otro. Sólo importa si
   remuneración - detracción queda debajo del mínimo. 7053 (ART fijo) y 7030 / 7050 / 7055 no se tocan: enero conserva su tarifa histórica.
   Rollback: borrar las vigencias nuevas de A y B (y sus filas de historial), reabrir las 2026-01-01 de B (Hasta 2026-01-31) y borrar los parámetros de C con Vigencia Desde 2026-01-01.
   Después: reiniciar el servicio y recalcular enero completo (los 330 empleados: la rama nueva decide por CNT_APLICA). */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @T nvarchar(300) = N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @P nvarchar(300) = N'dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @sys nvarchar(400) = N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000''';
DECLARE @sql nvarchar(max);
CREATE TABLE #n (cod nvarchar(20) COLLATE DATABASE_DEFAULT, desde date);
INSERT #n VALUES (N'CNT_APLICA','20260101'),(N'3610','20260101'),(N'5800','20260101'),(N'5802','20260101'),(N'5803','20260101'),(N'5804','20260101'),(N'5831','20260101'),(N'CNT_SALDO','20260101'),
 (N'CNT_RED_SUELDO','20260101'),(N'CNT_BASE_PRUEBA','20260101'),(N'5811','20260101'),(N'CNT_FRAC_SAC','20260101'),(N'5821','20260101'),
 (N'7000','20260102'),(N'7010','20260102'),(N'7060','20260102'),(N'7070','20260102');
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c JOIN #n n ON n.cod=c.[Código] WHERE c.[Vigencia Desde] < '20260201' AND c.[Vigencia Desde] >= n.desde AND c.[Código] NOT IN (N'7000',N'7010',N'7060',N'7070'))
 OR EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c WHERE c.[Código] IN (N'7000',N'7010',N'7060',N'7070') AND c.[Vigencia Desde]='20260102')
BEGIN PRINT 'Ya hay vigencias de enero de estos conceptos'; ROLLBACK; RETURN; END;
IF (SELECT COUNT(*) FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c JOIN #n n ON n.cod=c.[Código] WHERE c.[Vigencia Desde]='20260201' AND c.[Vigencia Hasta]='17530101') <> 17
BEGIN PRINT 'Faltan vigencias abiertas 2026-02-01 en el modelo'; ROLLBACK; RETURN; END;

DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @cod nvarchar(20), @desde date, @cs nvarchar(max);
DECLARE cur CURSOR FOR SELECT cod, desde FROM #n;
OPEN cur; FETCH cur INTO @cod, @desde;
WHILE @@FETCH_STATUS = 0
BEGIN
  SET @cs = (SELECT STRING_AGG(CASE c.name WHEN N'Vigencia Desde' THEN N'@desde' WHEN N'Vigencia Hasta' THEN N'''20260131''' ELSE QUOTENAME(c.name) END, ',')
             FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
  SET @sql = N'INSERT ' + @T + N' (' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ' + @cs + @sys
           + N' FROM ' + @T + N' WHERE [Código]=@cod AND [Vigencia Desde]=''20260201'' AND [Vigencia Hasta]=''17530101'';';
  EXEC sp_executesql @sql, N'@cod nvarchar(20), @desde date', @cod=@cod, @desde=@desde;
  IF @cod IN (N'7000',N'7010',N'7060',N'7070')
    UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Vigencia Hasta]='20260101', [$systemModifiedAt]=SYSUTCDATETIME() WHERE [Código]=@cod AND [Vigencia Desde]='20260101';
  FETCH cur INTO @cod, @desde;
END
CLOSE cur; DEALLOCATE cur;
SELECT c.[Código],CONVERT(varchar(10),c.[Vigencia Desde],120) desde,CONVERT(varchar(10),c.[Vigencia Hasta],120) hasta FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c JOIN #n n ON n.cod=c.[Código] WHERE c.[Vigencia Desde]<'20260201' AND c.[Vigencia Desde]>='20260101' ORDER BY 1,2;

-- C. Parámetros CNT_*
DECLARE @pc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@P) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @ps nvarchar(max) = (SELECT STRING_AGG(CASE c.name WHEN N'Vigencia Desde' THEN N'''20260101''' ELSE QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@P) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
SET @sql = N'INSERT ' + @P + N' (' + @pc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ' + @ps + @sys + N' FROM ' + @P
         + N' p WHERE p.[Cód_ Parámetro Base] LIKE N''CNT[_]%'' AND p.[Vigencia Desde]=''20260201'' AND NOT EXISTS (SELECT 1 FROM ' + @P + N' q WHERE q.[Cód_ Parámetro Base]=p.[Cód_ Parámetro Base] AND q.[Cód_ Parámetro]=p.[Cód_ Parámetro] AND q.[Vigencia Desde]=''20260101'');';
EXEC (@sql);
SELECT @@ROWCOUNT AS Parametros_esperado_7;
SELECT [Cód_ Parámetro Base] pb,[Cód_ Convenio] cv,CONVERT(varchar(10),[Vigencia Desde],120) d,CAST(CAST(Valor AS float) AS varchar(30)) v FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Parámetro Base] LIKE N'CNT[_]%' ORDER BY 1,3;
COMMIT;
