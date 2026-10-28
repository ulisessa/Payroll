---
aliases: ["La final ajusta el estado de Francos al último día"]
tipo: leccion
tema: francos
tags: [leccion, francos, project]
actualizado: 2026-10-20
---

# La final ajusta el estado de Francos al último día

en una liquidación final el saldo de francos se compara con el último día de la relación, no con el fin del mes

> [!warning] `AjustarEstadoFrancos` corta el estado de Francos el día que se acaba el saldo, pero sólo si encuentra un Francos vigente en la fecha que se le pasa. La final de un empleado dado de baja a mitad de mes se lo pasaba con el fin del período: a esa fecha el estado ya es la baja y no hacía nada.

Marzo de 2026: 04020 (baja 13/3, Francos del 1 al 13, saldo 12) y 04185 (baja 10/3, Francos desde el 25/2, saldo 11). Sus finales fallaban con "La matriz pide 13 días de franco y faltan 1" y "pide 10 y faltan 3". Meta4 paga los días que cubre el saldo (`DIAS_FRANCO` 12 y 7 en marzo, 11 en total para 04185) y el resto como Órdenes.

## Qué se cambió (20/10/2026)

`FasePrepararCabecera` (Cod50014) llama a `AjustarEstadoFrancos` con `FechaAtributos` —el último día de cobertura en una `LIQ_FINAL`, el fin del período en las demás— en vez de `FechaRef`. Con eso el ajuste materializa el `Estado Siguiente` el día en que se acaba el saldo y `DIAS_FRANCOS_PERIODO` cuenta sólo los días cubiertos.

Ver [[francos-fifo-ledger]] y [[cuando-corresponde-una-liquidacion]].

## Qué queda distinto de Meta4 y es correcto en BC (20/10/2026)

Con el ajuste, 04020 y 04185 calculan sin errores y coinciden con Meta4 en francos, vacaciones no gozadas y su SAC. Lo que difiere viene de que **Meta4 paga lo que se le carga como incidencia, no lo que dicen los estados**:

- 04185: los 3 días de Órdenes (8 al 10/3) los paga BC como 1076 (70.289, y +8.434 en la antigüedad); Meta4 no los pagó porque nadie cargó la incidencia (`DIAS_FRANCO` 4 en febrero y 7 en marzo, nada más). Un estado activo con precio se paga.
- 04020: el día de Órdenes (13/3) lo paga BC como 1076 (23.429); Meta4 lo pagó como puerto (incidencia `DIAS_PUERTO` 1 → 67.749). Cambia el precio del día, no que se pague.
- El SAC de egreso (3813) difiere unos pesos (−3.693 y +6.560) por esos mismos días.

El historial de estados de Meta4 de los dos termina en Francos hasta la baja: nunca tuvo el estado de Órdenes.
