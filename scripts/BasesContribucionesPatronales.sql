/*
    BASES DE CONTRIBUCIONES PATRONALES (enero 2026, conciliación contra Meta4).
      - 7000/7010/7060/7070: base = BASE_SS_TRAB + BASE_SS_VAC (la remunerativa, no la de Ganancias) y
        la detracción DED_CONT_PATR se resta UNA vez por mes: MES_BASE_SS_* es lo ya liquidado en otras
        liquidaciones del mismo período; se contribuye por la diferencia del mes acumulado.
      - 7030: base = BASE_OS_TRAB + BASE_OS_VAC (las liquidaciones de vacaciones pagaban cero).
    Se corrige la vigencia 2026-01-01 en lugar de abrir otra: no puede haber dos con el mismo Desde.
    Después de aplicar: reiniciar el service tier y recalcular enero.
*/
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @t TABLE(cod nvarchar(20), pct nvarchar(30));
INSERT @t VALUES ('7000','PCT_CONT_JUB'),('7010','PCT_CONT_19032'),('7060','PCT_ASIG_FAMI'),('7070','PCT_FNE');
UPDATE c SET [Fórmula]=N'round((MAX(0, BASE_SS_TRAB + BASE_SS_VAC + MES_BASE_SS_TRAB + MES_BASE_SS_VAC - DED_CONT_PATR) - MAX(0, MES_BASE_SS_TRAB + MES_BASE_SS_VAC - DED_CONT_PATR)) * '+t.pct+N', PRECISION_REDONDEO)', [$systemModifiedAt]=SYSUTCDATETIME()
FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c JOIN @t t ON t.cod=c.[Código] WHERE c.[Vigencia Desde]='20260101';
SELECT @@ROWCOUNT AS esperado_4;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Fórmula]=N'round(MAX(0, BASE_OS_TRAB + BASE_OS_VAC) * PCT_CONT_23660, PRECISION_REDONDEO)', [$systemModifiedAt]=SYSUTCDATETIME() WHERE [Código]='7030' AND [Vigencia Desde]='20260101';
SELECT @@ROWCOUNT AS esperado_1;
SELECT [Código],[Fórmula] FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] IN ('7000','7010','7030','7060','7070') AND [Vigencia Desde]='20260101';
COMMIT;
