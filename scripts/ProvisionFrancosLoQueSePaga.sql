/* =====================================================================================================================
   Provisión de francos "a lo que se paga", con sus cargas (28/10/2026)

   Qué hace (decidido con el usuario el 28/10/2026, ver Vault/07 Lecciones/planilla-francos-no-es-meta4.md):
     1. La regla del 1062 (Lotes de francos) valúa cada lote como la planilla de francos devengados de contaduría:
          Fórmula Valor Franco = IFZERO(VALOR_FRANCO_EMP, VALOR_FRANCO)   -> OF02/OF04 al acuerdo de empresa
          Precio por Puesto    = 1                                        -> el mayor entre categoría y puesto
          Sin Coef Pesquería   = 1                                        -> 100 % también en tangoneros
     2. Concepto CNT_FRANCO_DEV: sólo da nombre a las reglas de las cargas. Informativo, sin fórmula e INACTIVO: el motor
        no lo calcula; la previa del asiento lo arma lote por lote.
     3. Reglas de CNT_FRANCO_DEV (Cargas sobre lotes de francos), una por sede como las del 1062: debe a cargas sociales de
        la sede (6110002…), haber 2113029 A CONFIRMAR. La tasa de cada lote es CNT_SAC_DEV / 4750 de su liquidación de
        origen: la patronal neta del crédito IVA, con la zona del empleado.

   Requiere la extensión con los campos 21-25 de Regla Asiento Liq. (1.0.0.710 o posterior).
   Idempotente. @Aplicar = 0 prueba y vuelve atrás. Después de aplicar, REINICIAR EL SERVICIO DE BC: el SQL directo
   deja la caché rancia.

   Vuelta atrás:
     UPDATE Regla Asiento Liq. SET [Fórmula Valor Franco] = '', [Precio por Puesto] = 0, [Sin Coef Pesquería] = 0
       WHERE [Cód_ Concepto] = '1062';
     DELETE Regla Asiento Liq. WHERE [Cód_ Concepto] = 'CNT_FRANCO_DEV';
     DELETE Concepto Liquidación WHERE [Código] = 'CNT_FRANCO_DEV';
   ===================================================================================================================== */
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @Aplicar bit = 0;
DECLARE @Vig date = '20260101';
DECLARE @Concepto nvarchar(20) = N'CNT_FRANCO_DEV';
DECLARE @Pasivo nvarchar(20) = N'2113029';
DECLARE @Formula nvarchar(250) = N'IFZERO(VALOR_FRANCO_EMP, VALOR_FRANCO)';
DECLARE @TR nvarchar(300) = N'dbo.[ArbuTest$Regla Asiento Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @TC nvarchar(300) = N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';

IF COL_LENGTH(@TR, N'Concepto Base Tasa') IS NULL
BEGIN
  RAISERROR('Regla Asiento Liq. no tiene los campos nuevos: publicar la extensión (1.0.0.710 o posterior) y volver a correr.', 16, 1);
  RETURN;
END;

BEGIN TRAN;

/* ---------- 1. Concepto ancla ----------
   Copia las columnas de un concepto informativo de la misma vigencia (4755), como SembrarAsientoSueldos.sql. */
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(CAST(QUOTENAME(c.name) AS nvarchar(max)), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@TC)
    AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%'
    AND c.name NOT IN (N'Código', N'Vigencia Desde', N'Descripción', N'Nombre Impresión', N'Tipo Concepto', N'Imprime en Recibo', N'Activo',
                       N'Es Acumulador', N'Vigencia Hasta', N'Orden Cálculo', N'Fórmula Orden Cálculo', N'Es Devengo', N'Grupo Costo Laboral', N'Condición',
                       N'Fórmula'));
