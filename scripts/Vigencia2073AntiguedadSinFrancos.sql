/* ADICIONAL TAREAS MECÁNICAS (2073): LA ANTIGÜEDAD DE SU BASE NO INCLUYE LA DE LOS DÍAS DE FRANCO. VIGENCIA DESDE EL 1/3/2026.
   03196 (175/75, GP + franco en marzo): Meta4 2073 = 773.976 = 15 % de 5.159.840 = 1083 1.020.000 + 2013 4.012.340 + 1053 127.500 (la antigüedad de los 20 días de GP, la corrida del 18/3); BC = 781.649,25 = 15 % de
   5.210.995, con el 1053 entero de la regular (197.625: también los 11 días de franco, 70.125). Mismo criterio que el 2083 y el 2013 (scripts/VigenciaAntiguedadPorTramo2083y2013.sql): el adicional es un % de lo que
   se paga por los días de marea y puerto, no por los de franco.
   Cambio: vigencia nueva desde el 1/3/2026 (la del 1/1 se cierra el 28/2) con `#1053` -> `#1053 * (1 - DIAS_FRANCOS_PERIODO / IFZERO(suma de días de la antigüedad, 1))`. Es el único 2073 de enero a marzo con días de franco:
   no cambia ningún otro. Queda sin explicar el efecto del TC de la corrida: Meta4 valuó el 2013 de 03196 al TC del 18/3 (1.360) y BC al del mes (1.355): 2013 -18.970 y 2073 -2.845 (15 % de esa diferencia).
   Rollback: borrar la vigencia del 2026-03-01 y volver el "Vigencia Hasta" de la del 2026-01-01 a 1753-01-01. Después: reiniciar el servicio y recalcular la REGULAR de marzo de 03196. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @TC nvarchar(300) = N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]='2073' AND [Vigencia Desde]='20260301')
BEGIN PRINT 'Ya existe la vigencia'; ROLLBACK; RETURN; END;
DECLARE @dias nvarchar(300) = N'IFZERO(DIAS_PROYECTO + DIAS_PUERTO + DIAS_GP_PERIODO + DIAS_FRANCOS_PERIODO + DIAS_ORD_PERIODO + DIAS_DIQUE + DIAS_PILOTAJE, 1)';
DECLARE @rep nvarchar(400) = N'#1053 * (1 - DIAS_FRANCOS_PERIODO / ' + @dias + N'))';
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@TC) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%' AND c.name NOT IN (N'Vigencia Desde', N'Vigencia Hasta', N'Fórmula'));
DECLARE @sql nvarchar(max) = N'INSERT ' + @TC + N' ([Vigencia Desde],[Vigencia Hasta],[Fórmula],' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ''20260301'',''17530101'',REPLACE([Fórmula], N''#1053)'', @rep),' + @cc
  + N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'' FROM ' + @TC + N' WHERE [Código]=N''2073'' AND [Vigencia Desde]=''20260101'';';
EXEC sp_executesql @sql, N'@rep nvarchar(400)', @rep;
SELECT @@ROWCOUNT AS Alta_esperado_1;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Vigencia Hasta]='20260228', [$systemModifiedAt]=SYSUTCDATETIME() WHERE [Código]='2073' AND [Vigencia Desde]='20260101' AND [Vigencia Hasta]='17530101';
SELECT @@ROWCOUNT AS Cerrada_esperado_1;
SELECT CONVERT(varchar(10),[Vigencia Desde],120) d, CONVERT(varchar(10),[Vigencia Hasta],120) h, (LEN([Fórmula])-LEN(REPLACE([Fórmula],N'DIAS_FRANCOS_PERIODO',N'')))/20 n_fr FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]='2073' ORDER BY 1;
COMMIT;
