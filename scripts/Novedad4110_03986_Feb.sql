/* 03986 (729/15, MR08): ENFERMEDAD DE FEBRERO (4110) POR NOVEDAD DE IMPORTE CON EL VALOR DE META4, COMO ENERO.
   AU1 continua del 16/9/2025 al 30/4/2026. Meta4 promedia sobre un solo mes y BC sobre la ventana confirmada por el usuario (el vínculo actual; 12 meses de fase
   continua, ver ventana-promedio-ausentismo.md): febrero 6.089.167 (BC) contra 6.713.860 (Meta4), -9,3 %. En enero la diferencia ya se ajustó con una novedad de importe
   con el valor de Meta4 (2.229.960,88). Mismo criterio mientras dure el paralelo: la regla de BC es la correcta, la novedad sólo iguala el recibo.
   Rollback: borrar la novedad 4110 de 03986 del período 202602. Después: reiniciar el servicio y recalcular la regular de febrero de 03986 (LIQ-00053436). */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
SELECT * INTO #n FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [No_ Empleado] = N'03986' AND [Cód_ Período] = N'202601' AND [Cód_ Concepto] = N'4110';
SELECT COUNT(*) AS molde_esperado_1 FROM #n;
UPDATE #n SET [Cód_ Período] = N'202602', [Fecha] = '20260228', [Importe] = 6713860.00, [Estado] = 0, [No_ Liquidación] = N'', [Motivo No Aplicada] = N'',
              [Observaciones] = N'Meta4 liquido sobre un solo mes; BC promedia la fraccion activa (paralelo, febrero)', [$systemId] = NEWID();
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(N'dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]') AND c.name NOT IN ('timestamp', 'No_ Movimiento'));
EXEC (N'INSERT dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] (' + @cc + N') SELECT ' + @cc + N' FROM #n n WHERE NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] x WHERE x.[No_ Empleado] = N''03986'' AND x.[Cód_ Período] = N''202602'' AND x.[Cód_ Concepto] = N''4110'')');
SELECT @@ROWCOUNT AS Insertada_esperado_1;
SELECT [Cód_ Período], [Fecha], [Cód_ Tipo Liq_], [Cód_ Concepto], [Importe], [Estado] FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [No_ Empleado] = N'03986' AND [Cód_ Concepto] = N'4110' ORDER BY 1;
COMMIT;
