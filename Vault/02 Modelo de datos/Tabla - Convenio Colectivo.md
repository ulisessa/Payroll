---
tipo: tabla
tags: [modelo-datos, convenios-cct]
fuente: [src/Tables/Tab60004.ConvenioColectivo.al]
actualizado: 2026-10-04
---

# Tabla - Convenio Colectivo (60004)

## Propósito
Maestro de convenios (CCT 768/19, 729/15, 175/75, 372/04…). Es la **fuente de verdad** de los convenios: el convenio y la categoría de cada empleado *no* se guardan en la ficha sino como **atributos con historial** que espejan estas tablas (ver [[Tabla - Categoría CCT]] y [[atributos-tipados]]).

## PK
`Código` (Code[20]), clustered. DropDown: Código, Descripción, No. CCT.

## Campos
| Campo | Tipo | Propósito |
|---|---|---|
| `Código` / `Descripción` | Code[20] / Text[100] | Identificación |
| `No. CCT` (3) | Text[30] | Número oficial del convenio |
| `Sindicato` (4), `Cámara` (5), `Observaciones` (6) | Text | Informativos |
| `Tipo Empleado` (7) | Enum [[Enums de liquidación#Aplica A Liq]] | Población que encuadra: Tripulante / Mensualizado / Jornalizado. El filtro `Aplica A` de cada concepto se compara contra **esto**. Vacío ("Todos") = no filtra |
| `Cód. Calendario` (8) | Code[10] → `Base Calendar` | Calendario de feriados **de este convenio**; en blanco se usa el del período |

## TableRelations
`Cód. Calendario` → `Base Calendar`.

## Triggers
Los cuatro (OnInsert/OnModify/OnRename/OnDelete) delegan en el codeunit `Espejo Atributos Liq.` (`Cod50078`): `AlEscribirConvenio`, `AlRenombrarConvenio`, `AlBorrarConvenio`. Si existe un tipo de atributo con espejo `Convenio Colectivo` ([[Enums de liquidación#Espejo Atributo Liq]]), sus valores se mantienen desde acá; **el borrado se corta** si el valor espejo tiene historial (las vigencias quedarían nombrando un convenio inexistente). Sin atributo espejo configurado no hacen nada.

## Quién la lee
`Cod50014.MotorLiquidacion` (filtra conceptos por `Tipo Empleado`, resuelve feriados), `Cod50016.ContextoLiquidacion`, `Cod50080.ConvenioCategoriaLiq` (resolución del par), `Cod50018`, `Cod50078.EspejoAtributosLiq`. La referencian [[Tabla - Liquidación]], [[Tabla - Línea Liquidación]], [[Tabla - Parámetro Vigente]], [[Tabla - Concepto CCT Vigente]], [[Extensión - Employee]], `Tab110003 Tipo Atributo Liq.`, `Tab110012`, `Tab110038`, `Tab110045`. Página: `Pag50105 Convenios Colectivos`.

## Vigencias
Sin vigencia propia. La *pertenencia* de un empleado a un convenio sí tiene historial (atributo espejo).

## Trampas conocidas
> [!warning] El tipo de empleado es de la persona, no del día
> Antes salía del `Cód. Estado Empleado` del día; un tripulante de vacaciones cae en AU9 (compartido) y si AU9 dice "Todos" el motor no filtra nada y le entran conceptos de mensualizado (caso legajo 00191). Hoy se lee de acá.

> [!warning] Feriados por convenio, resueltos a la fecha de referencia
> Si alguien cambia de convenio a mitad de mes, todo el mes se cuenta con el convenio del cierre (caso raro, documentado). El 768/19 suma 8/9 de febrero y fija el 20/11; el 729/15 no.

Ver [[convenio-of-depende-de-la-categoria]], [[sindicato-obra-social-atributos]], [[puesto-vs-categoria-cct]].
