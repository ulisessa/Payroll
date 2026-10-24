---
aliases: ["Otras contribuciones a pagar: dependen del sindicato"]
tipo: leccion
tema: contribuciones-patronales
tags: [leccion, contribuciones-patronales, sindicato, comparador]
actualizado: 2026-10-15
---

# Otras contribuciones a pagar: dependen del sindicato

`TOT_CONTRIB` de Meta4 no es lo que presenta el 931. Es `TOT_CONT_SUSS` más `OTR_CONTR_A_PAG` (concepto 9650,
"Otr contr a pagar", cuenta 21.13.310) = `C_SINDICATO` (9272). En enero de 2026 son **151 empleados y 22,74 M**.
Con la parte SICOSS bien (ver [[bases-contribuciones-patronales-meta4]]) esa era toda la diferencia del comparador,
más el `7080` (seguro de vida obligatorio), que BC cuenta y Meta4 no guarda en ninguna columna con importe.

**Depende del atributo `SINDICATO` del empleado** (el dato es de la persona, no del convenio; ver el atributo en
[[Atributos tipados]]):

| Sindicato | Qué paga Meta4 | Columna |
|---|---|---|
| `ASO` | 849.000 fijo por mes | `C_SINDICATO` |
| `CON` | 200.000 en buques tangoneros (TIPOACTIVIDAD LAN), 1.216.900 en poteros (CAL) | `FARM_CON_NAV` (6303) |
| `PAT` | 1,0000 % de la base total remunerativa + no remunerativa (la de ART) | `FARMACIA_PAT` (6323) |
| `SOM`, `SSI`, `STI`, `FEC` | porcentajes que varían dentro del sindicato (SOM ≈ 1,47–1,48 % de `REMUN_IMPO_JUB`) | sin modelar (~5,5 M) |

No se explican por convenio ni por categoría: `OF02` de 175/75 tiene de los dos montos de `CON`. Lo que los separa es el
tipo de buque, el mismo eje que ya usan los precios de francos y de puerto.

**Cómo está modelado (15/10/2026), sin tablas ni campos nuevos:** concepto `7090` (Contribución Patronal, mismo molde
que el `7053`: el fijo se cobra una vez por mes con `MES_CONTRIB_SIND`), parámetros `CONTRIB_SIND_FIJO` (ejes
SINDICATO y TIPOACTIVIDAD) y `PCT_CONTRIB_SIND` (eje SINDICATO), y `Sufijo Parámetro` = código en los valores `ASO`,
`CON` y `PAT` del atributo. Script: `scripts/ContribucionesSindicales.sql`. Cubre 36 empleados y unos 17 M de los 22,7.

**El comparador** (v1.0.0.659) compara el Total Contribuciones de BC **sin el `7080` ni el `7090`** contra `TOT_CONT_SUSS`.
Antes comparaba contra `TOT_CONTRIB` y todo empleado con otras contribuciones aparecía con una diferencia que no era un error.

Ver [[Comparador BC vs Meta4]].
