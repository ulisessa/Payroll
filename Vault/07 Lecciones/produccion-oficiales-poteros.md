---
aliases: ["Producción de oficiales en poteros"]
tipo: leccion
tema: conceptos-haberes
tags: [leccion, conceptos-haberes, project]
actualizado: 2026-10-04
---

# Producción de oficiales en poteros

**En una frase:** El modelo de dos totales (convenio y empresa) de la producción de oficiales en poteros, decodificado al centavo contra A28/59

Decodificado el 18/9/2026 con la planilla `A28 59 CLC producción.xlsx` y el recibo de 04649.
**Sólo aplica a POTEROS** (convenio 768/19). Los tangoneros son otra cosa.

Todo sale de un solo insumo de marea: **USD de producción** (506.911,20 en A28/59, = 0,80 USD
por kg neto) y el **tipo de cambio** (1.415). De ahí:

    bruto  = USD x TC                          717.279.348,00
    conv   = bruto x COEF 0,90                 645.551.413,20   ("PRODUCCION AACPyPP $")

**Los dos totales, y sobre qué base va cada uno** — esto es lo que no se adivina:

| | base | % | ejemplo |
|---|---|---|---|
| **Convenio** | bruto **x 0,90** | `PCT_PROD_CAPECA` · CAP 2,20 · 1° OF 1,80 | 14.202.131,09 |
| **Empresa** | bruto **sin coeficiente** | `PCT_PROD` · Pesca 4,00 · Capitán 2,00 · Jefe 2,00 · Garantía 2,50 | 14.345.586,96 |

Y las dos diferencias que van al recibo:

    PREMIO ADIC. ESP. DE PRODUCCIÓN = total convenio - (Sueldo Nav + Sueldo Puerto + Antigüedad + Adic. Art 23)
    A CTA FUTUROS AUMENTOS          = total empresa  - total convenio

    total empresa = produccion empresa + ASEGURADO (USD/mes x TC x 0,90)

Verificado al centavo en 04649: 14.202.131,09 − 2.425.536,67 = **11.776.594,42** (premio del
recibo) y 46.571.665,77 − 14.202.131,09 = **32.369.534,68** (a cta del recibo).

**Esto destraba LIQ-00006166**: los 37.034.483,70 de 3664 (Garantía de Máquinas) son
17.931.983,70 de producción empresa + 19.102.500 de asegurado.

**Lo que BC ya tiene**: `PCT_DOLAR_PROD` 768/19 = 90 (es el COEF), `PCT_PROD` = 2,00 para
OF01/OF02, `PCT_PROD_CAPECA` = 2,20 OF01 / 1,80 OF03, `USD_MAREA` = 6900 OF01 / 5500 OF02.
**Lo que falta**: los % de Pesca (4,00) y Garantía (2,50), el `USD_MAREA` de FE01 (7.000) y
FE02 (15.000), y los dos insumos por marea — USD de producción y tipo de cambio.

Ojo con los nombres: la planilla usa PUESTO (Pesca, Capitán, Jefe de Máquinas, Garantía de
Máquinas) que es una quinta nomenclatura, distinta del rol de entrada, del catálogo de puestos
de Meta4 y de la categoría del CCT. Ver [[puesto-vs-categoria-cct]].

**CORREGIDO Y COMPLETADO leyendo las FORMULAS del xlsx** (descomprimir el .xlsx y mirar
`xl/worksheets/sheet1.xml`; los `<f>` estan ahi). Dos cosas que habia deducido mal de los
numeros:

- **El asegurado NO lleva coeficiente**: la celda es `=H/30*F`, o sea
  `USD_MAREA x TC / 30 x DIAS`. En A28/59 la marea duro 27 dias y 27/30 = 0,90, que es
  identico al COEF y me hizo leer un coeficiente donde hay un prorrateo por dias.
- **La produccion de empresa es USD POR TONELADA por puesto, no un porcentaje**:
  `=C20*<n>*C7/1000` con n = **Pesca 32 Â· Capitan 16 Â· Jefe 16 Â· Garantia 20**. Da lo mismo
  que un porcentaje del bruto SOLO porque `USD_TON_PROD` vale 800 (32/800 = 4%, 16/800 = 2%,
  20/800 = 2,5%). Si ese 800 cambia, las dos lecturas se separan.

**El ADIC PROD PESCA son 10 USD/ton extra para el Patron de Pesca** (`=1000/100*C25*C7`).
El Patron cobra 32 + 10 = 42 USD/ton.

**El "prorrateo" del Capitan es un literal a mano**: la celda J14 dice
`=183.333333333333*F14*C7`, y 183,3333 = 5.500/30, el USD del JEFE. Su propio valor esta
calculado al lado (I14 = 8.787.150) y no se usa. Es un ajuste manual de esa marea, no una regla.

La planilla tambien confirma desde el origen la escala SOMU: `=ROUND((H20/70*100),0)` y
siguientes, con el basico de Marinero de Planta en H20. Ver [[escala-somu-indice-70]].

**El recibo de Meta4 de 04649 / A28-59 (visto el 18/9/2026) cierra el resto del encuadre**, y
confirma que las cuatro deducciones del premio son exactamente las que la fórmula del 1534 ya
resta. Reglas que BC tenía mal o no tenía, todas de 768/19 y todas verificadas al peso:

- **El sueldo de puerto de los oficiales NO es el doble del de navegación.** Para 729/15 sí lo es
  —relación 2,000 clavada en las nueve categorías MR y en Meta4—, y esa regla se copió a las cinco
  OF, que es donde falla: OF01 cobra 259.416,67 por día, o sea **7.782.500 mensuales** contra los
  2.970.000 (= 2 × 1.485.000) que estaban cargados. En 768/19 la tarifa de puerto es independiente
  de la de navegación; OF02/OF03/OF04 siguen con el doble exacto y hay que confirmarlos.
- **Adicional Art. 23 = 60% del sueldo de navegación, y sólo para oficiales.** Verificado en las 26
  filas de la tripulación: OF01/OF02 con ratio 0,6000, todos los MR* en cero. El concepto 1533
  tiene la fórmula VACÍA, así que siempre dio cero.
- **La antigüedad de un oficial sale de la misma escala SOMU**: el recibo trae "8,00" como unidad,
  que es el tramo `>= 3 años` de `PCT_ANTIG_SOMU`. Daba cero porque ese concepto no está habilitado
  para 768/19 (sólo 175/75, 729/15 y ESP) y `#PCT_ANTIG_SOMU` leía 0.
- **Cuota sindical 768/19 = 3%**, no 2,5%. El 3,00 existe en la tabla pero cargado bajo
  `PCT_CUOTA_SIND_175/75_OF01`; huele a error de tipeo al migrar.
- **Centro de capacitación = 1% del remunerativo.** El 8553 está habilitado sólo para 768/19 —o sea,
  existe exactamente para este caso— y también tiene la fórmula vacía.

El total remunerativo del recibo (46.571.665,77) **es PROD_EMPRESA**: básicos + premio dan el total
de convenio, y sumándole el a-cuenta da el de empresa. El modelo cierra por los dos lados.

Cuidado al leer `@2499`/`@2498` en el 1534 y el 2003: cruzan de par. Ver
[[arroba-ignora-el-par-del-concepto]].

## Relacionado

- [[oficiales-netos-al-70]]
- [[precio-puerto-lista-inconsistente]]
- [[produccion-no-se-prorratea]]
- [[que-tc-usa-cada-concepto]]
- [[tc-de-marea-no-es-cotizacion]]
- Tema: `conceptos-haberes` (ver [[_Convenciones del vault]])
