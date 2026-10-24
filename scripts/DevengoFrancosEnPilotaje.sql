/* DEVENGO DE FRANCOS EN LA LIQUIDACIÓN DE PILOTAJE (22/10/2026). La corrida de pilotaje de Meta4 (TP_IMPUT 12, 21/4) devenga francos: DS_FRANCOS_DEV = 1 por empleado (50 % de los 2 días PI) y su SALDO_DS_FRANCO pasa de 64 a 65
   (04714: FRANCOS_DEV 56.239). BC no los devengaba: el concepto 1062 ("Francos devengados y liquidados", rol Devengo, fórmula ROUND(COEF_FRANCOS * DIAS_DEVENGA_FRANCOS_COBERTURA, 1) + DIAS_FERIADOS_GUARDIA cuando no hay marea) aplicaba
   sólo a CIERRE_MAREA, LIQ_FINAL, REGULAR y DEVENGADOS, y el pilotaje se separó en su propio tipo el 22/10 (PilotajeLiquidacionAparte.sql lo dejó sin francos). Efecto: a los 40 les faltaba 1 día en el saldo y a los que se dieron de baja
   después del pilotaje (04518, 04591, 04714, 04822, 04825, 04906, 04923, 04932 y los oficiales 04163, 04836, 04455) la indemnización de francos (2803) les salía 1 día más baja que a Meta4 (−56.232 a −80.331 y su SAC).
   Cambio: PILOTAJE se agrega a los "Tipos Liq. Aplicables" del 1062 (una sola vigencia, la del 1/1/2026, abierta). Rollback: sacar "|PILOTAJE".
   Después: reiniciar el servicio y recalcular, en orden, el PILOTAJE de abril de los 40 y las LIQ_FINAL de esos empleados. */
SET NOCOUNT ON;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Tipos Liq_ Aplicables]=[Tipos Liq_ Aplicables]+N'|PILOTAJE', [$systemModifiedAt]=SYSUTCDATETIME()
 WHERE [Código]=N'1062' AND [Vigencia Desde]='20260101' AND [Vigencia Hasta]='17530101' AND [Tipos Liq_ Aplicables] NOT LIKE N'%PILOTAJE%';
SELECT @@ROWCOUNT AS esperado_1;
