/* A CUENTA DE FUTUROS AUMENTOS (2013, 2023, 2043, 2073, 2083) NO CORREN EN PILOTAJE (22/10/2026). Eran conceptos comodín (Tipos Liq. Aplicables vacío) y la primera corrida de PILOTAJE de abril los calculó
   (2013 a 3 oficiales, 2043 a 5, 2083 a 4), inflando bruto y base de Ganancias: 03664 pagaba 2.556.823 de 2013 y su 5010 salía en 1.348.346 contra 496.083 de Meta4. La corrida de pilotaje de Meta4 sólo trae el 2033.
   Cambio: se enumeran todos los tipos existentes menos PILOTAJE (mismo comportamiento que antes en el resto). Un tipo de liquidación nuevo hay que sumarlo a mano a estos cinco.
   Rollback: dejar en blanco "Tipos Liq. Aplicables" de los cinco. Después: reiniciar el servicio y recalcular el PILOTAJE de abril. */
SET NOCOUNT ON;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Tipos Liq_ Aplicables]=N'AGUINALDO|ANTICIPO|CIERRE_MAREA|DEVENGADOS|HIST_REMUN|LIQ_FINAL|REGULAR|RELIQUIDACION|SALDO_INICIAL|VACACIONES', [$systemModifiedAt]=SYSUTCDATETIME()
 WHERE [Código] IN (N'2013',N'2023',N'2043',N'2073',N'2083') AND [Vigencia Hasta]='17530101' AND [Tipos Liq_ Aplicables]=N'';
SELECT @@ROWCOUNT AS esperado_5;
