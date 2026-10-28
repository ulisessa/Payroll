/* PILOTAJE Y DIQUE: SUELDO (1043, 1033) Y A CUENTA DE FUTUROS AUMENTOS (2033, 2023), DESDE ABRIL DE 2026.
   Hasta ahora los cuatro conceptos existían sin fórmula (1033 y 1043 ni siquiera activos) y la fuente de días de pilotaje no existía: BC pagaba cero, y en abril Meta4 pagó pilotaje a 40 empleados (5 días cada uno; 2033 a 7).
   Lo que se midió en Meta4 (ARBPRO.M4_ACUMULADO_RL3, corrida del 21/4/2026, 40 empleados):
     - precio del día de pilotaje = 2 x PRECIO_PUERTO / 30 en 175/75 OF02/OF04 y en marinería (120.000 y 102.000 en OF02/OF04; 133.885,33 en MR00) y 1 x PRECIO_PUERTO / 30 en 768/19 OF01/OF03
       (5.500 USD y 4.304 USD x TC 1.718,7 / 30 = 315.100 y 246.600). Dique: 1 x PRECIO_PUERTO / 30 en todos (COEF_DIQUE 2 = COEF_PUERTO 2).
     - 2033 = garantizado de puerto prorrateado por los días de pilotaje - lo ganado (1043 + antigüedad), con piso en cero: 03664 = 1.370.000 - 685.200 = 684.800, igual que Meta4. Es la misma estructura que el 2013.
     - 6 de los 7 2033 de abril son incidencias manuales de Meta4 (importe), no fórmula: van por novedad (aparte, ver NovedadesMetaAbrilJunio).
   Cambios (todo con vigencia desde el 1/4/2026; las vigencias anteriores se cierran el 31/3):
     1. Fuente de datos DIAS_PILOTAJE: copia de DIAS_DIQUE con el estado PI.
     2. Parámetro COEF_PILOTAJE_PUERTO (precio de pilotaje sobre PRECIO_PUERTO): 2 general; 1 para 768/19 OF01 y OF03 (su PRECIO_PUERTO ya es el garantizado mensual en USD). Vigencia 1/1/2026.
     3. 1043 = DIAS_PILOTAJE * PRECIO_PUERTO / 30 * COEF_PILOTAJE_PUERTO * #COEF_PESQUERIA; 1033 = DIAS_DIQUE * PRECIO_PUERTO / 30 * #COEF_PESQUERIA. Activos, cantidad = los días, mismos tipos de liquidación que el 1083.
     4. 2033 / 2023 = MAX(0, VALOR_PUERTO_EMP / 30 * dias - (#1043|#1033 + #1023 + #1053 * dias / dias de la antigüedad)). Pasan al orden 553 / 552 porque leen el 1023 (orden 470): con el 186 / 184 de antes lo leían antes de calcularse.
     5. La suma de días de la antigüedad (1053), del feriado (1023) y de la resta de antigüedad del 2013 y del 2083 incluye DIAS_DIQUE + DIAS_PILOTAJE (la antigüedad de Meta4 también cuenta esos días).
   Rollback: borrar las vigencias del 2026-04-01 de 1023, 1033, 1043, 1053, 2013, 2023, 2033 y 2083 y volver el "Vigencia Hasta" de las anteriores a 1753-01-01; borrar la fuente DIAS_PILOTAJE (con sus filtros) y el parámetro COEF_PILOTAJE_PUERTO (cabecera y 3 filas vigentes).
   Después: reiniciar el servicio. Verificación: crear abril y comparar el 1043 (40 casos) y el 2033 (03664) con Meta4. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @TC nvarchar(300) = N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @FD nvarchar(300) = N'dbo.[ArbuTest$Fuente Datos Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @FF nvarchar(300) = N'dbo.[ArbuTest$Filtro Fuente Datos Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @PM nvarchar(300) = N'dbo.[ArbuTest$Parámetro$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @PV nvarchar(300) = N'dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @sys nvarchar(400) = N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000''';
DECLARE @sysc nvarchar(200) = N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]';
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] IN ('1033','1043','2023','2033') AND [Vigencia Desde]='20260401')
BEGIN PRINT 'Ya existen las vigencias'; ROLLBACK; RETURN; END;
DECLARE @sql nvarchar(max), @cc nvarchar(max);

/* 1. FUENTE DIAS_PILOTAJE (copia de DIAS_DIQUE con el estado PI) */
SET @cc = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@FD) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%' AND c.name NOT IN (N'Nombre Variable', N'Descripción'));
SET @sql = N'INSERT ' + @FD + N' ([Nombre Variable],[Descripción],' + @cc + @sysc + N') SELECT N''DIAS_PILOTAJE'', N''Días de pilotaje en un período'',' + @cc + @sys + N' FROM ' + @FD + N' WHERE [Nombre Variable]=N''DIAS_DIQUE'';';
EXEC sp_executesql @sql; SELECT @@ROWCOUNT AS Fuente_esperado_1;
SET @cc = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@FF) AND c.name <> 'timestamp' AND c.is_identity = 0 AND c.name NOT LIKE '$system%' AND c.name NOT IN (N'Nombre Variable', N'Filtro Valor'));
SET @sql = N'INSERT ' + @FF + N' ([Nombre Variable],[Filtro Valor],' + @cc + @sysc + N') SELECT N''DIAS_PILOTAJE'', CASE WHEN [Filtro Valor]=N''DQ'' THEN N''PI'' ELSE [Filtro Valor] END,' + @cc + @sys + N' FROM ' + @FF + N' WHERE [Nombre Variable]=N''DIAS_DIQUE'';';
EXEC sp_executesql @sql; SELECT @@ROWCOUNT AS Filtros_esperado_3;

