/* ASIENTO DE SUELDOS: PARAMETRIZACIÓN INICIAL EN ArbuTest (matriz concepto -> debe/haber, provisiones y conceptos nuevos del motor).
   Reemplaza lo que la interfaz de Meta4 (codeunit 50506 "Interfaz Meta4" de la extensión de NAV) tenía cableado: cada columna contable de
   M4T_ACUMULADO_RL4 (REM_PAG_TA, SDOS_JORN, CONTR_TA, CTA_SIN_A_PAG…) iba a una cuenta fija, y fntInsertarM4 la cambiaba según el proyecto.
   Acá cada concepto tiene su par de cuentas en Regla Asiento Liq., con una variante por sede. Detalle: Vault/04 Integraciones/Asiento de sueldos.md.

   QUÉ HACE
     1. Borra la versión de rubros ASI_ si quedó algo (nunca se aplicó: el script anterior siempre volvía atrás).
     2. Dos conceptos nuevos del motor, informativos, vigencia 2026-01-01:
        CRED_IVA_814  crédito fiscal IVA de las contribuciones (Dto. 814/01): base imponible de contribuciones por la alícuota del tramo
                      ZONA_DESFAV para el COD_ZONA del empleado. Es el CREDITO_IVA_ST de Meta4 ((5811+5821+5831) * ALI_CRED_IVA_ST / 100).
        CNT_SAC_DEV   contribuciones sobre el SAC devengado: el 4750 por las alícuotas patronales menos la del crédito IVA. Es el CNT_PROV_SAC
                      de Meta4 (PROV_SAC * (619+624+626+628+630+631+6090-627) / 100).
     3. Las reglas (sólo si la tabla ya existe: requiere publicar la extensión), una por concepto y sede.
     4. Genera Asiento = Sí en todos los tipos menos HIST_REMUN y SALDO_INICIAL (ya contabilizados en Meta4) y ANTICIPO (tesorería; Meta4
        también dejaba afuera el tp 4). También requiere publicar.
     5. Con @Simular = 1, arma el asiento de @Periodo en SQL con la misma matriz y lo muestra por cuenta. Los dos conceptos nuevos no tienen
        líneas hasta recalcular: la simulación los calcula con su fórmula sobre las líneas que ya hay.

   CÓMO SE CORRE
     @Aplicar = 0 (por defecto) hace todo y vuelve atrás. @Aplicar = 1 confirma. Después: reiniciar el servicio de BC (SQL directo deja la
     caché rancia). Es re-ejecutable: no pisa filas existentes.

   ROLLBACK
     DELETE de Regla Asiento Liq.; DELETE de Concepto Liquidación WHERE [Código] IN ('CRED_IVA_814','CNT_SAC_DEV');
     UPDATE Tipo Liquidación SET [Genera Asiento]=0. */
SET XACT_ABORT ON; SET NOCOUNT ON;
DECLARE @Aplicar bit = 0;
DECLARE @Simular bit = 1;
DECLARE @Periodo nvarchar(10) = N'202601';
DECLARE @Vig date = '20260101';

BEGIN TRAN;

/* ---------- 1. La versión de rubros ---------- */
DELETE dbo.[ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Acumulador] LIKE N'ASI[_]%';
DELETE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] LIKE N'ASI[_]%';

/* ---------- 2. Conceptos nuevos ----------
   Se copian de la fila 2026-01-01 de 4755 (informativo, mismos tipos de liquidación que el SAC devengado) y se pisan los campos propios.
   CRED_IVA_814: la base es la misma de la contribución jubilatoria (7000). La condición COD_ZONA > 0 deja afuera a quien no tiene zona;
   el tramo no tiene fila para la zona 01 (CABA), que no da crédito. Meta4 lo apagaba en anticipos (acá no corre en ese tipo) y para la
   categoría FA44.
   CNT_SAC_DEV: las alícuotas son fracciones (PCT_CONT_JUB = 0,1077); el tramo da porcentaje. Corre en el 944, después del 4750 (924) y antes
   del crédito (945). */
DECLARE @Nuevo TABLE (Codigo nvarchar(20) PRIMARY KEY, Descr nvarchar(100), Impresion nvarchar(100), Orden int, Devengo tinyint, Grupo int,
                      Condicion nvarchar(4000), Formula nvarchar(4000));
INSERT @Nuevo VALUES
 (N'CNT_SAC_DEV', N'Contribuciones s/ SAC devengado', N'Contrib. s/ SAC devengado', 944, 1, 2, N'',
  N'ROUND(#4750 * (PCT_CONT_JUB + PCT_ART + PCT_TAR_DIF + IF(ES_JUBILADO = 0, PCT_CONT_19032 + PCT_CONT_23660 + PCT_ASIG_FAMI + PCT_FNE, 0))'
  + N' - #4750 * IF(COD_ZONA > 0, TRAMO(''ZONA_DESFAV'', COD_ZONA), 0) / 100, PRECISION_REDONDEO)'),
 (N'CRED_IVA_814', N'Crédito fiscal IVA contribuciones (Dto. 814/01)', N'Crédito IVA Dto. 814', 945, 0, 0, N'COD_ZONA > 0',
  N'ROUND(IF(#CNT_APLICA = 1, #5811 + #5821 + #5831, MAX(0, BASE_SS_TRAB + BASE_SS_VAC + MES_BASE_SS_TRAB + MES_BASE_SS_VAC - DED_CONT_PATR)'
  + N' - MAX(0, MES_BASE_SS_TRAB + MES_BASE_SS_VAC - DED_CONT_PATR)) * TRAMO(''ZONA_DESFAV'', COD_ZONA) / 100, PRECISION_REDONDEO)');

DECLARE @TC nvarchar(300) = N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(CAST(QUOTENAME(c.name) AS nvarchar(max)), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@TC)
    AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%'
    AND c.name NOT IN (N'Código', N'Vigencia Desde', N'Descripción', N'Nombre Impresión', N'Tipo Concepto', N'Imprime en Recibo', N'Activo',
                       N'Es Acumulador', N'Vigencia Hasta', N'Orden Cálculo', N'Fórmula Orden Cálculo', N'Es Devengo', N'Grupo Costo Laboral', N'Condición',
                       N'Fórmula'));