DECLARE @sql nvarchar(max) = N'INSERT ' + @TC + N' (' + @cc + N',[Código],[Vigencia Desde],[Descripción],[Nombre Impresión],[Tipo Concepto],[Imprime en Recibo],'
  + N'[Activo],[Es Acumulador],[Vigencia Hasta],[Orden Cálculo],[Fórmula Orden Cálculo],[Es Devengo],[Grupo Costo Laboral],[Condición],[Fórmula],'
  + N'[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) '
  + N'SELECT ' + @cc + N',@cod,@vig,N''Cargas s/ francos devengados'',N''Cargas s/ francos devengados'',6,0,0,0,''17530101'',946,N''946'',1,2,N'''',N'''','
  + N'NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'' FROM ' + @TC
  + N' WHERE [Código] = N''4755'' AND [Vigencia Desde] = ''20260101'' AND NOT EXISTS (SELECT 1 FROM ' + @TC + N' x WHERE x.[Código] = @cod);'
  + N' SELECT @@ROWCOUNT AS Concepto_creado;';
EXEC sp_executesql @sql, N'@cod nvarchar(20), @vig date', @Concepto, @Vig;
IF NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] = @Concepto)
BEGIN RAISERROR('No se pudo crear el concepto (¿falta el 4755 con vigencia 2026-01-01?).', 16, 1); ROLLBACK; RETURN; END;

/* ---------- 2. La regla de francos valúa lo que se paga ---------- */
SET @sql = N'UPDATE ' + @TR + N' SET [Fórmula Valor Franco] = @f, [Precio por Puesto] = 1, [Sin Coef Pesquería] = 1
  WHERE [Cód_ Concepto] = N''1062'' AND [Provisión] = 2
    AND ([Fórmula Valor Franco] <> @f OR [Precio por Puesto] <> 1 OR [Sin Coef Pesquería] <> 1);
  SELECT @@ROWCOUNT AS Reglas_1062_actualizadas;
  SELECT COUNT(*) AS Reglas_1062, SUM(CASE WHEN [Fórmula Valor Franco] = @f AND [Precio por Puesto] = 1 AND [Sin Coef Pesquería] = 1 THEN 1 ELSE 0 END) AS Con_lo_que_se_paga
  FROM ' + @TR + N' WHERE [Cód_ Concepto] = N''1062'';';
EXEC sp_executesql @sql, N'@f nvarchar(250)', @Formula;

/* ---------- 3. Reglas de las cargas, una por sede ----------
   Mismas sedes y filtros que SembrarAsientoSueldos.sql; el debe es la cuenta de cargas sociales de la sede. */
DECLARE @Sede TABLE (Sede nvarchar(10) PRIMARY KEY, Filtro nvarchar(100), Contrib nvarchar(20));
INSERT @Sede VALUES
 (N'GEN',  N'',                                                                                         N'6110002'),
 (N'BA',   N'PN-ADM-BAIRES|PN-ADM-MARDEL',                                                              N'6311002'),
 (N'SC',   N'PN-ADM-PTODDO',                                                                            N'6312002'),
 (N'CH',   N'PN-ADM-COMRIV|PN-ADM-PTOMDY',                                                              N'6313002'),
 (N'OADM', N'PN-ADM*&<>PN-ADM-BAIRES&<>PN-ADM-MARDEL&<>PN-ADM-PTODDO&<>PN-ADM-COMRIV&<>PN-ADM-PTOMDY', N'6110002'),
 (N'PL',   N'PN-ARB*|PP-ARB*|PN-PCR*|PP-PCR*|PN-PPM*|PP-PPM*',                                          N'6106002');

