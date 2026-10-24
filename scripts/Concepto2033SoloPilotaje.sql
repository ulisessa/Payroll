/* 2033 SÓLO EN PILOTAJE (22/10/2026). Era un concepto comodín (Tipos Liq. Aplicables vacío) y con la rama IF(ES_GROSSING_UP > 0, COMPLEMENTO_GU, ...) tomó el complemento del grossing-up de 04826 también en el CIERRE_MAREA
   (11.990.048), duplicándolo con el 2003: 04826 llegó a 13.698.746 de 2033 en abril contra 1.708.710 de Meta4. El 2033 (A_CT_FUT_AUM_PI) es del pilotaje: igual que el 1043, se limita a PILOTAJE.
   Rollback: dejar en blanco "Tipos Liq. Aplicables". Después: reiniciar el servicio y recalcular el CIERRE_MAREA de abril de 04826 (y de cualquier empleado con neto garantizado que se haya recalculado desde las 15:00 UTC del 22/10). */
SET NOCOUNT ON;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Tipos Liq_ Aplicables]=N'PILOTAJE', [$systemModifiedAt]=SYSUTCDATETIME()
 WHERE [Código]=N'2033' AND [Vigencia Hasta]='17530101' AND [Tipos Liq_ Aplicables]=N'';
SELECT @@ROWCOUNT AS esperado_1;
