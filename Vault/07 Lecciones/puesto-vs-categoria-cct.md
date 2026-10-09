---
aliases: ["Puesto vs categoría CCT"]
tipo: leccion
tema: convenios-cct
tags: [leccion, convenios-cct, project]
actualizado: 2026-10-04
---

# Puesto vs categoría CCT

> [!note] Verificar: Al 2026-10-04 `ParDePuesto` devuelve el par completo (el convenio sale del padre del puesto), no "sólo la categoría". Ver [[Hallazgos abiertos]].

**En una frase:** Dos ejes distintos — la categoría del CCT paga el sueldo y el puesto paga la producción; en BC eso son el atributo y la asignación

## Dónde vive cada uno, y qué debería haber hecho la migración

Confirmado por el usuario el 23/9/2026, después de revisitarlo varias veces:

| | Meta4 | BC |
|---|---|---|
| categoría | `M4T_HIST_CATEGORIAS`, historial propio. **Casi no cambia** | atributo con historial |
| puesto | `M4T_HIST_PUESTOS`, historial propio. **Cambia seguido** — puede cambiar en cada embarque | atributo con historial |

La diferencia estructural: **en BC los dos atributos comparten el mismo maestro** (`Categoría CCT`), en Meta4 son catálogos separados. La frecuencia de cambio de cada uno es la misma que en Meta4: la categoría quieta, el puesto móvil.

**Lo que la migración debería haber hecho y no hizo:** traer las categorías EXACTAS de `M4T_HIST_CATEGORIAS` al historial del atributo, y lo mismo con `M4T_HIST_PUESTOS` infiriendo el código de BC por el nombre del puesto. El puesto sí se migró así (18/9/2026, ver más abajo); **la categoría no**, y por eso el 23/9/2026 aparecieron **61 de 374 empleados con distinta categoría en BC que en Meta4** (MR05→MR08 en 17 casos, MR05→MR03 en 7, MR05→MR01 en 6…). Como la categoría paga el sueldo, eso mueve varios conceptos a la vez, no uno.

En Meta4 el **puesto** (`M4T_HIST_PUESTOS`, códigos tipo `CB04`) y la **categoría del
CCT** (`MR01` Contramaestre Argentino) son ejes independientes, y pagan cosas distintas:

| Eje | Paga |
|---|---|
| Categoría CCT | sueldo, navegación, puerto, antigüedad, sindical — 260 conceptos |
| Puesto | producción — los 13 conceptos con `Par CCT a Usar = Asignación` |

Comprobado en la marea A28/59: 03957 y 03961 son los dos "Contramaestre Argentino"
(MR01) con el mismo salario base y la misma navegación, pero producción 9.052.166,75
contra 7.694.278,38 — exactamente 14286/12143, o sea índice 100 contra 85. Lo único
que los separa es el puesto: 03957 es `CB04` Control de Calidad desde el 7/1/2024.

En BC el eje 1 sale de `Atributo Entidad Liq.` (Tab110005) vía `ParDeEntidad`, y el eje
2 de `Personal Proyecto` vía `ParDeProyecto` — ver `AplicarParDeConcepto` en Cod50014.
La cabecera de la liquidación siempre trae el eje 1; el concepto lo pisa si está en
Asignación.

**Por qué:** que sean dos fuentes NO es un defecto de diseño, es fiel al dominio. El defecto
es que la segunda pide reconfirmar el puesto en cada asignación a proyecto, mientras que
en Meta4 el puesto tiene historial propio sobre el empleado.

**Cómo aplicarlo:** migrar `M4T_HIST_PUESTOS` a un tipo de atributo `PUESTO` (el mecanismo
ya existe y es efectivo-fechado, ver [[atributos-tipados]]) y que los 13 conceptos de
producción lo lean en vez de la asignación. Hasta que eso pase, la categoría de
`Personal Proyecto` hay que cargarla a mano por marea y **no** se detecta sola:
ver [[migracion-atributos-cct-meta4]], que ya dejó anotado `M4T_HIST_PUESTOS` como
pendiente.

**VALIDADO DE PUNTA A PUNTA el 18/9/2026.** Con los `ID_PUESTO` reales de
`M4T_HIST_PUESTOS` para los 26 tripulantes de la marea A28/59, la cadena
puesto → categoría → `VALOR_CAL_ENT` → producción reproduce **26 de 26** importes de
recibo al centavo. El mapeo puesto→categoría está en
`scripts/MapearPuestosMeta4ACategorias.sql`: 14 coincidencias exactas de descripción,
4 decididas con evidencia (CB06→MR01, CB09→MR09, ME01→MR02, y MQ03→OF04, confirmado por el usuario el 18/9/2026 y además determinado por la estructura: la lista de oficiales alterna rama y rango —impares cubierta, pares máquinas— y MQ03 es el único hueco entre las dos anclas exactas MQ01→OF02 y MQ04→OF06) y 4 sin mapear
a propósito (tripulación española, nadie activo).

