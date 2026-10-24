/* APORTE PATRONAL AL INACAP DE FEC (Comercio): 0,5% mensual del salario inicial de la categoría Maestranza A.
   Confirmado por RRHH el 15/10/2026: es la única contribución de FEC. Meta4 la lleva en CNT_INACAP (dentro de
   OTR_CONTR_A_PAG): enero de 2026, un solo empleado (90157, convenio 130/75, categoría EC01 = Maestranza A),
   5.278,975 = 0,5% x 1.055.795.
   EC01 es la única categoría del convenio 130/75, así que el salario inicial de Maestranza A es el BASICO de ese
   empleado. Si 130/75 llegara a tener otra categoría, la fórmula tendría que apuntar al BASICO de EC01 y no al propio.
   Se modela sin código nuevo:
     1. Valor Atributo SINDICATO FEC: Sufijo Parámetro = FEC.
     2. Parámetro PCT_INACAP (eje SINDICATO), vigente PCT_INACAP_FEC = 0,5 desde 1/1/2026.
     3. Concepto 7094 (Contribución Patronal), molde del 7090, sólo REGULAR (es mensual y el sueldo viene en la regular).
   Rollback: borrar el concepto 7094, el parámetro con su vigente y vaciar el Sufijo de FEC.
   Después: reiniciar el servicio y recalcular. El comparador excluye 7090..7099 de las contribuciones SICOSS. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;

UPDATE dbo.[ArbuTest$Valor Atributo Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
SET [Sufijo Parámetro] = N'FEC', [$systemModifiedAt] = SYSUTCDATETIME()
WHERE [Cód_ Tipo Atributo] = N'SINDICATO' AND [Código] = N'FEC' AND [Sufijo Parámetro] = N'';
SELECT @@ROWCOUNT AS Sufijo_esperado_1;

SELECT [Código],[Descripción],[Notas],[Nombre Variable],[Sufijo CCT],[$systemId],[$systemCreatedBy],[$systemModifiedBy],[Sufijo Empleado],[Antigüedad Máxima Vigencia],[Sufijo Convenio],[Edad Máxima Familiar],[Cód_ Tipo Atributo 1],[Cód_ Tipo Atributo 2],[Cód_ Tipo Atributo 3] INTO #pb FROM dbo.[ArbuTest$Parámetro$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] = N'PCT_ART';
UPDATE #pb SET [Código] = N'PCT_INACAP', [Nombre Variable] = N'PCT_INACAP', [Descripción] = N'Aporte patronal al INACAP sobre el salario inicial de Maestranza A',
    [Notas] = N'Eje: SINDICATO (FEC). Meta4: CNT_INACAP.', [Cód_ Tipo Atributo 1] = N'SINDICATO', [Cód_ Tipo Atributo 2] = N'', [Cód_ Tipo Atributo 3] = N'', [$systemId] = NEWID();
INSERT dbo.[ArbuTest$Parámetro$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ([Código],[Descripción],[Notas],[Nombre Variable],[Sufijo CCT],[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy],[Sufijo Empleado],[Antigüedad Máxima Vigencia],[Sufijo Convenio],[Edad Máxima Familiar],[Cód_ Tipo Atributo 1],[Cód_ Tipo Atributo 2],[Cód_ Tipo Atributo 3])
SELECT [Código],[Descripción],[Notas],[Nombre Variable],[Sufijo CCT],[$systemId],SYSUTCDATETIME(),[$systemCreatedBy],SYSUTCDATETIME(),[$systemModifiedBy],[Sufijo Empleado],[Antigüedad Máxima Vigencia],[Sufijo Convenio],[Edad Máxima Familiar],[Cód_ Tipo Atributo 1],[Cód_ Tipo Atributo 2],[Cód_ Tipo Atributo 3] FROM #pb
WHERE NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Parámetro$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] x WHERE x.[Código] = N'PCT_INACAP');
SELECT @@ROWCOUNT AS Cabecera_esperado_1;

IF NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Parámetro] = N'PCT_INACAP_FEC' AND [Vigencia Desde] = '20260101')
    INSERT dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
        ([Cód_ Parámetro Base],[Cód_ Parámetro],[Vigencia Desde],[Descripción],[Valor],[Moneda],[En Uso],[Notas],[No_ Empleado],[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy],[Cód_ Convenio],[Cód_ Categoría],[Nivel],[Cód_ Variable TC],[Sufijo Atributo 1],[Sufijo Atributo 2],[Sufijo Atributo 3])
    SELECT TOP 1 N'PCT_INACAP', N'PCT_INACAP_FEC', '20260101', N'', 0.5, N'', 0, N'Aporte patronal al INACAP (Meta4: CNT_INACAP)', N'', NEWID(), SYSUTCDATETIME(), [$systemCreatedBy], SYSUTCDATETIME(), [$systemModifiedBy], N'', N'', 0, N'', N'FEC', N'', N''
    FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Parámetro] = N'PCT_ART' AND [Vigencia Desde] = '20260101';
SELECT [Cód_ Parámetro], [Valor], [Sufijo Atributo 1] FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Parámetro Base] = N'PCT_INACAP';

SELECT * INTO #cp FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] = N'7090' AND [Vigencia Desde] = '20260101';
UPDATE #cp SET [Código] = N'7094', [Descripción] = N'Aporte INACAP (Comercio)', [Nombre Impresión] = N'',
    [Fórmula] = N'ROUND(PCT_INACAP / 100 * BASICO, PRECISION_REDONDEO)', [Condición] = N'PCT_INACAP > 0',
    [Tipos Liq_ Aplicables] = N'REGULAR', [Orden Cálculo] = 943, [$systemId] = NEWID();
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]') AND c.name <> 'timestamp');
DECLARE @sqlc nvarchar(max) = N'INSERT dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] (' + @cc + N') SELECT ' + @cc + N' FROM #cp WHERE NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] x WHERE x.[Código] = N''7094'')';
EXEC (@sqlc);
SELECT @@ROWCOUNT AS Concepto_esperado_1;
SELECT [Código], [Tipo Concepto], [Orden Cálculo], [Condición], [Tipos Liq_ Aplicables], [Fórmula] FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] = N'7094';
COMMIT;
