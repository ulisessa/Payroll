---
aliases: ["Una part con Visible no se estira"]
tipo: leccion
tema: ui-controles
tags: [leccion, ui-controles, reference]
actualizado: 2026-10-04
---

# Una part con Visible no se estira

**En una frase:** una ListPart con Visible dinámico queda con el alto mínimo; con Enabled se estira igual que las demás

Una `part()` con **visibilidad dinámica** (`Visible = UnaVariable`) **no la estira el cliente**: queda
con el alto mínimo y scroll propio, dejando media pantalla vacía debajo. Con `Enabled` en lugar de
`Visible`, la misma part se abre a toda la altura disponible.

Se ve comparando dos páginas del proyecto que son **estructuralmente idénticas** —`PageType = Card`,
un `group(General)` y la part suelta como último elemento del `area(Content)`—:

- `Pag50138.ParametroCard` → part sin `Visible`, abre con la lista a toda la altura.
- `Pag110008.FichaTipoAtributo` → part con `Visible = EsLista`, abre con 11 filas y scroll. Con
  CATEGORIA o PUESTO, que tienen 101 valores cada uno, es inusable.

Cambiado a `Enabled = EsLista` el 2/10/2026, que además es lo que ya hacían los otros cuatro
controles de esa misma página.

**Lo que NO es la causa, para no volver a buscar ahí**: AL efectivamente no tiene ninguna propiedad
de alto para una part —no hay `Rows` ni `Height`; las propiedades son ApplicationArea, Caption,
Editable, Enabled, ProviderId, ShowFilter, SubPageLink, SubPageView, UpdatePropagation y Visible—, y
la part ya estaba en la posición correcta. Que no exista la propiedad no significa que no se pueda
hacer nada: **ante una part que no se estira, lo primero es comparar sus propiedades con las de otra
que sí lo hace**, no concluir que es un límite de la plataforma.

## Relacionado

- Tema: `ui-controles` (ver [[_Convenciones del vault]])