Dos cosas que salieron de ahí:

- **La columna CARGO del rol de entrada describe la tarea a bordo, no el puesto de
  nómina.** COLMAN (04169) figura como CONTRA / PLANTA igual que MOLINA, pero su puesto
  es `PT02` Marinero de Planta, índice 70, que es lo que le pagaron. No había diferencia
  que reclamar. Y el `COMENT` de `M4T_HIST_PUESTOS` es texto libre: el de 03957 dice
  "CONTROL DE CALIDAD POTEROS" mientras su puesto es `CB04` Primer Pescador.
- **`OF06` Segundo Oficial de Máquinas existe en 768/19 y no en 175/75.** Como el
  convenio del oficial sale de la flota, un `MQ04` embarcado en un tangonero se queda
  sin categoría. Falta un alta en Categoría CCT.

**Cómo viene el historial de Meta4, para cuando se migre.** Tres trampas vistas en el
volcado de `M4T_HIST_PUESTOS`:

- **Varias filas abiertas por empleado.** El 00436 tiene `MQ03` sin `FEC_FIN` desde 1992
  y encima decenas de filas cerradas hasta 2024; el 00191 tiene dos abiertas a la vez.
  Una fila abierta la pisa la siguiente que EMPIEZA después: normalizar con `LEAD` sobre
  `FEC_INICIO`, nunca con el máximo de `FEC_FIN`. Misma trampa que las islas de estados.
- **`FEC_FIN` en blanco de gente que se fue hace décadas.** De 168 legajos `00xxx` sólo
  17 siguen con alta abierta. Hay que cerrar la vigencia contra la fase de alta o BC
  queda con `PUESTO` vigente para 151 bajas.
- **Los códigos de los noventa no son confiables.** `MQ03` y `CB05` aparecen en ~90 y ~28
  de los primeros 600 legajos, casi siempre con `COMENT = 'IMPORTACION 02/12/99'`, lo que
  no cierra para "Primer Oficial de Máquinas" en una flota pesquera. El catálogo muestra
  que `MQ03` se editó en 2007 y `CB04` en 2012: las descripciones son las ACTUALES. El
  mapeo vale para datos recientes, no para el import de 1999.

**IMPLEMENTADO el 18/9/2026** (falta publicar y cargar). El motor ya distingue los dos
ejes:

- `Espejo Atributo Liq.` (Enum50326) valor 3 `Puesto`: copia el MISMO maestro que
  `Categoría CCT` pero es un espejo aparte, porque `TipoConEspejo` busca el tipo POR su
  espejo con un `FindFirst` — con los dos declarando "Categoría CCT" se pisarían según el
  orden alfabético del código. `Cod50078` mantiene los dos con `BuscarTiposDeCategoria`.
- `Par CCT Liq.` (Enum50327) valor 2 `Puesto`, y `ParDePuesto` en Cod50080. **Cambia sólo
  la categoría, no el convenio**: el puesto no lleva convenio y el del oficial sale de la
  flota del buque. Sin puesto vigente devuelve false y el concepto usa el par de la
  cabecera — el fallback es no cambiar nada.
- `AplicarParDeConcepto` (Cod50014) pasó de un `if` a un `case` y recibe `FechaRef`.

El pipeline de migración está en `scripts/puestos/` (normalizar → staging → validar →
migrar). Simulado de punta a punta contra A28/59: **26 de 26 al centavo**.

**MIGRADO Y ENCENDIDO el 18/9/2026.** 9.809 vigencias en el atributo PUESTO (cero solapes,
cero bajas con puesto vigente) y los 13 conceptos de producción pasados a
`Par CCT a Usar = Puesto`.

Validación independiente en A14/311 (julio 2026, otro buque y otra marea que la que se usó
para armar el mapeo): los recibos de ese formato **imprimen la categoría que Meta4 usó**, y
en los 5 tripulantes donde puesto y asignación difieren, **el puesto acierta los 5 y la
asignación ninguno**. Los básicos confirman los índices: 951.312/783.433 = 1,2143 (85
sobre 70).

Ese formato de recibo —`A14M311.PDF`, uno por buque y marea, con `Legajo | Apellido |
Fec. Ingreso | CUIL` y `Período | Tarea | Categoría | Básico`— es MUCHO más fácil de leer
que el de A28: trae la categoría impresa y los conceptos etiquetados, sin el corrimiento
de una línea entre etiqueta e importe. Para verificar contra Meta4, preferir esos.

