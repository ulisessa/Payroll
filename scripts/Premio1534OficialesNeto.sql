/* PREMIO 1534 DE LOS OFICIALES DE NETO PACTADO (04724 y 04868): TAMBIÉN VA POR LA RAMA CON DEV_PREV_MAREA Y FERIADO.
   La rama "producción fija" del 1534 (MAX(producción, garantía CCT por DIAS_ENROLAMIENTO) menos lo devengado antes, menos básicos y
   menos el feriado 1023) estaba reservada a quien NO tiene neto pactado (NETO_GU_MAREA = 0 y ES_GROSSING_UP = 0). Los oficiales de
   neto pactado caían en la segunda rama, que ni resta el devengado anterior de la marea ni el feriado.
   Medido en febrero de 2026 con Meta4 (04724, HF802 marea 7):
     - Cierre del 1 al 12/2: premio Meta4 6.846.373 contra BC 8.629.273. La diferencia, 1.782.900 = 5.400 USD x 1.415 / 30 x 7, es la
       garantía CCT de los 7 días de enero que el devengado de enero ya pagó (DEV_PREV_MAREA). 9.516.107 (premio + básicos de BC)
       menos 1.782.900 da 7.733.207, el TOT_REMUN_27617 de Meta4, al peso.
     - Devengado del 13 al 28/2: premio Meta4 2.664.738 = 5.400 x 1.370 / 30 x 16 - básicos (con antigüedad y feriado). BC daba 2.819.450
       por no restar el feriado 1023 (140.768) ni la antigüedad.
   En los de neto pactado el total de la liquidación lo fija el grossing-up (2003 completa el objetivo), así que para 04868 el cambio sólo
   reparte distinto entre 1534 y 2003: su bruto ya cerraba. Para 04724 el cierre no tiene 2003 y por eso se notaba.
   Cambio: nueva vigencia 2026-02-03 del 1534 (la 2026-02-02 se cierra el 02-02) sin "NETO_GU_MAREA = 0 AND ES_GROSSING_UP = 0" en la
   condición de la primera rama. Enero no cambia: no alcanza ninguna fecha de enero.
   Rollback: DELETE de la fila 1534 con Vigencia Desde 2026-02-03 y UPDATE [Vigencia Hasta] = '17530101' en la 2026-02-02.
   Después: reiniciar el servicio y recalcular los cierres y devengados de febrero de 04724 y 04868 (cierre primero). */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @T nvarchar(300) = N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'1534' AND [Vigencia Desde]='20260203')
BEGIN PRINT 'Ya existe la vigencia 2026-02-03'; ROLLBACK; RETURN; END;
DECLARE @old nvarchar(max) = (SELECT [Fórmula] FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'1534' AND [Vigencia Desde]='20260202');
DECLARE @quitar nvarchar(100) = N' AND NETO_GU_MAREA = 0 AND ES_GROSSING_UP = 0';
IF CHARINDEX(@quitar, @old) = 0 BEGIN PRINT 'No se encontró el texto a quitar'; ROLLBACK; RETURN; END;
DECLARE @f nvarchar(max) = REPLACE(@old, @quitar, N'');
SELECT LEN(@old) len_vieja, LEN(@f) len_nueva;
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @cs nvarchar(max) = (SELECT STRING_AGG(CASE c.name
   WHEN N'Vigencia Desde' THEN N'''20260203'''
   WHEN N'Vigencia Hasta' THEN N'''17530101'''
   WHEN N'Fórmula' THEN N'@f'
   ELSE QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @sql nvarchar(max) = N'INSERT ' + @T + N' (' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy])
SELECT ' + @cs + N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000''
FROM ' + @T + N' WHERE [Código]=N''1534'' AND [Vigencia Desde]=''20260202'';';
EXEC sp_executesql @sql, N'@f nvarchar(max)', @f = @f;
SELECT @@ROWCOUNT AS Insertada_esperado_1;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
SET [Vigencia Hasta]='20260202', [$systemModifiedAt]=SYSUTCDATETIME()
WHERE [Código]=N'1534' AND [Vigencia Desde]='20260202' AND [Vigencia Hasta]='17530101';
SELECT @@ROWCOUNT AS Cerrada_esperado_1;
SELECT [Vigencia Desde],[Vigencia Hasta],[Orden Cálculo],[Tipos Liq_ Aplicables],LEN([Fórmula]) len_f FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'1534' ORDER BY 1;
COMMIT;

/* ------------------------------------------------------------------------------------------------------------------
   04921 (Jefe de Máquinas, HF801): el escalón de febrero (20.000 USD) arranca con la marea 8 (17/2) y no el 1/2.
   Meta4: el cierre del 1 al 16/2 de la marea 7 paga 17.000 USD (neto 8.444.933 + anticipo 250.000 = 16/30 x 17.000 x 1.370 x 0,70)
   y el devengado del 17 al 28/2 paga 20.000. BC con la vigencia al 1/2 daba 14,6 M de tapón contra 12,0 M. 04836, con el mismo
   escalón mensual, cierra con el valor de febrero desde el 1/2: no se toca.
   Antes: USD_MAREA_04921 / NETO_GU_MAREA_04921 = 20.000 desde 2026-02-01. Después: desde 2026-02-17. Rollback: invertir la fecha. */
SET XACT_ABORT ON;
BEGIN TRAN;
UPDATE dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Vigencia Desde]='20260217', [$systemModifiedAt]=SYSUTCDATETIME()
WHERE [Cód_ Parámetro] IN (N'USD_MAREA_04921', N'NETO_GU_MAREA_04921') AND [Vigencia Desde]='20260201' AND [Valor]=20000;
SELECT @@ROWCOUNT AS Escalon_esperado_2;
COMMIT;
