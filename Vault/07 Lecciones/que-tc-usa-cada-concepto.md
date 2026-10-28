---
aliases: ["Qué TC usa cada concepto"]
tipo: leccion
tema: conceptos-haberes
tags: [leccion, conceptos-haberes, project]
actualizado: 2026-10-04
---

# Qué TC usa cada concepto

**En una frase:** producción y precios de a bordo van al comprador, sueldos en moneda extranjera al vendedor; y el patrón _ESFCY que lo decide

**Comprador** (`TC_COMPRADOR`): toda la producción — oficiales, marinería de tangoneros y
tripulantes españoles —, el asegurado de marea, y los precios de a bordo de oficiales: dique,
francos, pilotaje y puerto.

**Vendedor** (`TC_VENDEDOR`): los sueldos de administración en moneda extranjera y las
liquidaciones de tripulantes españoles — incluido el neto objetivo del grossing-up (`NETO_GU`,
cargado en USD y EUR).

Al 26/9/2026 quedan 17 conceptos en comprador (`ADIC_PROD_PESCA`, `PROD_EMPRESA`, `1083`,
`2403`-`2483`, `2498`, `2499`, `1393`, `1534`, `2003`) y 3 en vendedor (`1003` sueldo, `3553`
vacaciones, `4743` descuento de vacaciones).

**El patrón es `_ESFCY`**, no una regla del motor: el contexto deriva `<PARAM>_ESFCY` de cada
parámetro —verdadero si su vigencia tiene `Moneda` cargada— y **la fórmula decide**, como en
1083: `IF(PRECIO_PUERTO_LAN_ESFCY, PRECIO_PUERTO_LAN * TC_COMPRADOR, PRECIO_PUERTO_LAN)`. Así
el mismo concepto sirve para un par cuyo precio está en pesos y para otro en dólares.

**Un precio en dólares cargado como pesos no da error, da un importe congelado.** Los
`VALOR_FRANCO_*_OF*` estaban en pesos (162.725 / 141.500 / 127.350 / 120.275) y son exactamente
115 / 100 / 90 / 85 **dólares** por el comprador de enero (1.415). Mientras el dólar no se
mueva coinciden con Meta4; el mes que se mueva, se paga al dólar viejo y no hay nada que avise.
Para detectarlo: dividir el parámetro por la cotización del mes en que se cargó y ver si da
redondo.

Ver [[tc-comprador-parametro-fantasma]] y [[parametros-somu-por-pesqueria]].

## Relacionado

- [[oficiales-netos-al-70]]
- [[precio-puerto-lista-inconsistente]]
- [[produccion-no-se-prorratea]]
- [[produccion-oficiales-poteros]]
- [[tc-de-marea-no-es-cotizacion]]
- Tema: `conceptos-haberes` (ver [[_Convenciones del vault]])
