/* ENFERMEDAD (4110): NOVEDADES DE IMPORTE CON EL VALOR DE META4 PARA LOS CASOS EN QUE LA REGLA DE BC ES LA CORRECTA Y DIFIERE DE META4, DE FEBRERO A JUNIO.
   Son los que ya tenían novedad en enero con una causa identificada: (a) excepción de RRHH, recaída con intervalo breve, se paga el valor del primero (01767, 01961, 02924),
   y (b) Meta4 promedia sobre un solo mes y BC sobre el vínculo actual (02737, 03986), ver ventana-promedio-ausentismo.md. 01607, 02449 y 04185 no tienen diferencia en febrero
   ni 4110 de Meta4 después. Se excluyen los cuatro de enero con "diferencia sin causa identificada" (02670, 02854, 03073, 04216): no hay una regla que sostener.
   Febrero: las cuatro diferencias medidas (01767 +174.997, 01961 +258.613, 02737 -6.263, 02924 -9.612; 03986 ya cargado). Marzo a junio: el valor de Meta4 de cada mes con 4110
   de esos empleados (BC no está calculado todavía; si BC coincidiera, la novedad sólo iguala). Molde: la novedad de enero de cada uno.
   Rollback: borrar las novedades 4110 con observación terminada en '(paralelo)' de los períodos 202602 a 202606. Después: reiniciar el servicio y recalcular. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
CREATE TABLE #v (emp nvarchar(20) COLLATE DATABASE_DEFAULT, per nvarchar(10) COLLATE DATABASE_DEFAULT, fecha date, importe decimal(38,2));
INSERT #v VALUES
 (N'01767', N'202602', '20260228', 1802197), (N'01961', N'202602', '20260228', 2404095), (N'02737', N'202602', '20260228', 2255069), (N'02924', N'202602', '20260228', 1190807),
 (N'01767', N'202603', '20260331', 1995289), (N'01961', N'202603', '20260331', 2661677), (N'03986', N'202603', '20260331', 7433202),
 (N'01767', N'202604', '20260430',  836734), (N'01961', N'202604', '20260430', 2575817), (N'03986', N'202604', '20260430', 7193422),
 (N'01961', N'202605', '20260531',  798503), (N'01961', N'202606', '20260630',  231823);
SELECT n.* INTO #m FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] n JOIN (SELECT DISTINCT emp FROM #v) e ON e.emp = n.[No_ Empleado] COLLATE DATABASE_DEFAULT WHERE n.[Cód_ Concepto] = N'4110' AND n.[Cód_ Período] = N'202601';
SELECT COUNT(*) AS moldes_esperado_5 FROM #m;
SELECT m.*, v.per AS nuevo_per, v.fecha AS nueva_fecha, v.importe AS nuevo_importe INTO #t FROM #m m JOIN #v v ON v.emp = m.[No_ Empleado] COLLATE DATABASE_DEFAULT;
UPDATE #t SET [Cód_ Período] = nuevo_per, [Fecha] = nueva_fecha, [Importe] = nuevo_importe, [Estado] = 0, [No_ Liquidación] = N'', [Motivo No Aplicada] = N'', [$systemId] = NEWID(),
              [Observaciones] = LEFT(CASE WHEN [Observaciones] LIKE N'%(paralelo)' THEN [Observaciones] ELSE [Observaciones] + N' (paralelo)' END, 250);
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(N'dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]') AND c.name NOT IN ('timestamp', 'No_ Movimiento'));
EXEC (N'INSERT dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] (' + @cc + N') SELECT ' + @cc + N' FROM #t t WHERE NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] x WHERE x.[No_ Empleado] = t.[No_ Empleado] AND x.[Cód_ Período] = t.[Cód_ Período] AND x.[Cód_ Concepto] = N''4110'')');
SELECT @@ROWCOUNT AS Insertadas_esperado_11;
SELECT [No_ Empleado] e, [Cód_ Período] p, CAST([Importe] AS bigint) imp, [Estado] est, RIGHT([Observaciones], 22) o FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Concepto] = N'4110' AND [Cód_ Período] >= N'202602' ORDER BY 2, 1;
COMMIT;
