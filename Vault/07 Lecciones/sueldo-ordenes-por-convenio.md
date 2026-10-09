---
aliases: ["Sueldo a órdenes: 1073 vs 1076"]
tipo: leccion
tema: convenios-cct
tags: [leccion, convenios-cct, project]
actualizado: 2026-10-04
---

# Sueldo a órdenes: 1073 vs 1076

**En una frase:** 1073 y 1076 se parten por veda, no por convenio; el art. 48 es sólo de marinería y por eso parecía un reparto por convenio

El sueldo a las órdenes se paga por **1073 `SUELDO_ORDENES`** (días fuera de veda, sobre
`PRECIO_ORDENES`) o por **1076 `ART48_PAR11`** (días dentro de veda, sobre `PRECIO_NAV`), los
dos al coeficiente de pesquería. **Lo que los separa es la veda.**

**El art. 48 existe sólo en el CCT 729/2015**, así que 1076 es exclusivo de marinería: en toda
la historia de Meta4 lo cobraron 254 marineros entre 2015 y 2026 y ningún oficial. Pero
`SUELDO_ORDENES` lo usan los dos — 615 marineros desde 2000 y 132 oficiales —, así que **no
es un reparto por convenio**. Un oficial con el buque en veda cobra igual por 1073 y por sus
días completos: el 01541 en A14, enero 2026, cobró los 31 días.

Eso se implementa con un auxiliar **`DIAS_ART48`** (tipo 6, orden 60, CCT sólo 729/15) =
`MIN(DIAS_ORD_PERIODO, DIAS_VEDA_BUQUE)`; 1073 resta `#DIAS_ART48` y 1076 lo usa como
cantidad. Para un oficial el concepto no corre y `#DIAS_ART48` se lee 0 — el evaluador
devuelve 0 cuando el concepto referenciado no corrió. La regla "el art. 48 es de marinería"
queda en la CCT, no repetida en un IF dentro de la fórmula.

**Las bases no son la misma.** En marinería `PR_ORDENES = PR_NAVEG = PR_SUELDO/30`, o sea el
básico; en oficiales es el precio de órdenes, que es su básico × 1,5 (el `COEF_ORDENES` = 1,5
de Meta4). Por eso 1076 lee `PRECIO_NAV` y 1073 `PRECIO_ORDENES`: `PRECIO_ORDENES` de
marinería vale básico × 1,5, así que usar el mismo parámetro en los dos le paga 1,5 veces de
más. `BASICO` no está cargado para marinería.

**Por qué:** llegué a "se parte por convenio" mirando sólo enero 2026, donde **todos** los
tangoneros estaban en veda — así que los 96 marineros cayeron en 1076 y los 18 oficiales en
1073, sin un solo caso cruzado. Un mes entero de datos limpios y la conclusión estaba mal: el
discriminador verdadero era constante en la muestra. Ver [[previsualizar-antes-de-migrar]].

**Cómo aplicarlo:** ver [[veda-como-atributo-del-buque]] para de dónde salen los días de veda.

## Relacionado

- [[lista-precios-oficiales]]
- [[parametros-somu-por-pesqueria]]
- [[puesto-vs-categoria-cct]]
- Tema: `convenios-cct` (ver [[_Convenciones del vault]])
