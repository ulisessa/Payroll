/* SAC DEVENGADO (4750) Y CUOTA SINDICAL SAC (4754) SIN EL BONO 4874, SÓLO MARZO DE 2026.
   El 4874 "Bono Fin de Año STIA - cuota marzo 2026" (190.000 fijos, 12 empleados, vigente sólo en marzo) integra BASE_IG4 pero Meta4 no lo cuenta en el SAC devengado: su BSAC_MES_RG3976 es (bruto - 190.000) / 12
   (90414: 306.370,12 contra el 4750 de BC de 322.203,46). Ese exceso de 15.833,33 entraba a la base de Ganancias (x19 % = 3.008,33) y a la cuota sindical del SAC (x2 % = 316,67): 90414 y 80267 quedaban +2.948,17 de impuesto (3.008,33 - 60,17)
   y +316,67 en el 4754. Los aportes 4751/4752/4753 ya coincidían: no leen el 4750.
   Cambio, para cada uno de 4750 y 4754 (hoy con la vigencia del 1/2 abierta):
     - se cierra la vigencia del 1/2 al 28/2;
     - vigencia 1/3 al 31/3 con la misma fórmula y "- #4874" dentro de la base (una referencia # a un concepto sin vigencia es un error, y el 4874 sólo existe en marzo);
     - vigencia desde el 1/4, abierta, con la fórmula de febrero (para no dejar un hueco).
   Si el bono vuelve en otro mes (cuota de abril, etc.), hay que repetir esto con la vigencia de ese mes.
   Rollback: borrar las filas del 1/3 y del 1/4 de ambos conceptos y reabrir la del 1/2 (Vigencia Hasta 1753-01-01).
   Después: reiniciar el servicio y recalcular marzo de los 12 empleados con 4874. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @C nvarchar(300) = N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] IN (N'4750',N'4754') AND [Vigencia Desde]='20260301')
BEGIN PRINT 'Ya existe'; ROLLBACK; RETURN; END;
DECLARE @sys nvarchar(400) = N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000''';
DECLARE @sysc nvarchar(200) = N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]';
DECLARE @cc nvarchar(max), @sql nvarchar(max);
SET @cc = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@C) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%' AND c.name NOT IN (N'Vigencia Desde', N'Vigencia Hasta', N'Fórmula'));
/* 1/3 - 31/3 con la exclusión */
SET @sql = N'INSERT ' + @C + N' ([Vigencia Desde],[Vigencia Hasta],[Fórmula],' + @cc + @sysc + N') SELECT ''20260301'',''20260331'',
   REPLACE([Fórmula], N''- #2803)'', N''- #2803 - #4874)''),' + @cc + @sys + N' FROM ' + @C + N' WHERE [Código] IN (N''4750'',N''4754'') AND [Vigencia Desde]=''20260201'';';
EXEC sp_executesql @sql;
SELECT @@ROWCOUNT AS Marzo_esperado_2;
/* desde el 1/4 la de febrero */
SET @sql = N'INSERT ' + @C + N' ([Vigencia Desde],[Vigencia Hasta],[Fórmula],' + @cc + @sysc + N') SELECT ''20260401'',''17530101'',[Fórmula],' + @cc + @sys
  + N' FROM ' + @C + N' WHERE [Código] IN (N''4750'',N''4754'') AND [Vigencia Desde]=''20260201'';';
EXEC sp_executesql @sql;
SELECT @@ROWCOUNT AS Abril_esperado_2;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Vigencia Hasta]='20260228', [$systemModifiedAt]=SYSUTCDATETIME() WHERE [Código] IN (N'4750',N'4754') AND [Vigencia Desde]='20260201' AND [Vigencia Hasta]='17530101';
SELECT @@ROWCOUNT AS Cerradas_esperado_2;
SELECT [Código],CONVERT(varchar(10),[Vigencia Desde],120) d,CONVERT(varchar(10),[Vigencia Hasta],120) h,(LEN([Fórmula])-LEN(REPLACE([Fórmula],N'#4874','')))/5 AS con_4874,REPLACE(LEFT([Fórmula],70),CHAR(13)+CHAR(10),' ') f FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] IN (N'4750',N'4754') ORDER BY 1,2;
COMMIT;
