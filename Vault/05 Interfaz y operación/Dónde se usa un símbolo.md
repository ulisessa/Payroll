---
tipo: proceso
tags: [ui, diagnostico, conceptos, acumuladores, orden-calculo]
fuente: [src/Pages/Pag110062.DondeSeUsa.al, src/Codeunits/Cod110058.BuscarUsosLiq.al, src/Tables/Tab110064.UsoSimboloLiq.al]
actualizado: 2026-10-11
---

# Dónde se usa un símbolo

Página **110062 "Dónde se usa"** (*Informes y análisis*). Contesta una pregunta que antes exigía leer dos mil fórmulas a mano: **qué le afecta si toco esto.**

El motor se configura, no se codifica, y el precio es que **ninguna dependencia está declarada**: vive adentro de un campo de texto. Un parámetro, un concepto, una fuente de datos o un atributo pueden estar nombrados en ocho lugares distintos, y el que no se revisa es siempre el que rompe.

## Los ocho lugares donde busca

| # | Dónde | Tabla |
|---|---|---|
| 1 | `Fórmula` de un concepto | `Concepto Liquidación` |
| 2 | `Condición` | idem |
| 3 | `Variable Cantidad` | idem |
| 4 | `Variable Base` | idem |
| 5 | `Filtro Valor 1/2/3` y la subtabla de filtros | `Fuente Datos Liquidación`, `Filtro Fuente Datos Liq.` |
| 6 | Fracciones, **en las dos direcciones** | `Fracción Acumulador` |
| 7 | `Cód. Acumulador` / `Cód. Concepto` de una variable de sistema | `Variable Sistema Liq.` |
| 8 | `Cód. Parámetro Valor`, `Cód. Tipo Atributo Detalle`, `Cód. Tipo Atributo Precio` | `Concepto Liquidación` |

> [!important] El punto 6 es el que se olvida
> La fracción **hacia adelante** —"Aporta al acumulador"— es un uso aunque nadie nombre al concepto en ninguna fórmula. El 4751 es el caso que lo demostró: ninguna fórmula lo menciona, y sin embargo aporta el 100 % a `GAN_NETA_MES`, `GAN_NETA_A_DEDUC` y `SS_SAC_DEV`. Mirando sólo las fórmulas la respuesta era "casi no se usa", que es lo contrario de la verdad.

## La columna que justifica la vista

**"Lee antes de estar listo"**, en rojo. El motor falla en silencio cuando una fórmula lee algo que todavía no se calculó: devuelve cero y paga de menos **sin un solo error** ([[Orden de cálculo y precedencia]], [[acumuladores-orden-calculo]]).

Y para un **acumulador** el umbral no es su propio `Orden Cálculo` sino **el de su último aportante**: el acumulador existe desde el principio y devuelve un número, pero ese número sólo está completo cuando aportó el último. Confundir los dos es el error que esta vista viene a encontrar.

La columna *Orden en que el símbolo está listo* muestra ese umbral; *Orden de quien lo usa*, el del consumidor. Rojo cuando el segundo es menor que el primero.

> La corrección es mover el **productor hacia atrás**, no el consumidor hacia adelante: [[concepto-negativo-despues-de-sus-consumidores]].

## Cómo busca, y qué no es

Busca **por texto con los bordes marcados**: un símbolo cuenta cuando lo que lo rodea no es letra, dígito ni guion bajo. Sin eso, `DIAS` encuentra `DIAS_MAREA` y `1053` encuentra `10530`, y la lista deja de servir — es lo que pasa con un `LIKE '%X%'` a mano. El `#` y el `@` **sí** cuentan como borde: son parte de cómo se nombra a un concepto, no parte del nombre.

**No es un analizador.** Encuentra el nombre, no entiende la fórmula: un símbolo dentro de un literal, o un número suelto que coincide con un código, aparecen igual. El campo *Fragmento* está para juzgar eso sin abrir el objeto.

## Las dos casillas de la cabecera

- **Sólo vigentes** (prendida por omisión) — deja afuera las vigencias cerradas y las que todavía no arrancaron. El corte es **por fechas, nunca por `Activo`**: ese campo está marcado para quitar porque no tiene efecto en el cálculo, y hay 45 versiones de concepto con `Activo` en falso que siguen vivas. Filtrar por él esconde configuración real.
- **Incluir sufijos** (apagada por omisión) — relaja el borde derecho para encontrar `PRECIO_NAV_LAN` buscando `PRECIO_NAV`. Hace falta para un **parámetro**, que es el que se sufija ([[sufijo-que-no-distingue-nada]], [[parametros-somu-por-pesqueria]]). Con esto prendido, `DIAS` también encuentra `DIAS_MAREA`: es el precio.

## Desde dónde se abre

Acción **Dónde se usa** en: ficha y lista de conceptos, ficha y lista de fuentes de datos, lista de variables de sistema, ficha de parámetro y ficha de tipo de atributo. Desde la página se abre a mano escribiendo el símbolo.

## Relacionadas

- [[Orden de cálculo y precedencia]] — la regla que la columna roja vigila
- [[Acumuladores y fracciones]] — por qué el umbral de un acumulador es su último aportante
- [[Controles y avisos del cálculo]] — el control de precedencia de fórmulas, que detecta lo mismo sobre liquidaciones ya calculadas
- [[Nombres de variables y conflictos]] — qué pasa cuando dos cosas se llaman igual