/* 2. PARÁMETRO COEF_PILOTAJE_PUERTO: cabecera copiada de PRECIO_NAV (clave por convenio + categoría) y tres filas vigentes */
SET @cc = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@PM) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%' AND c.name NOT IN (N'Código', N'Descripción', N'Notas', N'Nombre Variable'));
SET @sql = N'INSERT ' + @PM + N' ([Código],[Descripción],[Notas],[Nombre Variable],' + @cc + @sysc + N') SELECT N''COEF_PILOTAJE_PUERTO'', N''Precio del día de pilotaje sobre PRECIO_PUERTO'', N''Meta4 1042: 2 x puerto salvo 768/19 OF01 y OF03 (garantizado USD): 1. Clave: COEF_PILOTAJE_PUERTO_[CCT]_[CAT]'', N''COEF_PILOTAJE_PUERTO'',' + @cc + @sys + N' FROM ' + @PM + N' WHERE [Código]=N''PRECIO_NAV'';';
EXEC sp_executesql @sql; SELECT @@ROWCOUNT AS Parametro_esperado_1;
SET @cc = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@PV) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%' AND c.name NOT IN (N'Cód_ Parámetro', N'Cód_ Parámetro Base', N'Vigencia Desde', N'Valor', N'Moneda', N'Cód_ Convenio', N'Cód_ Categoría', N'Nivel', N'Descripción', N'Notas', N'En Uso', N'No_ Empleado', N'Cód_ Variable TC', N'Sufijo Atributo 1', N'Sufijo Atributo 2', N'Sufijo Atributo 3'));
SET @sql = N'INSERT ' + @PV + N' ([Cód_ Parámetro],[Cód_ Parámetro Base],[Vigencia Desde],[Valor],[Moneda],[Cód_ Convenio],[Cód_ Categoría],[Nivel],[Descripción],[Notas],[En Uso],[No_ Empleado],[Cód_ Variable TC],[Sufijo Atributo 1],[Sufijo Atributo 2],[Sufijo Atributo 3],' + @cc + @sysc
 + N') SELECT @cod, N''COEF_PILOTAJE_PUERTO'', ''20260101'', @val, '''', @cv, @ct, @niv, N''Precio del día de pilotaje sobre PRECIO_PUERTO'', N''Medido en Meta4 (corrida del 21/4/2026)'', 0, '''', '''', '''', '''', '''',' + @cc + @sys + N' FROM ' + @PV + N' WHERE [Cód_ Parámetro]=N''PRECIO_NAV_175/75_OF02'' AND [Vigencia Desde]=''20260101'';';
EXEC sp_executesql @sql, N'@cod nvarchar(50),@val decimal(38,20),@cv nvarchar(20),@ct nvarchar(20),@niv int', N'COEF_PILOTAJE_PUERTO', 2, N'', N'', 0;
EXEC sp_executesql @sql, N'@cod nvarchar(50),@val decimal(38,20),@cv nvarchar(20),@ct nvarchar(20),@niv int', N'COEF_PILOTAJE_PUERTO_768/19_OF01', 1, N'768/19', N'OF01', 2;
EXEC sp_executesql @sql, N'@cod nvarchar(50),@val decimal(38,20),@cv nvarchar(20),@ct nvarchar(20),@niv int', N'COEF_PILOTAJE_PUERTO_768/19_OF03', 1, N'768/19', N'OF03', 2;

