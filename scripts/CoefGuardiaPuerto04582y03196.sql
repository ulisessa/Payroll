/* COEF_GUARDIA_PUERTO = 1,4 PARA 04582 Y 03196 (175/75, guardia de puerto de febrero de 2026).
   Meta4 paga el 2013 con el coeficiente 1,4 en estos dos y sin coeficiente en 03039, así que no es del convenio: es por empleado, como 00794
   (parámetro por empleado COEF_GUARDIA_PUERTO_00794, 1,4 desde el 1/1). Los de convenio 175/75 y 729/15 recién arrancan el 1/5.
   04582: 2013 de BC 2.920.313 contra 4.712.702 de Meta4; con 1,4 da 4.667.702 (45.000 de diferencia = el 1073, sueldo a órdenes, que Meta4 no
   resta del 2013 y BC sí). 03196: 2.450.450 contra 3.935.530; con 1,4 da exacto.
   Vigencia desde 2026-02-01: es el único mes medido. Rollback: borrar las dos filas. Después: reiniciar el servicio y recalcular las regulares de febrero. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
SELECT m.e, v.* INTO #t FROM (VALUES (N'04582'), (N'03196')) m(e) CROSS JOIN dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] v WHERE v.[Cód_ Parámetro] = N'COEF_GUARDIA_PUERTO_00794';
SELECT COUNT(*) AS moldes_esperado_2 FROM #t;
DECLARE @cols nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(N'dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]') AND c.name NOT IN ('timestamp','$systemId','Cód_ Parámetro','No_ Empleado','Vigencia Desde','Notas'));
DECLARE @sql nvarchar(max) = N'INSERT dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] (' + @cols + N',[$systemId],[Cód_ Parámetro],[No_ Empleado],[Vigencia Desde],[Notas]) SELECT ' + @cols + N', NEWID(), N''COEF_GUARDIA_PUERTO_'' + t.e, t.e, ''20260201'', N''Verificado contra Meta4 en febrero de 2026: con 1,4 el 2013 da exacto (guardia de puerto, 175/75).'' FROM #t t WHERE NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] x WHERE x.[Cód_ Parámetro] = N''COEF_GUARDIA_PUERTO_'' + t.e AND x.[Vigencia Desde] = ''20260201'')';
EXEC (@sql);
SELECT @@ROWCOUNT AS Insertadas_esperado_2;
SELECT [Cód_ Parámetro],[Valor],[Vigencia Desde],[No_ Empleado] FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Parámetro Base] = N'COEF_GUARDIA_PUERTO' ORDER BY 1;
COMMIT;