**LA FUENTE AUTORITATIVA DEL ÍNDICE APARECIÓ el 18/9/2026**: `M4T_VAL_COEF_CAPECA_PUESTO`, en
Meta4, da el coeficiente **por PUESTO** y por tipo de buque (CG y PT, con los mismos valores).
Coincide en los NUEVE puestos que yo había deducido de los recibos, y agrega los de oficiales:

    CB01 Capitán 1,15 · CB04 Primer Pescador 1,00 · MQ01 Jefe de Máquinas 1,00
    CB03 1er Of. Cubierta 0,90 · CB06 Contramaestre 0,85 · ME01 Cocinero 0,85
    MQ03 1er Of. Máquinas 0,85 · ME02 Mozo 0,80 · ME03 Enfermero 0,80 · PT04 Frío 0,80
    CB07 Marinero Cubierta 0,75 · MQ05 Engrasador 0,75 · PT02 Marinero Planta 0,70

Los coeficientes SON los índices dividido 100, así que confirman la escala de
[[escala-somu-indice-70]] desde el origen y no por inferencia. **Los cuatro de oficiales son lo
que falta para que la producción de oficiales deje de dar cero** (LIQ-00006166: Meta4 paga
37.034.484, BC da 0) — pendiente de verificar contra un recibo antes de cargarlos.

`M4T_VAL_CONVENIO_CATEG_PUESTO` además confirma que la combinación (OF04, MQ03) existe en la
configuración de Meta4: el mapeo MQ03→OF04 ya no depende sólo de mi deducción estructural.

## El puesto que paga la producción de oficiales NO está en Meta4 (29/9/2026)

La predicción de arriba —que los coeficientes CAPECA de oficiales eran "lo que falta para que
la producción de oficiales deje de dar cero", con el caso de los 37.034.484— **era incorrecta**.
Ese caso es el 03664 en A28/59, y se resolvió por otro lado.

Lo que lo destrabó fue cargarle `PUESTO = FE02` (Garantía de Máquinas, del convenio ESP):
`PROD_EMPRESA` pasó de 0 a **37.034.483,70**, exacto contra la planilla, como
`633,639 t × 800 USD × 1415 × 2,5%` de producción más `15.000 × 1415 / 30 × 27` de garantizado.

**Pero ese puesto no sale de ninguna tabla de Meta4, y hay que dejar de buscarlo ahí:**

- `M4T_HIST_PUESTOS` dice `MQ01` (Jefe de Máquinas) en los cinco tramos del 03664 desde 2010,
  y `CB01` (Capitán) en los seis del 04649. Nunca `MQ02` ni `CB02`, que existen y los usan
  59 y 76 empleados.
- `M4T_ACUMULADO_RL3` —el acumulado de la liquidación, que trae `ID_PUESTO` **por marea**
  junto a `ID_BUQUE`, `ID_MAREA`, `DIAS_MAREA` y `A_CTA_MAREA`— dice lo mismo en las cuatro
  corridas de enero. Meta4 liquidó con MQ01/CB01 y aun así pagó los valores de Garantía y
  Patrón de Pesca.
- `M4T_VAL_NETOS_GARANTIZADOS` no tiene los 15.000 USD del 03664 en ningún puesto: MQ01 vale
  7.000 y 4.783, CB01 vale 6.900 y 5.500.

**Por qué:** son acuerdos INDIVIDUALES fuera de convenio, y por eso el valor no cuelga del puesto
en ninguna parte. La planilla `<buque> <marea> CLC producción.xlsx` usa "Garantía de Máquinas"
como etiqueta del trato, no como el puesto de nómina — el mismo fenómeno que la columna CARGO
del rol de entrada, ya anotado arriba. `M4T_HIST_PUESTOS` guarda el puesto **orgánico**, que es
el que sale impreso en el recibo como categoría.

**Cómo aplicarlo:** para los oficiales fuera de convenio, el puesto de liquidación sale de la
planilla CLC de cada marea (legajo, puesto, días, asegurado) y no hay migración que lo traiga.
Los códigos ya existen: `FE01` Patrón de Pesca y `FE02` Garantía de Máquinas, bajo el padre
`ESP`. Queda por decidir si el garantizado va por puesto FE0x —sirve si varios comparten el
trato— o con alcance por empleado en `Parámetro Vigente`, que es más fiel si cada acuerdo es
propio. Ver [[valor-franco-por-terna]] para el patrón de parámetros por terna.

También del mismo día: el 2003 restaba siempre la producción al porcentaje CAPECA. Sólo
corresponde a los puestos que tienen "dif CCT" —Patrón de Pesca y Capitán 2,2%, Primer Oficial
1,8%—; al Jefe y a la Garantía se les restan los básicos ya devengados. La fórmula ahora
discrimina con `IF(PCT_PROD_CAPECA = 0, …)`, y la condición va sobre el porcentaje y no sobre
el producto para que una marea con producción cero no mande al capitán por la rama equivocada.

## Relacionado

- [[lista-precios-oficiales]]
- [[parametros-somu-por-pesqueria]]
- [[sueldo-ordenes-por-convenio]]
- Tema: `convenios-cct` (ver [[_Convenciones del vault]])
