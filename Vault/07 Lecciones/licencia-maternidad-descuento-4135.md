---
aliases: ["Licencia por maternidad: el 4135 sale del estado"]
tipo: leccion
tema: conceptos-haberes
tags: [leccion, conceptos-haberes, project]
actualizado: 2026-10-15
---

# Licencia por maternidad: el 4135 sale del estado

**En una frase:** el descuento de días de maternidad (4135) no tenía fórmula y sólo existía como novedad; ahora se calcula con los días AU3 en base 30, igual que Meta4.

90452 (FA55) tiene AU3 del 29/1 al 28/4. Meta4: enero paga 2.156.000 (el sueldo 2.310.000 menos 2 días, `4135 = -154.000`, incidencia 530 = 2: el mes comercial de 30 cuenta el 29 y el 30 y no el 31), y febrero y marzo **no liquidan nada**. BC pagaba el sueldo entero (+2.310.000 de diferencia en febrero).

Cambio (`scripts/Maternidad4135.sql`): Fuente de Datos `DIAS_MATERNIDAD_30` (copia de `DIAS_ENFERMEDAD_30` con el código AU3) y `4135` desde el 1/2 = `-ROUND(#1003 / 30 * DIAS_MATERNIDAD_30, PRECISION_REDONDEO)` con condición `DIAS_MATERNIDAD_30 > 0`. La vigencia de enero queda con su novedad de importe y no se descuenta dos veces.

**Límite:** el 4135 se calcula sobre el 1003. Una licencia por maternidad con otros haberes (antigüedad, adicionales) no los descuenta. En febrero hay un solo AU3 (90452); 90451 empieza el 12/3 (19 días en la incidencia 530 de Meta4 del 25/3), así que marzo es el siguiente caso para verificar. La liquidación de febrero de 90452 queda con bruto cero: conviene confirmar que el descarte de vacías (ver [[crear-y-calcular-descarta-vacias]]) la trata como Meta4, que no la liquida.
