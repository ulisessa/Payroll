/* 2033 (A CUENTA DE FUTUROS AUMENTOS PILOTAJE): LA GARANTÍA ES LA DE NAVEGACIÓN, NO LA DE PUERTO (22/10/2026). Indicación del usuario: la fórmula usaba VALOR_PUERTO_EMP y el pilotaje se paga sobre navegación
   (art. 29: garantía en navegación). Cambio, en el lugar (la vigencia del 1/4/2026 es nueva de este mes): VALOR_PUERTO_EMP -> VALOR_NAV_EMP en la condición y en el cálculo. Sólo el 2033; el 2023 (dique) no se toca.
   Efecto en abril: los seis 2033 de Meta4 y el de 03664 siguen por novedad (reemplazan a la fórmula) y 04455 por su novedad en cero; para el resto da cero salvo diferencias chicas posibles en quien tiene
   piso personal de navegación mayor que el de su categoría (04791, 7.000 USD): hay que mirarlo al recalcular.
   Rollback: volver a VALOR_PUERTO_EMP. Después: reiniciar el servicio y recalcular el PILOTAJE de abril. */
SET NOCOUNT ON;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Fórmula]=REPLACE([Fórmula], N'VALOR_PUERTO_EMP', N'VALOR_NAV_EMP'), [$systemModifiedAt]=SYSUTCDATETIME()
 WHERE [Código]=N'2033' AND [Vigencia Desde]='20260401' AND [Vigencia Hasta]='17530101' AND [Fórmula] LIKE N'%VALOR_PUERTO_EMP%';
SELECT @@ROWCOUNT AS esperado_1;
