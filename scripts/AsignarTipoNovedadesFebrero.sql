/*
    NOVEDADES DE FEBRERO 2026 CON EL TIPO DE LIQUIDACIÓN EN BLANCO QUE CAYERON EN EL RECIBO EQUIVOCADO.

    Sin Cód. Tipo Liq. la novedad entra en la liquidación cuya cobertura contiene su fecha, y la fecha
    de estas viene estampada de la migración (25/02 = pago de la corrida mensual, 27/02 = pago de la
    corrida de vacaciones). Con vacaciones y Regular en el mismo mes, la cobertura de Vacaciones suele
    contener las dos fechas. El tipo correcto sale de Meta4: la corrida cuyo valor en la columna
    mapeada al concepto iguala el importe, y su Tipo de Imputación (1 = mensual → REGULAR,
    3 = vacaciones → VACACIONES).

    10 novedades (todas 8893, cuota alimentaria): 8 de Vacaciones → REGULAR, 2 de Regular → VACACIONES.
    NO se tocan las que no tienen columna mapeada (no se pueden verificar) ni las dos de DEVENGADOS
    (8893 de 01477 y 8830 de 04163), que llevan proyecto de marea.

    Sólo se carga el TIPO. La novedad sigue Aplicada en la liquidación vieja hasta que ésta se
    recalcula: recalcular PRIMERO Vacaciones y DESPUÉS Regular de cada empleado (Vacaciones libera la
    novedad; Regular la toma). SQL directo: reiniciar el service tier.
*/
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
UPDATE dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
SET [Cód_ Tipo Liq_] = N'REGULAR', [$systemModifiedAt] = SYSUTCDATETIME()
WHERE [No_ Movimiento] IN (2860,2934,3226,3262,3723,3745,4157,4555) AND [Cód_ Concepto] = N'8893' AND [Cód_ Período] = N'202602' AND [Cód_ Tipo Liq_] = N'';
SELECT @@ROWCOUNT AS A_REGULAR_esperado_8;
UPDATE dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
SET [Cód_ Tipo Liq_] = N'VACACIONES', [$systemModifiedAt] = SYSUTCDATETIME()
WHERE [No_ Movimiento] IN (3860,4425) AND [Cód_ Concepto] = N'8893' AND [Cód_ Período] = N'202602' AND [Cód_ Tipo Liq_] = N'';
SELECT @@ROWCOUNT AS A_VACACIONES_esperado_2;
COMMIT;
SELECT [No_ Movimiento] mov, [No_ Empleado] e, [Cód_ Tipo Liq_] tipo FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
WHERE [No_ Movimiento] IN (2860,2934,3226,3262,3723,3745,4157,4555,3860,4425) ORDER BY 3,1;
