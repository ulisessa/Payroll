/* ESCALÓN DE MARZO DE 04163 (USD_MAREA Y NETO_GU_MAREA, 12.000 -> 15.000): DESDE LA SALIDA DE LA MAREA DE MARZO (23/3), NO DESDE EL 1/3.
   Con las liquidaciones de marzo de 04163 se pudo verificar lo que no se podía en enero y febrero ("no tiene liquidaciones con qué verificarse", acuerdo-escalonado-por-mes-calendario): sus escalones se habían movido de las
   salidas del HF802 (26/1 y 13/2) al 1/2 y al 1/3. Meta4 liquidó el cierre de marea del 13/3 (cobertura 1 al 22/3, 22 días) con 12.000 USD: LIQUIDO 8.127.600 = 12.000 x 1.360 x 70 % x 22/30 - 250.000 de anticipo
   (BC, con 15.000 desde el 1/3, daba 10.221.994 y un 2003 de 13.913.469 contra 10.611.463 de Meta4). La DEVENGADOS del 23 al 31/3 sí usa 15.000 (4.268.250 en los dos sistemas).
   O sea: el escalón de marzo arranca con la salida de la marea nueva (23/3), igual que 04826 (13/2) y 04921 (17/2), que ya estaban en la fecha de salida y cuadran.
   Cambio: en USD_MAREA_04163 y NETO_GU_MAREA_04163 la fila del 1/3 pasa a 12.000 (el valor de febrero, que sigue rigiendo hasta la salida) y se agrega una fila del 23/3 con 15.000.
   Rollback: borrar las filas del 23/3 y volver las del 1/3 a 15.000.
   Después: reiniciar el servicio y recalcular el CIERRE_MAREA de marzo de 04163 (la DEVENGADOS no cambia). */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @T nvarchar(300) = N'dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Parámetro] IN (N'USD_MAREA_04163',N'NETO_GU_MAREA_04163') AND [Vigencia Desde]='20260323')
BEGIN PRINT 'Ya existen las filas del 23/3'; ROLLBACK; RETURN; END;
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%' AND c.name NOT IN (N'Vigencia Desde', N'Notas', N'En Uso'));
DECLARE @sql nvarchar(max) = N'INSERT ' + @T + N' ([Vigencia Desde],[Notas],[En Uso],' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ''20260323'', N''Escalón de marzo desde la salida de la marea (23/3): Meta4 liquidó el cierre del 13/3 con 12.000 y la devengada del 23/3 con 15.000. Ver EscalonGU04163Marzo.sql'', 0,' + @cc
  + N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'' FROM ' + @T + N' WHERE [Cód_ Parámetro] IN (N''USD_MAREA_04163'',N''NETO_GU_MAREA_04163'') AND [Vigencia Desde]=''20260301'';';
EXEC (@sql);
SELECT @@ROWCOUNT AS Altas_esperado_2;
UPDATE dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Valor]=12000, [Notas]=N'Escalón de febrero (12.000) hasta la salida de la marea de marzo (23/3). Ver EscalonGU04163Marzo.sql', [$systemModifiedAt]=SYSUTCDATETIME()
WHERE [Cód_ Parámetro] IN (N'USD_MAREA_04163',N'NETO_GU_MAREA_04163') AND [Vigencia Desde]='20260301' AND [Valor]=15000;
SELECT @@ROWCOUNT AS Modificadas_esperado_2;
SELECT [Cód_ Parámetro] p, CONVERT(varchar(10),[Vigencia Desde],120) d, CAST([Valor] AS decimal(10,2)) v, Moneda FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Parámetro] IN (N'USD_MAREA_04163',N'NETO_GU_MAREA_04163') ORDER BY 1,2;
COMMIT;
