/* PCT_ANTIG_SOMU EN PILOTAJE: FALTABA EN LA VIGENCIA DE ABRIL (22/10/2026). PilotajeLiquidacionAparte.sql agregó PILOTAJE a los "Tipos Liq. Aplicables" filtrando por la vigencia abierta (Vigencia Hasta en blanco),
   y la de PCT_ANTIG_SOMU abierta es la del 1/7/2026; la que rige en abril (1/1 al 30/6) quedó sin PILOTAJE. En PILOTAJE el porcentaje salía 0 y la antigüedad (1053) de las marineras daba 0 (Meta4: 03487, 25 % x PR_NAVEG x 6 días = 37.655).
   Es el único concepto con vigencia futura al 25/4 (se revisaron todos). Rollback: sacar "|PILOTAJE" de esa vigencia. Después: reiniciar el servicio y recalcular el PILOTAJE de abril. */
SET NOCOUNT ON;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Tipos Liq_ Aplicables]=[Tipos Liq_ Aplicables]+N'|PILOTAJE', [$systemModifiedAt]=SYSUTCDATETIME()
 WHERE [Código]=N'PCT_ANTIG_SOMU' AND [Vigencia Desde]='20260101' AND [Vigencia Hasta]='20260630' AND [Tipos Liq_ Aplicables] NOT LIKE N'%PILOTAJE%';
SELECT @@ROWCOUNT AS esperado_1;
