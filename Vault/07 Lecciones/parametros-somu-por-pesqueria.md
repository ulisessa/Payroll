---
aliases: ["Parámetros SOMU por pesquería"]
tipo: leccion
tema: convenios-cct
tags: [leccion, convenios-cct, reference]
actualizado: 2026-10-04
---

# Parámetros SOMU por pesquería

**En una frase:** PRECIO_PUERTO y compañía se parten en _LAN y _CAL; PCT_DOLAR_PROD no

Los parámetros de importe de SOMU están partidos por pesquería: **`_LAN`**
(langostino, tangoneros) y **`_CAL`** (calamar, poteros). No existe `PRECIO_PUERTO`
a secas — aunque haya 45 valores cargados bajo ese nombre, contra un parámetro base
inexistente que ninguna fórmula lee. Lo mismo con `VALOR_FRANCO_*`,
`PRECIO_ORDENES_*` y `PRECIO_NAV_*`.

**`PCT_DOLAR_PROD` NO se parte por pesquería:** es uno solo por convenio y
categoría —60 para `175/75`, 78 para `729/15`, 90 para `768/19`— y la misma fila
sirve a las dos. Están probados y son correctos.

**Los `PCT_` conviven en DOS unidades y no hay forma de saber cuál es cuál sin mirar
el valor.** Guardados como porcentaje entero, y por lo tanto la fórmula TIENE que
dividir por 100: `PCT_JUB`=11, `PCT_OS`=3, `PCT_19032`=3, `PCT_CUOTA_SIND`=2..10,75,
`PCT_DOLAR_PROD`=60..90, `PCT_PROD_CAPECA`=1,8..2,2, `PCT_PROD`, `PCT_ADIC_ART23`=60,
`PCT_TRAB_ESP`=20. Guardados ya como fracción, y entonces dividir sería el error:
`PCT_CONT_JUB`=0,1077, `PCT_CONT_19032`=0,0159, `PCT_CONT_23660`=0,06, `PCT_ART`=0,0551,
`PCT_ASIG_FAMI`=0,047, `PCT_FNE`=0,0094, `PCT_ANTIG`=0,01..0,25, `PCT_TAR_MEC`=0,15,
`PCT_FRIO_PTA`=0,333, `PCT_ADICIONAL_OS`, `PCT_CUOTA_EXT_CAP`=0,03, `PCT_NORM_TANG`=0,82.
`PCT_ESCALA_*` y `PCT_PUESTO` no son porcentajes sino coeficientes.

Por eso **"la fórmula no divide por 100" no es un defecto por sí solo**: el 21/9/2026 un
barrido crudo dio 37 candidatos y sólo 6 eran error. El control que sirve es comparar
contra el GEMELO: `6000 Jubilacion` dice `* PCT_JUB / 100` y `6003 Jubilacion vacaciones`
decía `* PCT_JUB`. Estaban mal las variantes SAC y VACACIONES de los descuentos del
trabajador —6002, 6003, 6012, 6013, 6035 y 8525— multiplicando por cien de más.

Estuvo oculto años porque las bases `_VAC` valían casi cero: recién al enchufar el
promedio de seis meses (ver [[vacaciones-tripulantes-promedio]]) la base pasó a valer
millones y salió a la superficie, con 6.345 millones de descuentos en enero donde iban
63,4. **Un factor de escala mal no se ve mientras la base sea chica.**

**Por qué:** el 17/9/2026 el documento de carga mapeaba tres columnas a
`PRECIO_PUERTO`, `VALOR_FRANCO` y `PRECIO_ORDENES`, que no existen, y daba por
verificados dos valores de oficiales que no están en la base.

**Cómo aplicarlo:** antes de cargar, mirar `Parámetro` (los códigos base) y no sólo
`Parámetro Vigente`, donde puede haber valores huérfanos. Ver
[[escala-somu-indice-70]] y [[conexion-sql-bc]].

## Relacionado

- [[lista-precios-oficiales]]
- [[puesto-vs-categoria-cct]]
- [[sueldo-ordenes-por-convenio]]
- Tema: `convenios-cct` (ver [[_Convenciones del vault]])
