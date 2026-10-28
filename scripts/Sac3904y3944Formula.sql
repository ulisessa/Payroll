/* SAC SOBRE LA INDEMNIZACIÓN SUSTITUTIVA DEL PREAVISO (3904) Y SOBRE LA INTEGRACIÓN DEL MES DE DESPIDO (3944): FÓRMULA DESDE EL 1/3/2026.
   Los dos conceptos existían en BC sin fórmula (importe cero siempre). 90315 (FA31, LIQ_FINAL de marzo) los cobra en Meta4: SAC_IND_PREAVISO 317.938,80 = 3903 / 12 y SAC_IND_INTEG 95.381,64 = 3943 / 12;
   suman 413.320,44, que era la diferencia de bruto que le quedó a 90315 después de corregir el SAC de egreso (-413.320 en el comparador; antes quedaba tapada por el +70.229 del 3813).
   Fórmulas originales de Meta4 (M4_TEXTO_FORMULA_1, 2009-03-01): 3904 = #3903 / 12 y 3944 = @3943 / 12.
   Cambio: vigencia nueva desde el 1/3/2026 (la del 1/1 se cierra el 28/2) con ROUND(#3903 / 12, PRECISION_REDONDEO) y ROUND(#3943 / 12, PRECISION_REDONDEO), como el 3974. Pasan al orden 452 y 453:
   leen el 3903 y el 3943, que están en 451, y con el mismo orden los leían antes de que se calcularan. Es el único caso con preaviso o integración en enero a marzo: no cambia ninguna otra liquidación.
   Rollback: borrar las dos vigencias del 2026-03-01 y volver el "Vigencia Hasta" de las del 2026-01-01 a 1753-01-01.
   Después: reiniciar el servicio y recalcular la LIQ_FINAL de marzo de 90315. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @TC nvarchar(300) = N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] IN ('3904','3944') AND [Vigencia Desde]='20260301')
BEGIN PRINT 'Ya existen las vigencias'; ROLLBACK; RETURN; END;
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@TC) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%' AND c.name NOT IN (N'Vigencia Desde', N'Vigencia Hasta', N'Fórmula', N'Orden Cálculo'));
DECLARE @sql nvarchar(max) = N'INSERT ' + @TC + N' ([Vigencia Desde],[Vigencia Hasta],[Fórmula],[Orden Cálculo],' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ''20260301'',''17530101'',@f,@o,' + @cc
  + N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'' FROM ' + @TC + N' WHERE [Código]=@c AND [Vigencia Desde]=''20260101'';';
EXEC sp_executesql @sql, N'@f nvarchar(max),@o int,@c nvarchar(20)', N'ROUND(#3903 / 12, PRECISION_REDONDEO)', 452, N'3904';
EXEC sp_executesql @sql, N'@f nvarchar(max),@o int,@c nvarchar(20)', N'ROUND(#3943 / 12, PRECISION_REDONDEO)', 453, N'3944';
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Vigencia Hasta]='20260228', [$systemModifiedAt]=SYSUTCDATETIME() WHERE [Código] IN ('3904','3944') AND [Vigencia Desde]='20260101' AND [Vigencia Hasta]='17530101';
SELECT @@ROWCOUNT AS Cerradas_esperado_2;
SELECT [Código] c, CONVERT(varchar(10),[Vigencia Desde],120) d, CONVERT(varchar(10),[Vigencia Hasta],120) h, [Orden Cálculo] o, [Fórmula] f FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] IN ('3904','3944') ORDER BY 1,2;
COMMIT;