-- Las sedes tienen que ser las de la regla del 1062: si alguien cambió sus filtros, las cargas irían a otro lado.
DECLARE @SedeJson nvarchar(max) = (SELECT * FROM @Sede FOR JSON PATH);
DECLARE @SinRegla int;
SET @sql = N'SELECT s.Sede AS Sede_sin_regla_1062 FROM OPENJSON(@j) WITH (Sede nvarchar(10), Filtro nvarchar(100)) s
  WHERE NOT EXISTS (SELECT 1 FROM ' + @TR + N' r WHERE r.[Cód_ Concepto] = N''1062'' AND r.[Filtro Tipo Liq_] = N'''' AND r.[Filtro Proyecto] = s.Filtro);
  SET @n = @@ROWCOUNT;';
EXEC sp_executesql @sql, N'@j nvarchar(max), @n int OUTPUT', @SedeJson, @SinRegla OUTPUT;
IF @SinRegla > 0
BEGIN RAISERROR('Hay sedes sin regla del 1062 con el mismo filtro de proyecto: revisar antes de cargar las cargas.', 16, 1); ROLLBACK; RETURN; END;

IF EXISTS (SELECT 1 FROM (SELECT Contrib AS Cuenta FROM @Sede UNION SELECT @Pasivo) k
           WHERE NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$G_L Account$437dbf0e-84ff-417a-965d-ed2bb9650972] g WHERE g.[No_] = k.Cuenta))
BEGIN RAISERROR('Hay cuentas que no existen en el plan de cuentas.', 16, 1); ROLLBACK; RETURN; END;

SET @sql = N'INSERT ' + @TR + N' ([Cód_ Concepto],[Filtro Tipo Liq_],[Filtro Proyecto],[Cód_ Dimensión Filtro],[Filtro Valor Dimensión],
    [Cód_ Atributo Filtro],[Filtro Valor Atributo],[Vigencia Desde],[Descripción],[Cuenta Debe],[Cuenta Haber],[No Contabiliza],[Cód_ Atributo Cuenta],
    [Dimensión Cuenta],[Lado Atributo],[Provisión],[Conceptos Consumo],[Fórmula Valor Franco],[Precio por Puesto],[Sin Coef Pesquería],
    [Concepto Tasa Cargas],[Concepto Base Tasa])
  SELECT @cod, N'''', s.Filtro, N'''', N'''', N'''', N'''', @vig,
         LEFT(N''Cargas s/ francos: tasa CNT_SAC_DEV/4750 del lote. Pasivo A CONFIRMAR ('' + s.Sede + N'')'', 100),
         s.Contrib, @pas, 0, N'''', N'''', 0, 3, N'''', N'''', 0, 0, N''CNT_SAC_DEV'', N''4750''
  FROM OPENJSON(@j) WITH (Sede nvarchar(10), Filtro nvarchar(100), Contrib nvarchar(20)) s
  WHERE NOT EXISTS (SELECT 1 FROM ' + @TR + N' x WHERE x.[Cód_ Concepto] = @cod AND x.[Filtro Tipo Liq_] = N'''' AND x.[Filtro Proyecto] = s.Filtro
                    AND x.[Cód_ Dimensión Filtro] = N'''' AND x.[Cód_ Atributo Filtro] = N'''' AND x.[Vigencia Desde] = @vig);
  SELECT @@ROWCOUNT AS Reglas_cargas_creadas;
  SELECT [Filtro Proyecto], [Cuenta Debe], [Cuenta Haber], [Provisión], [Concepto Tasa Cargas], [Concepto Base Tasa] FROM ' + @TR + N'
  WHERE [Cód_ Concepto] = @cod ORDER BY [Filtro Proyecto];';
EXEC sp_executesql @sql, N'@j nvarchar(max), @cod nvarchar(20), @vig date, @pas nvarchar(20)', @SedeJson, @Concepto, @Vig, @Pasivo;

-- Un solo concepto con cada provisión de francos: la previa corta si hay dos.
DECLARE @Dobles int;
SET @sql = N'SELECT [Provisión], COUNT(DISTINCT [Cód_ Concepto]) AS Conceptos FROM ' + @TR + N' WHERE [Provisión] IN (2, 3) GROUP BY [Provisión];
  SELECT @n = COUNT(*) FROM (SELECT [Provisión] FROM ' + @TR + N' WHERE [Provisión] IN (2, 3)
    GROUP BY [Provisión] HAVING COUNT(DISTINCT [Cód_ Concepto]) > 1) x;';
EXEC sp_executesql @sql, N'@n int OUTPUT', @Dobles OUTPUT;
IF @Dobles > 0
BEGIN RAISERROR('Hay dos conceptos con la misma provisión de francos (2 o 3): la previa no abriría.', 16, 1); ROLLBACK; RETURN; END;

IF @Aplicar = 1 BEGIN COMMIT; PRINT 'Aplicado. Reiniciar el servicio de BC.'; END
ELSE BEGIN ROLLBACK; PRINT 'Prueba: se volvió todo atrás. Poner @Aplicar = 1 para confirmar.'; END;
