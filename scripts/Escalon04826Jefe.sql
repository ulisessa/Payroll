/* 04826 (Almirón) PASA A JEFE DE MÁQUINAS EN LA MAREA 8 DEL HF802 (13/2/2026): neto pactado 22.000 USD de marea y 9.000 de puerto.
   La planilla CONDICIONES OFICIALES POTEROS CAMPAÑA 26.xlsx lo lista dos veces: PRIMER OFICIAL DE MÁQUINAS (15.000 / 6.600, el que
   estaba cargado desde el 3/1) y JEFE DE MÁQUINAS junto con 04837 (22.000 / 9.000). El cierre del 1 al 12/2 cierra con 15.000 y el
   devengado del 13 al 28/2 de Meta4 (neto 11,25 M contra 7,67 M de BC) corresponde a 22.000/9.000: BC con esos valores da 11,1 M.
   Hace falta la vigencia desde el día de la salida de la marea y no desde el 1/2: acá el escalón es un cambio de puesto, no de mes.
   Rollback: borrar las cuatro filas de Vigencia Desde 2026-02-13 de USD_MAREA_04826, USD_PUERTO_04826, NETO_GU_MAREA_04826 y
   NETO_GU_PUERTO_04826.
   Después: reiniciar el servicio y recalcular el devengado del 13 al 28/2 de 04826 (y la final si la hubiera). */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
CREATE TABLE #m (cod nvarchar(30) COLLATE DATABASE_DEFAULT, valor decimal(38,10));
INSERT #m VALUES (N'USD_MAREA_04826', 22000), (N'NETO_GU_MAREA_04826', 22000), (N'USD_PUERTO_04826', 9000), (N'NETO_GU_PUERTO_04826', 9000);
SELECT m.cod, v.* INTO #t FROM #m m JOIN dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] v ON v.[Cód_ Parámetro] = m.cod AND v.[Vigencia Desde] = '20260103';
SELECT COUNT(*) AS moldes_esperado_4 FROM #t;
DECLARE @cols nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(N'dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]') AND c.name NOT IN ('timestamp', '$systemId', 'Vigencia Desde', 'Valor'));
DECLARE @sql nvarchar(max) = N'INSERT dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] (' + @cols + N',[$systemId],[Vigencia Desde],[Valor]) SELECT ' + @cols + N', NEWID(), ''20260213'', m.valor FROM #t t JOIN #m m ON m.cod = t.cod WHERE NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] x WHERE x.[Cód_ Parámetro] = t.cod AND x.[Vigencia Desde] = ''20260213'')';
EXEC (@sql);
COMMIT;

/* ------------------------------------------------------------------------------------------------------------------
   PUESTO de 04826: el ascenso a Jefe (OF02) venía cargado desde el 1/3; se adelanta al 13/2, salida de la marea 8.
   Antes: OF04 hasta el 28/2 y OF02 desde el 1/3. Después: OF04 hasta el 12/2 y OF02 desde el 13/2. (Aplicado el 15/10/2026.)
   Rollback: invertir las dos fechas. */
SET XACT_ABORT ON;
BEGIN TRAN;
UPDATE dbo.[ArbuTest$Atributo Entidad Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Vigencia Hasta] = '20260212', [$systemModifiedAt] = SYSUTCDATETIME()
WHERE [Tipo Entidad] = 0 AND [Cód_ Entidad] = N'04826' AND [Cód_ Tipo Atributo] = N'PUESTO' AND [Cód_ Valor] = N'OF04' AND [Vigencia Hasta] = '20260228';
SELECT @@ROWCOUNT AS Hasta_esperado_1;
UPDATE dbo.[ArbuTest$Atributo Entidad Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Vigencia Desde] = '20260213', [$systemModifiedAt] = SYSUTCDATETIME()
WHERE [Tipo Entidad] = 0 AND [Cód_ Entidad] = N'04826' AND [Cód_ Tipo Atributo] = N'PUESTO' AND [Cód_ Valor] = N'OF02' AND [Vigencia Desde] = '20260301';
SELECT @@ROWCOUNT AS Desde_esperado_1;
COMMIT;
