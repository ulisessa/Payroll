---
aliases: ["La veda es un atributo del buque"]
tipo: leccion
tema: parametros-atributos
tags: [leccion, parametros-atributos, project]
actualizado: 2026-10-04
---

# La veda es un atributo del buque

**En una frase:** la veda es una vigencia del atributo ART48 sobre el buque, no un estado ni una tabla; y la trampa de dejarla abierta

La veda se carga como **vigencia del atributo `ART48` sobre la entidad Buque**: `Vigencia
Desde` / `Vigencia Hasta` *son* el período. No hace falta tabla nueva ni estado nuevo —
`Atributo Entidad Liq.` ya acepta entidad Buque y ya tiene las dos fechas. La fuente de datos
`DIAS_VEDA_BUQUE` cuenta los días de esa vigencia que caen en la ventana, filtrando entidad
Buque, `{BUQUE}` y tipo `ART48` (campos 1, 2 y 3; las fechas son los campos 4 y 5).

**Tampoco hace falta cascadear nada a la tripulación.** La fórmula resuelve `{BUQUE}` y el
`MIN` contra los días de órdenes propios de cada tripulante ya deja afuera al que estuvo de
vacaciones, enfermo o de franco. Verificado en A14, enero 2026: el 00492 tenía `OR` todo el
mes (31 días), el 00627 `OR` hasta el 4/1 y `AU9` desde el 5/1 (4 días), el 04185 `AU1` todo
el mes (0 días) — y los tres coinciden clavado con Meta4. Copiar el estado a cada empleado
agrega una copia que se puede desincronizar y no compra nada.

**La trampa:** al insertar una vigencia nueva, `SincronizarContiguidad` cierra la anterior
que esté abierta en "inicio − 1". Para una veda eso significa que si no se la cierra cuando
termina, la veda vieja se estira hasta el día anterior a la próxima **y se come la temporada
de pesca del medio**. Hay que cerrarla; editar `Vigencia Hasta` alcanza, el `OnModify` valida
el intervalo y que no pise la siguiente.

**Por qué:** las fórmulas originales partían los días por un estado `VED` de `Estado Empleado`
con ámbito buque que no tenía ni una fila — y no había forma práctica de cargarlo. En Meta4 la
veda se lleva a mano: se para el buque (`M4T_HIST_EST_BUQUE`, estado `GP`) y se cargan los
días de órdenes de cada tripulante. Automatizarla era el punto.

Ver [[sueldo-ordenes-por-convenio]] y [[estado-empleado-effective-dated]].

## Relacionado

- [[parametro-y-atributo-mismo-nombre]]
- [[sindicato-obra-social-atributos]]
- [[tc-comprador-parametro-fantasma]]
- [[tipo-atributo-tres-campos-silenciosos]]
- [[un-valor-una-fuente]]
- Tema: `parametros-atributos` (ver [[_Convenciones del vault]])