DECLARE @sql nvarchar(max) = N'INSERT ' + @TC + N' (' + @cc + N',[Código],[Vigencia Desde],[Descripción],[Nombre Impresión],[Tipo Concepto],[Imprime en Recibo],'
  + N'[Activo],[Es Acumulador],[Vigencia Hasta],[Orden Cálculo],[Fórmula Orden Cálculo],[Es Devengo],[Grupo Costo Laboral],[Condición],[Fórmula],'
  + N'[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) '
  + N'SELECT ' + @cc + N',@cod,@vig,@des,@imp,6,0,1,0,''17530101'',@ord,CAST(@ord AS nvarchar(20)),@dev,@gru,@con,@for,NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'','
  + N'SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'' FROM ' + @TC + N' WHERE [Código] = N''4755'' AND [Vigencia Desde] = ''20260101''';
DECLARE @cod nvarchar(20), @des nvarchar(100), @imp nvarchar(100), @ord int, @dev tinyint, @gru int, @con nvarchar(4000), @for nvarchar(4000), @altasC int = 0;
DECLARE cn CURSOR LOCAL FAST_FORWARD FOR SELECT Codigo, Descr, Impresion, Orden, Devengo, Grupo, Condicion, Formula FROM @Nuevo n
  WHERE NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] x WHERE x.[Código] = n.Codigo);
OPEN cn; FETCH NEXT FROM cn INTO @cod, @des, @imp, @ord, @dev, @gru, @con, @for;
WHILE @@FETCH_STATUS = 0 BEGIN
  EXEC sp_executesql @sql, N'@cod nvarchar(20), @vig date, @des nvarchar(100), @imp nvarchar(100), @ord int, @dev tinyint, @gru int, @con nvarchar(4000), @for nvarchar(4000)',
       @cod, @Vig, @des, @imp, @ord, @dev, @gru, @con, @for;
  SET @altasC += @@ROWCOUNT;
  FETCH NEXT FROM cn INTO @cod, @des, @imp, @ord, @dev, @gru, @con, @for;
END;
CLOSE cn; DEALLOCATE cn;
SELECT @altasC AS Conceptos_creados;

/* ---------- 3. Sedes ----------
   Los tres proyectos que nombraba fntInsertarM4 (BAIRES, PTODDO, COMRIV) y la planta (ARB/PCR/PPM). MARDEL va con Buenos Aires y PTOMDY con
   Chubut (confirmado). Las otras PN-ADM-* van a las cuentas de buques con el neto de administración, como antes. Los filtros no se pisan:
   dos filtros de proyecto que coinciden con la misma liquidación serían una regla ambigua. */
DECLARE @Sede TABLE (Sede nvarchar(10) PRIMARY KEY, Filtro nvarchar(100), Sueldos nvarchar(20), Contrib nvarchar(20), Sac nvarchar(20), CsSac nvarchar(20),
                     Vac nvarchar(20), Neto nvarchar(20), Viajes nvarchar(20));
INSERT @Sede VALUES
 (N'GEN',  N'',                                                                   N'6110001', N'6110002', N'6110026', N'6110027', N'6110044', N'2112001', N'6110010'),
 (N'BA',   N'PN-ADM-BAIRES|PN-ADM-MARDEL',                                        N'6311001', N'6311002', N'6311023', N'6311026', N'6311024', N'2112003', N'6311006'),
 (N'SC',   N'PN-ADM-PTODDO',                                                      N'6312001', N'6312002', N'6312020', N'6312023', N'6312021', N'2112003', N'6312006'),
 (N'CH',   N'PN-ADM-COMRIV|PN-ADM-PTOMDY',                                        N'6313001', N'6313002', N'6313020', N'6313023', N'6313021', N'2112003', N'6313006'),
 (N'OADM', N'PN-ADM*&<>PN-ADM-BAIRES&<>PN-ADM-MARDEL&<>PN-ADM-PTODDO&<>PN-ADM-COMRIV&<>PN-ADM-PTOMDY',
                                                                                  N'6110001', N'6110002', N'6110026', N'6110027', N'6110044', N'2112003', N'6110010'),
 (N'PL',   N'PN-ARB*|PP-ARB*|PN-PCR*|PP-PCR*|PN-PPM*|PP-PPM*',                    N'6106001', N'6106002', N'6106003', N'6106004', N'6106012', N'2112011', N'6110010');

/* ---------- 4. Qué es cada concepto ---------- */
DECLARE @C TABLE (Codigo nvarchar(20) PRIMARY KEY, Tipo int, Dev tinyint, Descr nvarchar(100));
INSERT @C
SELECT c.[Código], c.[Tipo Concepto], c.[Es Devengo], c.[Descripción]
FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c
WHERE c.[Es Acumulador] = 0 AND c.[Vigencia Desde] = (
        SELECT MAX(c2.[Vigencia Desde]) FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c2
        WHERE c2.[Código] = c.[Código] AND c2.[Vigencia Desde] <= '20261231')
  AND (c.[Vigencia Hasta] = '17530101' OR c.[Vigencia Hasta] >= @Vig);

