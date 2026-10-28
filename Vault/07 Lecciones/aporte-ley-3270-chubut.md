---
aliases: ["Aporte 8/1000 Ley 3270 de Chubut"]
tipo: leccion
tema: parametros-atributos
tags: [leccion, parametros-atributos, project]
actualizado: 2026-10-15
---

# Aporte 8/1000 (Ley 3270) de Chubut

**En una frase:** Meta4 cobra 0,8% de `BASE_SS_TRAB + BASE_SS_VAC` al personal de tierra de Chubut, y la zona desfavorable no lo identifica: hace falta la provincia de la planta.

Meta4 lo lleva en `AP_PAT_LEY_3270` / `C_CHUBUT` (conceptos 6143 y 9276), **dentro de `OTR_CONTR_A_PAG`** y fuera de `TOT_CONT_SUSS`. Enero de 2026: 36 empleados, 1.017.160,56; febrero: 35. Coincide al centavo con 0,8% de la base SS sin restar la detracción.

**Por qué:** parecía una contribución de SSI porque 24 de los 36 son SSI (Sin Sindicato), y la zona 69 casi lo explicaba (41 empleados, 36 lo pagan). Los cinco que no (90068, 90315, 90396, 90397 y 90441) trabajan en Santa Cruz. La planilla `CONTRIBUCIONES EMPRESA.xlsx` lista el fondo como "Tasa 8/1000 total de haberes".

**Cómo aplicarlo:**

- Atributo de empleado `PROVINCIA` (lista; el código del valor es el Sufijo Parámetro) + parámetro `PCT_LEY_3270` con eje `PROVINCIA`; hoy sólo existe `PCT_LEY_3270_CHU` = 0,8.
- Concepto `7091`: `IF(TIPOEMPL = 2, 0, ROUND(PCT_LEY_3270 / 100 * (BASE_SS_TRAB + BASE_SS_VAC), PRECISION_REDONDEO))`. Los tripulantes dan cero.
- El comparador (`Pag110051`) lo saca de las contribuciones junto con 7080 y 7090.
- **La provincia de la ficha (`County`) es el domicilio, no la planta**: sirve para el personal de tierra, pero 12 tripulantes figuran en Chubut. Cargada la ficha, mandó la evidencia de Meta4. Los nuevos se cargan en el alta.
- Script: `scripts/ProvinciaYAporteLey3270.sql`.

Ver [[otras-contribuciones-por-sindicato]], [[bases-contribuciones-patronales-meta4]] y [[sindicato-obra-social-atributos]].
