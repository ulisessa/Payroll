---
aliases: ["Rangos de ID que habilita la licencia"]
tipo: leccion
tema: desarrollo-al
tags: [leccion, desarrollo-al, reference]
origen: 6fef786a-9ac7-4101-a78d-2cb1c395ef37
actualizado: 2026-08-17
---

# Rangos de ID que habilita la licencia

**En una frase:** La licencia limita los IDs de objeto; Table corta en 60029 y el rango libre real es 110000-149999. El detalle está en "Objetos Custom - Numeración y Disponibilidad.xlsx"

Antes de elegir el ID de un objeto nuevo hay que mirar **`Objetos Custom - Numeración y Disponibilidad.xlsx`**, en la raíz del proyecto:

- Pestaña **"Rangos permitidos"** → lo que la LICENCIA habilita, por tipo de objeto.
- Pestaña **"Disponibilidad"** → lo que además está libre.

Lo que más muerde: **Table sólo llega hasta 60029**. Todo objeto de tipo tabla por encima de eso falla en runtime con *"los permisos actuales impidieron la acción. (Table NNNNN … Execute)"*, que parece un problema de permission set y no lo es — el set puede tener la tabla y el error aparece igual. Otros topes: Codeunit 50000-50099 y 50500-50585; Page 50000-50842 y varios bloques en 60000-70000; Report 50000-50101.

**El rango cómodo es 110000-149999**, habilitado y libre entero para Table, Page, Codeunit, Report, XMLport y Query.

**Enum, TableExtension, PageExtension y PermissionSet no figuran en la hoja porque no los controla la licencia**: ahí el ID es indiferente.

Ojo con el orden de las cosas: renumerar una tabla la dropea con sus datos (ver [[rad-json-removed-peligroso]]). Los buffers que sólo se usan declarados `temporary` no tienen tabla física con datos y se renumeran sin riesgo; una tabla con datos necesita exportar antes y reimportar después.

Rastro de que esto ya pasó: `Tab60031.TipoLiquidacion.al` declara por dentro `table 50578` — se movió al rango habilitado y el archivo quedó con el nombre viejo.

## Relacionado

- [[progreso-singleinstance-sucio]]
- [[rad-json-removed-peligroso]]
- [[report-sin-layout-compila]]
- [[setselectionfilter-tabla-temporal]]
- [[symbolos-final-version-tienen-fuente]]
- [[version-app-json-manual]]
- Tema: `desarrollo-al` (ver [[_Convenciones del vault]])