DECLARE @Lista TABLE (Codigo nvarchar(20), Clase nvarchar(20), Pasivo nvarchar(20), PRIMARY KEY (Codigo));
INSERT @Lista VALUES
 -- SAC liquidado: va al gasto de SAC contra el neto, y su pago cancela la provisión. El SAC sobre indemnizaciones no se provisiona: gasto
 -- de SAC del mes.
 (N'3613',N'SAC',N''),(N'3623',N'SAC',N''),(N'3813',N'SAC',N''),(N'3823',N'SAC',N''),(N'3814',N'SAC',N''),
 (N'2804',N'SAC',N''),(N'3904',N'SAC',N''),(N'3944',N'SAC',N''),(N'3974',N'SAC',N''),(N'3976',N'SAC',N''),
 -- Vacaciones pagadas: al gasto de vacaciones, que la provisión compensa.
 (N'3553',N'VAC',N''),(N'3573',N'VAC',N''),(N'3973',N'VAC',N''),(N'3975',N'VAC',N''),
 -- Provisiones: el asiento lleva la variación del saldo, no el importe.
 (N'4750',N'PROV_SAC',N'2112010'),(N'CNT_SAC_DEV',N'PROV_CNT_SAC',N'2113029'),(N'VAC_DEVENG',N'PROV_VAC',N'2112013'),
 (N'1062',N'PROV_FRANCOS',N'2112005'),
 (N'CRED_IVA_814',N'CRED_IVA',N'1115314'),
 -- Descuentos que bajan el sueldo y no son una deuda con un tercero.
 (N'4121',N'BAJA',N''),(N'4140',N'BAJA',N''),(N'4723',N'BAJA',N''),
 -- Descuento -> su pasivo (o el gasto que recupera).
 (N'8522',N'SIND',N'2113003'),(N'8523',N'SIND',N'2113003'),(N'8525',N'SIND',N'2113003'),(N'8542',N'SIND',N'2113003'),(N'8543',N'SIND',N'2113003'),
 (N'8553',N'SIND',N'2113003'),(N'8563',N'SIND',N'2113003'),(N'8573',N'SIND',N'2113003'),(N'8593',N'SIND',N'2113003'),(N'8603',N'SIND',N'2113003'),
 (N'5010',N'DESC',N'2115006'),(N'5020',N'DESC',N'2115006'),(N'5310',N'DESC',N'2115006'),
 (N'8883',N'DESC',N'2113004'),(N'8893',N'DESC',N'2113002'),
 (N'8810',N'DESC',N'1115204'),(N'8830',N'DESC',N'1115204'),(N'8835',N'DESC',N'1115204'),(N'8840',N'DESC',N'1115204'),(N'8850',N'DESC',N'1115204'),
 (N'8860',N'DESC',N'1115204'),(N'8870',N'DESC',N'1115205'),
 (N'8623',N'VIAJES',N''),(N'8643',N'VIAJES',N''),(N'8633',N'DESC',N'6110006'),(N'8653',N'DESC',N'6110006'),
 (N'8693',N'DESC',N'6110011'),(N'8683',N'DESC',N'6110025'),(N'8703',N'DESC',N'6110025'),
 -- Mapeados y sin asiento: el anticipo vive en su propia liquidación (ti=4); 2704 es el crédito viejo sobre el básico, reemplazado por
 -- CRED_IVA_814; las contribuciones sindicales sobre el SAC devengado quedan para cuando se provisionen.
 (N'4813',N'NOCONT',N''),(N'2704',N'NOCONT',N''),(N'4755',N'NOCONT',N''),(N'4756',N'NOCONT',N''),(N'4757',N'NOCONT',N''),
 (N'FRANCO_DEVENG',N'NOCONT',N'');
-- Contribuciones que se pagan con el F.931 (SUSS). El resto (sindicales y de farmacia patronales, ley 3270, INACAP) va a otras.
DECLARE @Suss TABLE (Codigo nvarchar(20) PRIMARY KEY);
INSERT @Suss VALUES (N'7000'),(N'7002'),(N'7010'),(N'7030'),(N'7050'),(N'7053'),(N'7055'),(N'7060'),(N'7070'),(N'7080');

DECLARE @Clase TABLE (Codigo nvarchar(20) PRIMARY KEY, Clase nvarchar(20), Pasivo nvarchar(20));
INSERT @Clase
SELECT c.Codigo,
       COALESCE(l.Clase,
         CASE WHEN c.Tipo IN (0,1) AND c.Dev = 0 THEN N'HABER'
              WHEN c.Tipo IN (2,4,5) AND c.Dev = 1 THEN N'NOCONT'          -- retenciones sobre el SAC devengado
              WHEN c.Tipo = 5 THEN N'APORTE'
              WHEN c.Tipo = 3 AND c.Dev = 0 THEN N'CONTRIB' END),
       COALESCE(NULLIF(l.Pasivo, N''), CASE WHEN c.Tipo = 3 THEN CASE WHEN s.Codigo IS NULL THEN N'2113005' ELSE N'2113001' END END, N'')
FROM @C c LEFT JOIN @Lista l ON l.Codigo = c.Codigo LEFT JOIN @Suss s ON s.Codigo = c.Codigo
WHERE COALESCE(l.Clase,
         CASE WHEN c.Tipo IN (0,1) AND c.Dev = 0 THEN N'HABER' WHEN c.Tipo IN (2,4,5) AND c.Dev = 1 THEN N'NOCONT'
              WHEN c.Tipo = 5 THEN N'APORTE' WHEN c.Tipo = 3 AND c.Dev = 0 THEN N'CONTRIB' END) IS NOT NULL;
-- Los dos conceptos nuevos todavía no existen en @C si el script corre por primera vez dentro de esta transacción: ya se insertaron arriba,
-- así que @C los trae. Si @Lista nombra un concepto que no existe, se avisa.
SELECT l.Codigo AS En_lista_y_no_existe FROM @Lista l WHERE NOT EXISTS (SELECT 1 FROM @C c WHERE c.Codigo = l.Codigo);

/* ---------- 5. Reglas ---------- */
DECLARE @Regla TABLE (Concepto nvarchar(20), FiltroTipo nvarchar(80), Sede nvarchar(10), FiltroProy nvarchar(100), Debe nvarchar(20), Haber nvarchar(20),
                      NoCont tinyint, AtrCta nvarchar(20), DimCta nvarchar(20), LadoAtr int, Prov int, Consumo nvarchar(250), Descr nvarchar(100),
                      PRIMARY KEY (Concepto, FiltroTipo, Sede));
DECLARE @ConsumoSac nvarchar(250) = N'3613|3623|3813|3823|3814';
DECLARE @ConsumoVac nvarchar(250) = N'3553|3573|3973|3975';

