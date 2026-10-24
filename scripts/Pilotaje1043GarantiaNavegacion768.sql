/* PILOTAJE EN 768/19: EL PRECIO DEL DÍA ES LA GARANTÍA DE NAVEGACIÓN DEL CONVENIO, NO EL PRECIO DE PUERTO (22/10/2026). Comparación de abril contra la corrida de pilotaje de Meta4 (TP_IMPUT 12).
   6 oficiales de 768/19 (01477, 04791, 04868 en OF01; 02452, 04724, 04924 en OF03) cobraban en BC 1.255.833 / 982.747 y en Meta4 1.575.500 / 1.233.000 (5 días). No era el tipo de cambio:
   Meta4 = 6.900 USD x 1.370 / 30 x 5 en OF01 y 5.400 USD x 1.370 / 30 x 5 en OF03, o sea la garantía de navegación del CCT (GARANT_POT_CCT, sin los pisos personales de VALOR_NAV_EMP: 01477 y 04791 tienen 7.000),
   con el mismo TC (1.370) que BC. BC usaba PRECIO_PUERTO (5.500 y 4.304 USD). Art. 29: el quíntuplo de cinco días de la remuneración garantizada en navegación.
   Cambio, en el lugar (vigencia del 1/4/2026, nueva de este mes): 1043 = #DIAS_PILOT_PAGO * IF(GARANT_POT_CCT > 0, GARANT_POT_CCT, PRECIO_PUERTO) / 30 * COEF_PILOTAJE_PUERTO * #COEF_PESQUERIA.
   Fuera de 768/19 GARANT_POT_CCT vale 0 (fila genérica) y sigue PRECIO_PUERTO.
   Rollback: volver a PRECIO_PUERTO. Después: reiniciar el servicio y recalcular el PILOTAJE de abril. */
SET NOCOUNT ON;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Fórmula]=N'#DIAS_PILOT_PAGO * IF(GARANT_POT_CCT > 0, GARANT_POT_CCT, PRECIO_PUERTO) / 30 * COEF_PILOTAJE_PUERTO * #COEF_PESQUERIA', [$systemModifiedAt]=SYSUTCDATETIME()
 WHERE [Código]=N'1043' AND [Vigencia Desde]='20260401' AND [Vigencia Hasta]='17530101' AND [Fórmula] LIKE N'%PRECIO_PUERTO%' AND [Fórmula] NOT LIKE N'%GARANT_POT_CCT%';
SELECT @@ROWCOUNT AS esperado_1;