/* 3-5. CONCEPTOS: vigencia nueva desde el 1/4/2026 */
DECLARE @dias nvarchar(300) = N'IFZERO(DIAS_PROYECTO + DIAS_PUERTO + DIAS_GP_PERIODO + DIAS_FRANCOS_PERIODO + DIAS_ORD_PERIODO + DIAS_DIQUE + DIAS_PILOTAJE, 1)';
DECLARE @f1043 nvarchar(max) = N'DIAS_PILOTAJE * PRECIO_PUERTO / 30 * COEF_PILOTAJE_PUERTO * #COEF_PESQUERIA';
DECLARE @f1033 nvarchar(max) = N'DIAS_DIQUE * PRECIO_PUERTO / 30 * #COEF_PESQUERIA';
DECLARE @f2033 nvarchar(max) = N'IF(VALOR_PUERTO_EMP * DIAS_PILOTAJE = 0, 0, MAX(0, round(VALOR_PUERTO_EMP / 30 * DIAS_PILOTAJE - (#1043 + #1023 + #1053 * DIAS_PILOTAJE / ' + @dias + N'), PRECISION_REDONDEO)))';
DECLARE @f2023 nvarchar(max) = N'IF(VALOR_PUERTO_EMP * DIAS_DIQUE = 0, 0, MAX(0, round(VALOR_PUERTO_EMP / 30 * DIAS_DIQUE - (#1033 + #1023 + #1053 * DIAS_DIQUE / ' + @dias + N'), PRECISION_REDONDEO)))';
DECLARE @tla nvarchar(max) = (SELECT TOP 1 [Tipos Liq_ Aplicables] FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]='1083' AND [Vigencia Hasta]='17530101');
SET @cc = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@TC) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%' AND c.name NOT IN (N'Vigencia Desde', N'Vigencia Hasta', N'Fórmula', N'Activo', N'Variable Cantidad', N'Unidad Cantidad', N'Tipos Liq_ Aplicables', N'Orden Cálculo'));
SET @sql = N'INSERT ' + @TC + N' ([Vigencia Desde],[Vigencia Hasta],[Fórmula],[Activo],[Variable Cantidad],[Unidad Cantidad],[Tipos Liq_ Aplicables],[Orden Cálculo],' + @cc + @sysc
 + N') SELECT ''20260401'',''17530101'', ISNULL(@f, REPLACE([Fórmula], N''DIAS_ORD_PERIODO'', N''DIAS_ORD_PERIODO + DIAS_DIQUE + DIAS_PILOTAJE'')), CASE WHEN @act IS NULL THEN [Activo] ELSE @act END, ISNULL(@vc,[Variable Cantidad]), ISNULL(@uc,[Unidad Cantidad]), ISNULL(@t,[Tipos Liq_ Aplicables]), ISNULL(@o,[Orden Cálculo]),' + @cc + @sys
 + N' FROM ' + @TC + N' WHERE [Código]=@c AND [Vigencia Desde]=@d;';
DECLARE @alta TABLE (c nvarchar(20), d date, f nvarchar(max), act int, vc nvarchar(100), uc nvarchar(30), t nvarchar(max), o int);
INSERT @alta VALUES
 (N'1043','20260101',@f1043,1,N'DIAS_PILOTAJE',N'DIA',@tla,NULL),
 (N'1033','20260101',@f1033,1,N'DIAS_DIQUE',N'DIA',@tla,NULL),
 (N'2033','20260101',@f2033,NULL,NULL,NULL,NULL,553),
 (N'2023','20260101',@f2023,NULL,NULL,NULL,NULL,552),
 (N'1053','20260201',NULL,NULL,NULL,NULL,NULL,NULL),
 (N'1023','20260204',NULL,NULL,NULL,NULL,NULL,NULL),
 (N'2013','20260301',NULL,NULL,NULL,NULL,NULL,NULL),
 (N'2083','20260301',NULL,NULL,NULL,NULL,NULL,NULL);
DECLARE @c nvarchar(20), @d date, @f nvarchar(max), @act int, @vc nvarchar(100), @uc nvarchar(30), @t nvarchar(max), @o int;
DECLARE cur CURSOR FOR SELECT c,d,f,act,vc,uc,t,o FROM @alta;
OPEN cur; FETCH cur INTO @c,@d,@f,@act,@vc,@uc,@t,@o;
WHILE @@FETCH_STATUS = 0
BEGIN
  EXEC sp_executesql @sql, N'@c nvarchar(20),@d date,@f nvarchar(max),@act int,@vc nvarchar(100),@uc nvarchar(30),@t nvarchar(max),@o int', @c,@d,@f,@act,@vc,@uc,@t,@o;
  FETCH cur INTO @c,@d,@f,@act,@vc,@uc,@t,@o;
END
CLOSE cur; DEALLOCATE cur;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Vigencia Hasta]='20260331', [$systemModifiedAt]=SYSUTCDATETIME()
WHERE [Vigencia Hasta]='17530101' AND [Vigencia Desde]<'20260401' AND [Código] IN ('1033','1043','2023','2033','1053','1023','2013','2083');
SELECT @@ROWCOUNT AS Cerradas_esperado_8;
SELECT [Código] c, CONVERT(varchar(10),[Vigencia Desde],120) d, CONVERT(varchar(10),[Vigencia Hasta],120) h, [Activo] act, [Orden Cálculo] o, [Variable Cantidad] vc, LEN([Fórmula]) l,
  (LEN([Fórmula])-LEN(REPLACE([Fórmula],N'DIAS_PILOTAJE','')))/13 n_pil, (LEN([Fórmula])-LEN(REPLACE([Fórmula],N'DIAS_DIQUE','')))/10 n_diq
FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] IN ('1033','1043','2023','2033','1053','1023','2013','2083') AND [Vigencia Desde]>='20260301' ORDER BY 1,2;
SELECT [Cód_ Parámetro] p, [Nivel] n, [Valor] v, [Cód_ Convenio] cv, [Cód_ Categoría] ct FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Parámetro Base]=N'COEF_PILOTAJE_PUERTO';
COMMIT;