INSERT @Regla
SELECT k.Codigo, N'', s.Sede, s.Filtro,
       CASE k.Clase WHEN N'HABER' THEN s.Sueldos WHEN N'SAC' THEN s.Sac WHEN N'VAC' THEN s.Vac
                    WHEN N'PROV_SAC' THEN s.Sac WHEN N'PROV_CNT_SAC' THEN s.CsSac WHEN N'PROV_VAC' THEN s.Vac WHEN N'PROV_FRANCOS' THEN s.Sueldos
                    WHEN N'CRED_IVA' THEN k.Pasivo WHEN N'CONTRIB' THEN s.Contrib WHEN N'NOCONT' THEN N''
                    ELSE s.Neto END,                                           -- APORTE, DESC, SIND, VIAJES, BAJA: debitan el neto
       CASE k.Clase WHEN N'HABER' THEN s.Neto WHEN N'SAC' THEN s.Neto WHEN N'VAC' THEN s.Neto
                    WHEN N'PROV_SAC' THEN k.Pasivo WHEN N'PROV_CNT_SAC' THEN k.Pasivo WHEN N'PROV_VAC' THEN k.Pasivo WHEN N'PROV_FRANCOS' THEN k.Pasivo
                    WHEN N'CRED_IVA' THEN s.Contrib WHEN N'CONTRIB' THEN k.Pasivo WHEN N'APORTE' THEN N'2113001'
                    WHEN N'VIAJES' THEN s.Viajes WHEN N'BAJA' THEN s.Sueldos WHEN N'NOCONT' THEN N''
                    ELSE k.Pasivo END,
       CASE WHEN k.Clase = N'NOCONT' THEN 1 ELSE 0 END,
       CASE WHEN k.Clase = N'SIND' THEN N'SINDICATO' ELSE N'' END,
       CASE WHEN k.Clase = N'SIND' THEN N'SINDICATOS' ELSE N'' END,
       CASE WHEN k.Clase = N'SIND' THEN 1 ELSE 0 END,
       CASE WHEN k.Clase IN (N'PROV_SAC', N'PROV_CNT_SAC', N'PROV_VAC') THEN 1 WHEN k.Clase = N'PROV_FRANCOS' THEN 2 ELSE 0 END,
       CASE WHEN k.Clase IN (N'PROV_SAC', N'PROV_CNT_SAC') THEN @ConsumoSac WHEN k.Clase = N'PROV_VAC' THEN @ConsumoVac ELSE N'' END,
       LEFT(CASE k.Clase WHEN N'HABER' THEN N'Haber: gasto contra el neto' WHEN N'SAC' THEN N'SAC liquidado: gasto de SAC contra el neto'
                         WHEN N'VAC' THEN N'Vacaciones pagadas: gasto de vacaciones contra el neto'
                         WHEN N'PROV_SAC' THEN N'Provisión SAC: devengado hasta liquidar; el pago lo revierte'
                         WHEN N'PROV_CNT_SAC' THEN N'Provisión cargas s/ SAC: devengado hasta liquidar; el pago lo revierte'
                         WHEN N'PROV_VAC' THEN N'Provisión vacaciones: devengado hasta liquidar; el pago lo revierte'
                         WHEN N'PROV_FRANCOS' THEN N'Provisión francos: lotes al valor de devengo, revertidos al liquidar. Pasivo A CONFIRMAR'
                         WHEN N'CRED_IVA' THEN N'Crédito IVA Dto. 814: baja las cargas sociales'
                         WHEN N'CONTRIB' THEN N'Contribución: cargas sociales contra su pasivo'
                         WHEN N'APORTE' THEN N'Aporte: baja el neto contra el SUSS'
                         WHEN N'SIND' THEN N'Cuota sindical: cuenta del sindicato por dimensión'
                         WHEN N'VIAJES' THEN N'Recupero de gastos de viaje'
                         WHEN N'BAJA' THEN N'Descuento que baja el sueldo'
                         WHEN N'NOCONT' THEN N'Mapeado: no contabiliza'
                         ELSE N'Descuento: baja el neto contra su pasivo' END + N' (' + s.Sede + N')', 100)
FROM @Clase k CROSS JOIN @Sede s
-- Lo que no depende de la sede va una sola vez, en la genérica.
WHERE s.Sede = N'GEN' OR k.Clase <> N'NOCONT';

-- Contribuciones del aguinaldo: a cargas sociales del SAC, para que el SAC liquidado quede en resultado con sus cargas.
INSERT @Regla
SELECT r.Concepto, N'AGUINALDO', r.Sede, r.FiltroProy, s.CsSac, r.Haber, 0, N'', N'', 0, 0, N'',
       LEFT(N'Contribución del aguinaldo: cargas sociales s/ SAC (' + r.Sede + N')', 100)
FROM @Regla r JOIN @Clase k ON k.Codigo = r.Concepto AND k.Clase = N'CONTRIB' JOIN @Sede s ON s.Sede = r.Sede
WHERE r.FiltroTipo = N'';

SELECT COUNT(*) AS Reglas, COUNT(DISTINCT Concepto) AS Conceptos FROM @Regla;

/* ---------- Controles antes de escribir ---------- */
DECLARE @Ctas TABLE (Cuenta nvarchar(20) PRIMARY KEY);
INSERT @Ctas SELECT DISTINCT x.Cuenta FROM (SELECT Debe AS Cuenta FROM @Regla UNION SELECT Haber FROM @Regla) x WHERE x.Cuenta <> N'';
IF EXISTS (SELECT 1 FROM @Ctas k WHERE NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$G_L Account$437dbf0e-84ff-417a-965d-ed2bb9650972] g WHERE g.[No_] = k.Cuenta))
BEGIN SELECT k.Cuenta AS Cuenta_inexistente FROM @Ctas k WHERE NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$G_L Account$437dbf0e-84ff-417a-965d-ed2bb9650972] g WHERE g.[No_] = k.Cuenta);
      RAISERROR('Hay cuentas que no existen en el plan de cuentas.', 16, 1); ROLLBACK; RETURN; END;
IF EXISTS (SELECT 1 FROM @Regla WHERE NoCont = 0 AND (Debe = N'' OR (Haber = N'' AND AtrCta = N'')))
BEGIN SELECT * FROM @Regla WHERE NoCont = 0 AND (Debe = N'' OR (Haber = N'' AND AtrCta = N''));
      RAISERROR('Hay reglas sin cuenta de un lado.', 16, 1); ROLLBACK; RETURN; END;
-- Lo que queda sin regla (para revisar, no frena).
SELECT c.Codigo, c.Tipo, c.Dev, c.Descr AS SinRegla_Revisar FROM @C c
WHERE c.Tipo <> 6 AND NOT EXISTS (SELECT 1 FROM @Clase k WHERE k.Codigo = c.Codigo) ORDER BY c.Tipo, c.Codigo;

/* ---------- 6. Simulación del período ----------
   Misma matriz, resuelta por sede y tipo de liquidación en vez de por filtro: la sede de cada proyecto sale del mismo CASE que los filtros. */
