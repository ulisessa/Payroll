---
aliases: ["Lista de precios de oficiales"]
tipo: leccion
tema: convenios-cct
tags: [leccion, convenios-cct, project]
actualizado: 2026-10-04
---

# Lista de precios de oficiales

**En una frase:** La lista de precios de oficiales sale de PR_SUELDO/PR_NAVEG/PR_FRANCO de Meta4, es uniforme por categoría, y BC la tiene bien en PRECIO_NAV y VALOR_FRANCO

Meta4 imprime los precios de cada oficial en el recibo y los guarda como columnas `PR_*`. En enero de
2026 son **uniformes dentro de cada categoría**, sin un solo empleado fuera de línea, y dan la lista
completa de oficiales:

| convenio | categoría | `PR_SUELDO` (mes) | `PR_NAVEG` (día) | `PR_FRANCO` (día) | franco en USD/mes |
|---|---|---:|---:|---:|---:|
| 175/75 | OF02 | 900.000 | 30.000 | 141.500 | 3.000 |
| 175/75 | OF04 | 765.000 | 25.500 | 120.275 | 2.550 |
| 768/19 | OF01 | 1.485.000 | 49.500 | 162.725 | 3.450 |
| 768/19 | OF03 | 1.162.000 | 38.733,33 | 127.350 | 2.700 |

`PR_NAVEG = PR_SUELDO / 30` y los demás días salen de ahí por coeficiente, que Meta4 también guarda:
`COEF_NAVEG` 1, `COEF_ORDENES` 1,5, `COEF_PUERTO` 2, `COEF_DIQUE` 2, `COEF_FERIADO` 2,
`COEF_PILOTAJE` 4. Así `PR_PUERTO` = 60.000 para OF02 = 30.000 × 2, y `PRECIO_PILOTAJE` = 120.000.

**Los francos en USD se convierten al comprador**: 141.500 / 1.415 = 100 USD/día = 3.000 USD/mes.

## Qué confirma en BC

- **`PRECIO_NAV_LAN` y `PRECIO_NAV_CAL` coinciden al peso con `PR_SUELDO`** en las cuatro categorías,
  y las dos pesquerías tienen el mismo valor. La base de la antigüedad de oficiales está bien
  parametrizada — ver [[antiguedad-suma-de-fases]].
- **`VALOR_FRANCO` coincide al peso con `PR_FRANCO`** en las cuatro, en 175/75, 768/19 y ESP.

## Y cierra una duda que quedaba abierta

`VALOR_FRANCO_175/75_OF03` = 127.350 parecía ×0,90 de OF02 cuando `PCT_ESCALA_ARBU` dice ×0,85, y
**no había ningún error**: comparaba entre convenios. OF03 vive en 768/19 —ver
[[convenio-of-depende-de-la-categoria]]— y dentro de cada convenio la razón es limpia:

    175/75:  OF04 / OF02 = 120.275 / 141.500 = 0,85   exacto
    768/19:  OF03 / OF01 = 127.350 / 162.725 = 0,7826

Las filas `VALOR_FRANCO_175/75_OF01` y `_OF03` (y las `768/19_OF02` y `_OF04`) son pares que no
existen: datos muertos, como las de `BASICO`.

## Jefe de Máquinas es OF02

Lo dice el recibo del 00794: "Convenio: Oficiales Embarcados, Categoría: Jefe de Máquinas" con par
`175/75 / OF02`. Eso **valida por qué `VALOR_FRANCO_ACDO` (hoy `VALOR_FRANCO_EMP`) se cargó sólo para OF02 y OF04**: el
acuerdo de empresa es de jefe y primer oficial de máquinas, y OF01/OF03 no son de máquinas. La
guarda de 2083 no es defensiva, es correcta — ver [[a-cuenta-futuros-aumentos-francos]].

## Relacionado

- [[parametros-somu-por-pesqueria]]
- [[puesto-vs-categoria-cct]]
- [[sueldo-ordenes-por-convenio]]
- Tema: `convenios-cct` (ver [[_Convenciones del vault]])
