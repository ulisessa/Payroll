/* GANANCIAS: DEDUCCIÓN DE FAMILIA ACUMULADA MES POR MES (VARIABLE DEDUC_GANANCIAS_ACUM) Y 5010 DESDE EL 1/3/2026.
   Requiere el código de Cod50016 `CalcDeduccionesGananciasAcum` publicado (publicado en la versión 1.0.0.676): sin él, la variable nueva da error al evaluarse.
   El 5010 calculaba la deducción del mes por los meses del año: (MNI + DESP + DEDUC_GANANCIAS) x MES_ANUAL. Meta4 acumula mes por mes. Se separan cuando la ficha de familia cambia dentro del año: un hijo que cumple 18
   en enero o febrero se deduce sólo hasta su mes de cumpleaños (00794, 04169 y 03664 en marzo de 2026), y una baja o un alta de mitad de año cuenta desde su mes.
   Cambio:
     1. La variable de sistema DEDUC_GANANCIAS_ACUM (cálculo DEDUC_GANANCIAS_ACUM) la siembra el upgrade al publicar (Cod50077); no hay que insertarla.
     2. Vigencia nueva del 5010 desde el 1/3/2026 (la del 1/2 se cierra el 28/2) con
          (MNI_ANUAL + DESP_4CAT_ANUAL + DEDUC_GANANCIAS) * MES_ANUAL       ->  ((MNI_ANUAL + DESP_4CAT_ANUAL) * MES_ANUAL + DEDUC_GANANCIAS_ACUM)
          (MNI_ANUAL + DESP_4CAT_ANUAL + DEDUC_GANANCIAS) * MES_ANUAL / 12  ->  ((MNI_ANUAL + DESP_4CAT_ANUAL) * MES_ANUAL + DEDUC_GANANCIAS_ACUM) / 12
        La rama de LIQ_FINAL no cambia (usa la deducción anual completa). Los gastos declarados siguen la regla de siempre (los del mes en curso por cada mes transcurrido): sólo cambia la familia.
   Sin cambios de familia dentro del año las dos cuentas dan lo mismo: no cambia el impuesto de quien tiene la ficha estable.
   Rollback: borrar la vigencia del 2026-03-01 del 5010 y volver el "Vigencia Hasta" de la del 2026-02-01 a 1753-01-01; la variable la deja el upgrade.
   Después: reiniciar el servicio y recalcular marzo (las que tienen impuesto: todas las REGULAR, DEVENGADOS y CIERRE_MAREA). */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @V nvarchar(300) = N'dbo.[ArbuTest$Variable Sistema Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @C nvarchar(300) = N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'5010' AND [Vigencia Desde]='20260301')
BEGIN PRINT 'Ya existe la variable o la vigencia'; ROLLBACK; RETURN; END;
DECLARE @sys nvarchar(400) = N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000''';
DECLARE @sysc nvarchar(200) = N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]';
DECLARE @cc nvarchar(max), @sql nvarchar(max);

/* 1. la variable de sistema DEDUC_GANANCIAS_ACUM la siembra el upgrade del código (Cod50077 Sembrar) al publicar: no se inserta acá. */

/* 2. 5010: vigencia nueva desde el 1/3/2026 */
DECLARE @r1 nvarchar(200) = N'((MNI_ANUAL + DESP_4CAT_ANUAL) * MES_ANUAL + DEDUC_GANANCIAS_ACUM) / 12';
DECLARE @r2 nvarchar(200) = N'((MNI_ANUAL + DESP_4CAT_ANUAL) * MES_ANUAL + DEDUC_GANANCIAS_ACUM)';
SET @cc = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@C) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%' AND c.name NOT IN (N'Vigencia Desde', N'Vigencia Hasta', N'Fórmula'));
SET @sql = N'INSERT ' + @C + N' ([Vigencia Desde],[Vigencia Hasta],[Fórmula],' + @cc + @sysc + N') SELECT ''20260301'',''17530101'',
   REPLACE(REPLACE([Fórmula], N''(MNI_ANUAL + DESP_4CAT_ANUAL + DEDUC_GANANCIAS) * MES_ANUAL / 12'', @r1), N''(MNI_ANUAL + DESP_4CAT_ANUAL + DEDUC_GANANCIAS) * MES_ANUAL'', @r2),' + @cc + @sys
  + N' FROM ' + @C + N' WHERE [Código]=N''5010'' AND [Vigencia Desde]=''20260201'';';
EXEC sp_executesql @sql, N'@r1 nvarchar(200),@r2 nvarchar(200)', @r1, @r2;
SELECT @@ROWCOUNT AS Alta_5010_esperado_1;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Vigencia Hasta]='20260228', [$systemModifiedAt]=SYSUTCDATETIME() WHERE [Código]=N'5010' AND [Vigencia Desde]='20260201' AND [Vigencia Hasta]='17530101';
SELECT @@ROWCOUNT AS Cerrada_esperado_1;
SELECT CONVERT(varchar(10),[Vigencia Desde],120) d, CONVERT(varchar(10),[Vigencia Hasta],120) h,
  (LEN([Fórmula])-LEN(REPLACE([Fórmula],N'DEDUC_GANANCIAS_ACUM','')))/20 n_acum, (LEN([Fórmula])-LEN(REPLACE([Fórmula],N'DEDUC_GANANCIAS)','')))/17 n_viejo
FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'5010' ORDER BY 1;
COMMIT;