IF @Simular = 1
BEGIN
  DECLARE @Tipos TABLE (Tipo nvarchar(20) PRIMARY KEY);
  INSERT @Tipos SELECT [Código] FROM dbo.[ArbuTest$Tipo Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
  WHERE [Código] NOT IN (N'HIST_REMUN', N'SALDO_INICIAL', N'ANTICIPO');
  DECLARE @Liq TABLE (NoLiq nvarchar(20) PRIMARY KEY, Emp nvarchar(20), Tipo nvarchar(20), Proy nvarchar(20), Fecha date, Sede nvarchar(10));
  INSERT @Liq
  SELECT l.[No_], l.[No_ Empleado], l.[Cód_ Tipo Liq_], l.[No_ Proyecto], l.[Fecha Liquidación],
         CASE WHEN l.[No_ Proyecto] IN (N'PN-ADM-BAIRES', N'PN-ADM-MARDEL') THEN N'BA' WHEN l.[No_ Proyecto] = N'PN-ADM-PTODDO' THEN N'SC'
              WHEN l.[No_ Proyecto] IN (N'PN-ADM-COMRIV', N'PN-ADM-PTOMDY') THEN N'CH' WHEN l.[No_ Proyecto] LIKE N'PN-ADM%' THEN N'OADM'
              WHEN l.[No_ Proyecto] LIKE N'PN-ARB%' OR l.[No_ Proyecto] LIKE N'PP-ARB%' OR l.[No_ Proyecto] LIKE N'PN-PCR%' OR l.[No_ Proyecto] LIKE N'PP-PCR%'
                OR l.[No_ Proyecto] LIKE N'PN-PPM%' OR l.[No_ Proyecto] LIKE N'PP-PPM%' THEN N'PL' ELSE N'GEN' END
  FROM dbo.[ArbuTest$Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] l JOIN @Tipos t ON t.Tipo = l.[Cód_ Tipo Liq_]
  WHERE l.[Cód_ Período] = @Periodo AND l.Estado IN (1,2,3);

  -- Las líneas del período, más las de los dos conceptos nuevos calculadas con su fórmula (todavía no hay líneas suyas).
  DECLARE @Lin TABLE (NoLiq nvarchar(20), Concepto nvarchar(20), Importe decimal(38,4));
  INSERT @Lin SELECT ln.[No_ Liquidación], ln.[Cód_ Concepto], ln.Importe
  FROM dbo.[ArbuTest$Línea Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ln JOIN @Liq q ON q.NoLiq = ln.[No_ Liquidación]
  WHERE ln.Importe <> 0 AND ln.[Cód_ Concepto] NOT IN (N'CRED_IVA_814', N'CNT_SAC_DEV');
  -- La zona es la que va a ver un recálculo: el atributo ZONA_DESFAVORABLE vigente a la fecha de la liquidación y, si no hay, la que
  -- usó el cálculo (la del proyecto o la ficha).
  DECLARE @Zona TABLE (NoLiq nvarchar(20) PRIMARY KEY, Ali decimal(9,4), Jub int);
  INSERT @Zona SELECT q.NoLiq,
         ISNULL((SELECT TOP 1 d.[Monto Fijo] FROM dbo.[ArbuTest$Tabla Escalonada Det_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] d
                 WHERE d.[Código] = N'ZONA_DESFAV' AND COALESCE(
                     (SELECT TOP 1 a.[Valor Numérico] FROM dbo.[ArbuTest$Atributo Entidad Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] a
                       WHERE a.[Tipo Entidad] = 0 AND a.[Cód_ Entidad] = q.Emp AND a.[Cód_ Tipo Atributo] = N'ZONA_DESFAVORABLE'
                         AND a.[Vigencia Desde] <= q.Fecha AND (a.[Vigencia Hasta] = '17530101' OR a.[Vigencia Hasta] >= q.Fecha)
                       ORDER BY a.[Vigencia Desde] DESC), TRY_CAST(r.[Valor] AS decimal(9,2)))
                   BETWEEN d.[Límite Inferior] AND d.[Límite Superior] ORDER BY d.[Vigencia Desde] DESC), 0),
         ISNULL((SELECT CAST(MAX(j.[Valor]) AS int) FROM dbo.[ArbuTest$Resumen Variable Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] j WHERE j.[No_ Liquidación] = q.NoLiq AND j.[Nombre Variable] = N'ES_JUBILADO'), 0)
  FROM @Liq q LEFT JOIN dbo.[ArbuTest$Resumen Variable Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] r ON r.[No_ Liquidación] = q.NoLiq AND r.[Nombre Variable] = N'COD_ZONA';
  -- La base es la del 7000: 5811+5821+5831 si CNT_APLICA = 1; si no, la otra rama de su fórmula, que se recupera del propio 7000.
  INSERT @Lin SELECT z.NoLiq, N'CRED_IVA_814',
         ROUND(CASE WHEN EXISTS (SELECT 1 FROM @Lin a WHERE a.NoLiq = z.NoLiq AND a.Concepto = N'CNT_APLICA' AND a.Importe = 1)
                    THEN (SELECT SUM(b.Importe) FROM @Lin b WHERE b.NoLiq = z.NoLiq AND b.Concepto IN (N'5811', N'5821', N'5831'))
                    ELSE (SELECT SUM(b.Importe) FROM @Lin b WHERE b.NoLiq = z.NoLiq AND b.Concepto = N'7000') / 0.1077 END * z.Ali / 100, 2)
  FROM @Zona z WHERE z.Ali <> 0;
  DELETE @Lin WHERE Concepto = N'CRED_IVA_814' AND ISNULL(Importe, 0) = 0;
  -- Las alícuotas patronales al valor de 2026 (PCT_CONT_JUB 0,1077, PCT_ART 0,074, 19032 0,0159, 23660 0,06, asig. fam. 0,047,
  -- FNE 0,0094); PCT_TAR_DIF es por convenio (2 % en los de la tripulación) y se lee del parámetro con el convenio de la línea.
  INSERT @Lin SELECT z.NoLiq, N'CNT_SAC_DEV', ROUND(l.Importe * (0.1077 + 0.074
           + ISNULL((SELECT TOP 1 p.Valor FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] p
                     WHERE p.[Cód_ Parámetro] = N'PCT_TAR_DIF_' + ln.[Cód_ Convenio] AND p.[Vigencia Desde] <= '20261231' ORDER BY p.[Vigencia Desde] DESC), 0)
           + CASE WHEN z.Jub = 0 THEN 0.0159 + 0.06 + 0.047 + 0.0094 ELSE 0 END) - l.Importe * z.Ali / 100, 2)
  FROM @Zona z JOIN @Lin l ON l.NoLiq = z.NoLiq AND l.Concepto = N'4750'
  CROSS APPLY (SELECT TOP 1 x.[Cód_ Convenio] FROM dbo.[ArbuTest$Línea Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] x
               WHERE x.[No_ Liquidación] = z.NoLiq AND x.[Cód_ Concepto] = N'4750') ln;

  DECLARE @Mov TABLE (Cuenta nvarchar(20), NoLiq nvarchar(20), Concepto nvarchar(30), Importe decimal(38,4));
  -- Líneas que no son provisión.
  INSERT @Mov SELECT r.Debe, l.NoLiq, l.Concepto, l.Importe FROM @Lin l JOIN @Liq q ON q.NoLiq = l.NoLiq
    JOIN @Regla r ON r.Concepto = l.Concepto AND r.Sede = CASE WHEN EXISTS (SELECT 1 FROM @Regla r2 WHERE r2.Concepto = l.Concepto AND r2.Sede = q.Sede) THEN q.Sede ELSE N'GEN' END
     AND r.FiltroTipo = CASE WHEN EXISTS (SELECT 1 FROM @Regla r3 WHERE r3.Concepto = l.Concepto AND r3.FiltroTipo = q.Tipo) THEN q.Tipo ELSE N'' END
    WHERE r.NoCont = 0 AND r.Prov = 0;
  INSERT @Mov SELECT CASE WHEN r.AtrCta = N'' THEN r.Haber ELSE ISNULL(
      (SELECT TOP 1 dd.[No_] FROM dbo.[ArbuTest$Default Dimension$437dbf0e-84ff-417a-965d-ed2bb9650972] dd
        WHERE dd.[Table ID] = 15 AND dd.[Dimension Code] = r.DimCta AND dd.[Dimension Value Code] =
          (SELECT TOP 1 a.[Cód_ Valor] FROM dbo.[ArbuTest$Atributo Entidad Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] a
            WHERE a.[Tipo Entidad] = 0 AND a.[Cód_ Entidad] = q.Emp AND a.[Cód_ Tipo Atributo] = r.AtrCta AND a.[Vigencia Desde] <= q.Fecha
              AND (a.[Vigencia Hasta] = '17530101' OR a.[Vigencia Hasta] >= q.Fecha) ORDER BY a.[Vigencia Desde] DESC)
        ORDER BY dd.[No_]), r.Haber) END,
      l.NoLiq, l.Concepto, -l.Importe FROM @Lin l JOIN @Liq q ON q.NoLiq = l.NoLiq
    JOIN @Regla r ON r.Concepto = l.Concepto AND r.Sede = CASE WHEN EXISTS (SELECT 1 FROM @Regla r2 WHERE r2.Concepto = l.Concepto AND r2.Sede = q.Sede) THEN q.Sede ELSE N'GEN' END
     AND r.FiltroTipo = CASE WHEN EXISTS (SELECT 1 FROM @Regla r3 WHERE r3.Concepto = l.Concepto AND r3.FiltroTipo = q.Tipo) THEN q.Tipo ELSE N'' END
    WHERE r.NoCont = 0 AND r.Prov = 0;

  -- Provisiones por conceptos: se registra el devengado hasta liquidar; el período en que un concepto que la liquida paga algo la
  -- revierte entera. Como el codeunit, por partida: cada línea de devengado con su liquidación. La simulación es del PRIMER período con
  -- liquidaciones que contabilizan (202601): no hay partidas abiertas de antes que revertir. Para un período posterior, el codeunit.
  IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] l JOIN @Tipos t ON t.Tipo = l.[Cód_ Tipo Liq_]
             WHERE l.[Cód_ Período] < @Periodo AND l.Estado IN (1,2,3))
    PRINT 'OJO: hay períodos anteriores con liquidaciones que contabilizan; la simulación de provisiones no revierte sus partidas abiertas.';
  DECLARE @Prov TABLE (Emp nvarchar(20), Concepto nvarchar(20), Saldo decimal(38,4), NoLiq nvarchar(20));
  INSERT @Prov
  SELECT q.Emp, r.Concepto, l.Importe, l.NoLiq
  FROM @Lin l JOIN @Liq q ON q.NoLiq = l.NoLiq JOIN (SELECT DISTINCT Concepto, Consumo FROM @Regla WHERE Prov = 1) r ON r.Concepto = l.Concepto
  WHERE NOT EXISTS (SELECT 1 FROM @Lin c JOIN @Liq qc ON qc.NoLiq = c.NoLiq WHERE qc.Emp = q.Emp
                      AND (N'|' + r.Consumo + N'|') LIKE N'%|' + c.Concepto + N'|%');

  -- Francos: días que le quedan a cada lote de la fase vigente, al valor del día de la liquidación que lo originó (VALOR_FRANCO_DIA ×
  -- COEF_PESQUERIA); si no lo tiene, el del empleado a esa fecha. Variación = saldo al cierre menos saldo al cierre anterior. En el primer
  -- período, el saldo anterior (los lotes del saldo inicial) no es gasto del mes: sale aparte, para asentarlo una vez.
  -- OJO: ES UNA APROXIMACIÓN. Desde la 1.0.0.709 el codeunit valoriza cada lote por su terna (Gestión Francos.ValuarMatriz con el par de
  -- la liquidación de origen, a la fecha del lote, por su COEF_PESQUERIA), como el 1063, y no por la VALOR_FRANCO_DIA guardada, que sólo
  -- existe donde algo la usa: después de recalcular enero esta simulación deja 56 días sin valor que la previa sí valoriza. Para los
  -- francos, la referencia es la previa (DiagnosticarPreviaJson).
  DECLARE @FHasta date = (SELECT [Fecha Hasta] FROM dbo.[ArbuTest$Período Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] = @Periodo);
  DECLARE @FAntes date = DATEADD(day, -1, (SELECT [Fecha Desde] FROM dbo.[ArbuTest$Período Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] = @Periodo));
  IF OBJECT_ID('tempdb..#Lote') IS NOT NULL DROP TABLE #Lote;
  SELECT d.[No_ Movimiento] AS Lote, d.[No_ Empleado] AS Emp, d.[Fecha Devengamiento] AS Fecha, d.[No_ Liquidación] AS LiqOrigen,
         (SELECT SUM(m.Cantidad) FROM dbo.[ArbuTest$Movimiento Franco Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] m WHERE m.[No_ Lote] = d.[No_ Movimiento] AND m.[Fecha Devengamiento] <= @FHasta) AS DiasAhora,
         (SELECT SUM(m.Cantidad) FROM dbo.[ArbuTest$Movimiento Franco Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] m WHERE m.[No_ Lote] = d.[No_ Movimiento] AND m.[Fecha Devengamiento] <= @FAntes) AS DiasAntes,
         CAST(0 AS decimal(38,6)) AS Valor
  INTO #Lote
  FROM dbo.[ArbuTest$Movimiento Franco Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] d
  WHERE d.Tipo = 0 AND d.[Fecha Devengamiento] <= @FHasta;
  -- La fase vigente a cada fecha; sin fase vigente (después de la baja) ningún lote cuenta.
  UPDATE l SET DiasAhora = CASE WHEN fa.Alta IS NOT NULL AND l.Fecha >= fa.Alta AND l.DiasAhora > 0 THEN l.DiasAhora ELSE 0 END,
               DiasAntes = CASE WHEN fb.Alta IS NOT NULL AND l.Fecha >= fb.Alta AND l.DiasAntes > 0 THEN l.DiasAntes ELSE 0 END
  FROM #Lote l
  OUTER APPLY (SELECT TOP 1 CASE WHEN f.[Fecha Baja] = '17530101' OR f.[Fecha Baja] > @FHasta THEN f.[Fecha Alta] END AS Alta
               FROM dbo.[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f WHERE f.[No_ Empleado] = l.Emp AND f.[Fecha Alta] <= @FHasta ORDER BY f.[Fecha Alta] DESC) fa
  OUTER APPLY (SELECT TOP 1 CASE WHEN f.[Fecha Baja] = '17530101' OR f.[Fecha Baja] > @FAntes THEN f.[Fecha Alta] END AS Alta
               FROM dbo.[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f WHERE f.[No_ Empleado] = l.Emp AND f.[Fecha Alta] <= @FAntes ORDER BY f.[Fecha Alta] DESC) fb;
  DELETE #Lote WHERE ISNULL(DiasAhora, 0) = 0 AND ISNULL(DiasAntes, 0) = 0;
  -- Valor por día de una liquidación.
  IF OBJECT_ID('tempdb..#ValLiq') IS NOT NULL DROP TABLE #ValLiq;
  SELECT r.[No_ Liquidación] AS NoLiq, lq.[No_ Empleado] AS Emp, lq.[Fecha Liquidación] AS Fecha,
         r.Valor * ISNULL(NULLIF((SELECT TOP 1 c.Importe FROM dbo.[ArbuTest$Línea Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c
                                  WHERE c.[No_ Liquidación] = r.[No_ Liquidación] AND c.[Cód_ Concepto] = N'COEF_PESQUERIA'), 0), 1) AS Valor
  INTO #ValLiq
  FROM dbo.[ArbuTest$Resumen Variable Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] r
  JOIN dbo.[ArbuTest$Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] lq ON lq.[No_] = r.[No_ Liquidación] AND lq.Estado IN (1,2,3)
  WHERE r.[Nombre Variable] = N'VALOR_FRANCO_DIA' AND r.Valor <> 0;
  UPDATE l SET Valor = COALESCE(o.Valor,
           (SELECT TOP 1 v.Valor FROM #ValLiq v WHERE v.Emp = l.Emp AND v.Fecha <= l.Fecha ORDER BY v.Fecha DESC),
           (SELECT TOP 1 v.Valor FROM #ValLiq v WHERE v.Emp = l.Emp AND v.Fecha > l.Fecha ORDER BY v.Fecha), 0)
  FROM #Lote l LEFT JOIN #ValLiq o ON o.NoLiq = l.LiqOrigen;
  SELECT CAST(SUM(DiasAhora) AS decimal(18,2)) AS Francos_dias_al_cierre, CAST(SUM(DiasAntes) AS decimal(18,2)) AS Francos_dias_al_cierre_anterior,
         CAST(SUM(CASE WHEN Valor = 0 THEN DiasAhora ELSE 0 END) AS decimal(18,2)) AS Dias_sin_valor,
         CAST(SUM(DiasAntes * Valor) AS decimal(18,2)) AS Saldo_inicial_aparte
  FROM #Lote;
  -- Cada lote con su liquidación de origen, como el codeunit; si el origen no existe o es de un tipo que no contabiliza (saldo inicial),
  -- con la última liquidación del empleado hasta el cierre.
  INSERT @Prov
  SELECT l.Emp, N'1062', (l.DiasAhora - l.DiasAntes) * l.Valor,
         CASE WHEN EXISTS (SELECT 1 FROM dbo.[ArbuTest$Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] o JOIN @Tipos t ON t.Tipo = o.[Cód_ Tipo Liq_]
                           WHERE o.[No_] = l.LiqOrigen) THEN l.LiqOrigen
              ELSE (SELECT TOP 1 lq.[No_] FROM dbo.[ArbuTest$Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] lq JOIN @Tipos t ON t.Tipo = lq.[Cód_ Tipo Liq_]
                    WHERE lq.[No_ Empleado] = l.Emp AND lq.[Fecha Liquidación] <= @FHasta AND lq.Estado IN (1,2,3)
                    ORDER BY lq.[Cód_ Período] DESC, lq.[No_ Empleado], lq.[No_] DESC) END
  FROM #Lote l WHERE l.Valor <> 0 AND l.DiasAhora <> l.DiasAntes;
  -- La sede de esas liquidaciones (pueden ser de otro período: no están en @Liq).
  DECLARE @SedeLiq TABLE (NoLiq nvarchar(20) PRIMARY KEY, Sede nvarchar(10));
  INSERT @SedeLiq SELECT DISTINCT p.NoLiq,
         CASE WHEN lq.[No_ Proyecto] IN (N'PN-ADM-BAIRES', N'PN-ADM-MARDEL') THEN N'BA' WHEN lq.[No_ Proyecto] = N'PN-ADM-PTODDO' THEN N'SC'
              WHEN lq.[No_ Proyecto] IN (N'PN-ADM-COMRIV', N'PN-ADM-PTOMDY') THEN N'CH' WHEN lq.[No_ Proyecto] LIKE N'PN-ADM%' THEN N'OADM'
              WHEN lq.[No_ Proyecto] LIKE N'PN-ARB%' OR lq.[No_ Proyecto] LIKE N'PP-ARB%' OR lq.[No_ Proyecto] LIKE N'PN-PCR%' OR lq.[No_ Proyecto] LIKE N'PP-PCR%'
                OR lq.[No_ Proyecto] LIKE N'PN-PPM%' OR lq.[No_ Proyecto] LIKE N'PP-PPM%' THEN N'PL' ELSE N'GEN' END
  FROM @Prov p JOIN dbo.[ArbuTest$Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] lq ON lq.[No_] = p.NoLiq;

  INSERT @Mov SELECT r.Debe, p.NoLiq, N'PROV:' + p.Concepto, p.Saldo FROM @Prov p JOIN @SedeLiq q ON q.NoLiq = p.NoLiq
    JOIN @Regla r ON r.Concepto = p.Concepto AND r.FiltroTipo = N'' AND r.Sede = q.Sede WHERE ROUND(p.Saldo, 2) <> 0;
  INSERT @Mov SELECT r.Haber, p.NoLiq, N'PROV:' + p.Concepto, -p.Saldo FROM @Prov p JOIN @SedeLiq q ON q.NoLiq = p.NoLiq
    JOIN @Regla r ON r.Concepto = p.Concepto AND r.FiltroTipo = N'' AND r.Sede = q.Sede WHERE ROUND(p.Saldo, 2) <> 0;

  -- Lo que no tiene regla.
  SELECT l.Concepto AS Sin_regla, COUNT(*) AS Lineas, SUM(l.Importe) AS Importe FROM @Lin l
  WHERE NOT EXISTS (SELECT 1 FROM @Regla r WHERE r.Concepto = l.Concepto)
    AND NOT EXISTS (SELECT 1 FROM @C c WHERE c.Codigo = l.Concepto AND c.Tipo = 6)
    AND l.Concepto IN (SELECT Codigo FROM @C)
  GROUP BY l.Concepto ORDER BY l.Concepto;

  SELECT m.Cuenta, g.Name, CAST(SUM(CASE WHEN m.Importe > 0 THEN m.Importe ELSE 0 END) AS decimal(18,2)) AS Debe,
         CAST(SUM(CASE WHEN m.Importe < 0 THEN -m.Importe ELSE 0 END) AS decimal(18,2)) AS Haber, CAST(SUM(m.Importe) AS decimal(18,2)) AS Saldo
  FROM @Mov m LEFT JOIN dbo.[ArbuTest$G_L Account$437dbf0e-84ff-417a-965d-ed2bb9650972] g ON g.[No_] = m.Cuenta
  GROUP BY m.Cuenta, g.Name ORDER BY m.Cuenta;
  SELECT COUNT(DISTINCT NoLiq) AS Liquidaciones, CAST(SUM(CASE WHEN Importe > 0 THEN Importe ELSE 0 END) AS decimal(18,2)) AS Debe,
         CAST(SUM(CASE WHEN Importe < 0 THEN -Importe ELSE 0 END) AS decimal(18,2)) AS Haber FROM @Mov;
  SELECT p.Concepto AS Provision, COUNT(*) AS Empleados, CAST(SUM(p.Saldo) AS decimal(18,2)) AS Variacion FROM @Prov p GROUP BY p.Concepto;
END;

/* ---------- 7. Escritura ----------
   Lo que necesita la extensión publicada se escribe con SQL dinámico para que el script compile aunque la tabla no exista. */
DECLARE @TR nvarchar(300) = N'dbo.[ArbuTest$Regla Asiento Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
IF OBJECT_ID(@TR) IS NULL
  PRINT 'Regla Asiento Liq. todavía no existe: publicar la extensión y volver a correr el script para cargar las reglas.';
ELSE BEGIN
  DECLARE @json nvarchar(max) = (SELECT * FROM @Regla FOR JSON PATH, INCLUDE_NULL_VALUES);
  SET @sql = CAST(N'INSERT ' AS nvarchar(max)) + @TR + N' ([Cód_ Concepto],[Filtro Tipo Liq_],[Filtro Proyecto],[Cód_ Dimensión Filtro],[Filtro Valor Dimensión],'
    + N'[Cód_ Atributo Filtro],[Filtro Valor Atributo],[Vigencia Desde],[Descripción],[Cuenta Debe],[Cuenta Haber],[No Contabiliza],[Cód_ Atributo Cuenta],'
    + N'[Dimensión Cuenta],[Lado Atributo],[Provisión],[Conceptos Consumo]) '
    + N'SELECT j.Concepto, j.FiltroTipo, j.FiltroProy, N'''', N'''', N'''', N'''', @vig, j.Descr, j.Debe, j.Haber, j.NoCont, j.AtrCta, j.DimCta, j.LadoAtr, j.Prov, j.Consumo '
    + N'FROM OPENJSON(@json) WITH (Concepto nvarchar(20), FiltroTipo nvarchar(80), FiltroProy nvarchar(100), Debe nvarchar(20), Haber nvarchar(20), NoCont tinyint, '
    + N'AtrCta nvarchar(20), DimCta nvarchar(20), LadoAtr int, Prov int, Consumo nvarchar(250), Descr nvarchar(100)) j '
    + N'WHERE NOT EXISTS (SELECT 1 FROM ' + @TR + N' x WHERE x.[Cód_ Concepto] = j.Concepto AND x.[Filtro Tipo Liq_] = j.FiltroTipo AND x.[Filtro Proyecto] = j.FiltroProy '
    + N'AND x.[Cód_ Dimensión Filtro] = N'''' AND x.[Cód_ Atributo Filtro] = N'''' AND x.[Vigencia Desde] = @vig); SELECT @@ROWCOUNT AS Reglas_creadas;';
  EXEC sp_executesql @sql, N'@json nvarchar(max), @vig date', @json, @Vig;
END;

IF COL_LENGTH(N'dbo.[ArbuTest$Tipo Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]', N'Genera Asiento') IS NULL
  PRINT 'Tipo Liquidación todavía no tiene Genera Asiento: publicar la extensión y volver a correr el script.';
ELSE BEGIN
  EXEC sp_executesql N'UPDATE dbo.[ArbuTest$Tipo Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Genera Asiento] = 1
    WHERE [Código] NOT IN (N''HIST_REMUN'', N''SALDO_INICIAL'', N''ANTICIPO'') AND [Genera Asiento] = 0;
    SELECT @@ROWCOUNT AS Tipos_marcados;';
END;

IF @Aplicar = 1 BEGIN COMMIT; PRINT 'Aplicado. Reiniciar el servicio de BC.'; END
ELSE BEGIN ROLLBACK; PRINT 'Prueba: se volvió todo atrás. Poner @Aplicar = 1 para confirmar.'; END;
