---
aliases: ["Tipo Atributo: tres campos silenciosos"]
tipo: leccion
tema: parametros-atributos
tags: [leccion, parametros-atributos, feedback]
actualizado: 2026-10-04
---

# Tipo Atributo: tres campos silenciosos

> [!warning] Falla en silencio
> Cód. Clase, Nombre Variable y Obligatorio de un Tipo Atributo Liq. parecen decorativos y cada uno apaga algo distinto

Al crear un `Tipo Atributo Liq.` por SQL es fácil dejar tres campos en blanco y que "funcione":
el atributo resuelve, el cálculo da bien, ningún error. Cada uno apaga algo que no se ve.

- **`Cód. Clase`** (`EMPLEADO`, `BUQUE`…): `PlantillaAtributosLiq` filtra por clase. En blanco,
  el tipo **no aparece** en los atributos de la entidad: sólo se puede cargar por SQL.
- **`Nombre Variable`**: no es sólo para que una fórmula lea el número. `Cod50016.LoadAtributos`
  además llama a `GuardarValorTexto`, y **eso** es lo que hace que el valor quede en el resumen
  de variables de la liquidación. Sin nombre, el atributo puede decidir un importe sin dejar
  rastro en el recibo ni en la página de detalle del cálculo.
- **`Obligatorio`**: con 1, `PlantillaAtributosLiq` le crea una vigencia a toda la clase. Va en 0
  cuando el atributo es legítimamente opcional y algo depende de su ausencia — `PUESTO` está en
  0 porque 42 activos no tienen puesto en Meta4 y su fallback es no tener vigencia.

**Por qué:** los tres se completan solos al crear el tipo desde la página, así que el hueco aparece
sólo cuando la carga se hace por SQL, que es como se hacen las migraciones.

**Cómo aplicarlo:** después de crear un tipo por SQL, compararlo contra los que ya existen
(`SELECT Código, Cód_ Clase, Nombre Variable, Obligatorio, Espejo De`) y justificar cada
diferencia. Ver [[atributos-tipados]] y [[puesto-vs-categoria-cct]].

**Y un cuarto: `Cód. Tipo Atributo Padre`.** Cuando los VALORES del atributo cuelgan de otro
—la categoría del CCT cuelga del convenio, porque `OF01` existe en 175/75 y en 768/19— el tipo
tiene que declarar de quién cuelga. Sin eso, `ValorPadreVigente()` (Tab110005) devuelve vacío,
el lookup del valor filtra por `Cód. Valor Padre = ''` y **la lista sale vacía**: no se puede
asignar ningún valor desde la página.

Pasó el 18/9/2026 con `PUESTO`: los 97 valores estaban cargados y las 9.809 vigencias también,
pero el tipo no declaraba `CONVENIO` como padre y en pantalla no aparecía nada. El síntoma no
dice "falta el padre", dice "no hay valores".

Se arregla con `Cód. Tipo Atributo Padre = 'CONVENIO'`. Antes de ponerlo conviene verificar que
el padre YA guardado en cada vigencia coincida con el que `ValorPadreVigente()` va a recalcular
—el convenio del empleado a la fecha de inicio de esa vigencia— porque si no, el valor cambia
solo en cuanto alguien edite la fila.

## Relacionado

- [[parametro-y-atributo-mismo-nombre]]
- [[sindicato-obra-social-atributos]]
- [[tc-comprador-parametro-fantasma]]
- [[un-valor-una-fuente]]
- [[veda-como-atributo-del-buque]]
- Tema: `parametros-atributos` (ver [[_Convenciones del vault]])
