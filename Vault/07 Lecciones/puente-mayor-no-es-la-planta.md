---
aliases: ["El Puente Mayor no es la planta"]
tipo: leccion
tema: estados-fases
tags: [leccion, estados-fases, project]
origen: 7aa458fa-440c-4ba2-a50b-60d4d7167eea
actualizado: 2026-10-02
---

# El Puente Mayor no es la planta

**En una frase:** PM en Meta4 es el buque Puente Mayor, no la planta PPM; cinco tripulantes quedaron liquidados sobre un proyecto de planta

**`PM` en Meta4 es el buque Puente Mayor** —un arrastrero/merlucero de Arbumasa, parado en
reparación—, **no** `PPM`, que en BC es la Planta de Proceso de Puerto Madryn. Dos códigos parecidos
para cosas distintas, y la migración los unió: en enero de 2026 hay 8 liquidaciones de Meta4 en PM,
de **5 empleados** —04495, 04703, 04888, 04916 y 04920, todos 729/15— que en BC quedaron con sus
estados y su liquidación sobre `PN-PPM-NOMINA`.

Eso explica el `TIPOACTIVIDAD = PA (Planta)` que apareció cargado sobre PPM con vigencia 1/1/2026:
se puso para que esos casos resolvieran algo, no porque la gente estuviera en la planta.

**La pesquería sólo recorta al tangonero.** El 70/30 es exclusivo del LAN: el potero (CAL) y el
merlucero pagan el valor pleno para el mismo par convenio+categoría. Por eso `COEF_PESQUERIA` queda

```
IF(TIPOACTIVIDAD = 0, IFZERO(COEF_TANGONERO, 1), 1)
```

y no un CASE por pesquería: sólo el tangonero tiene coeficiente, todo lo demás paga entero. La
fórmula vieja era binaria —`IF(TIPOACTIVIDAD = 1, COEF_POTERO, COEF_TANGONERO)`— y cualquier cosa que
no fuera potero caía en el coeficiente del tangonero **por descarte**, incluido el merlucero y la
planta.

Valores de `TIPOACTIVIDAD`: TA=0 Tangonero, PO=1 Potero, FA=2 Administración, PA=3 Planta,
**ML=4 Arrastrero/Merlucero** (agregado el 2/10/2026).

**Trampa de vigencia**: el atributo del buque nuevo se cargó con vigencia del día (2/10/2026) y los
atributos se resuelven a la fecha de CADA liquidación, así que para enero el buque no tenía pesquería
y `TIPOACTIVIDAD` volvía cero —el código del tangonero—. Se retrotrajo a 2023-01-01, igual que los
otros doce. Es la misma trampa que con los lotes de franco del 31/12/2025.

También faltaba el atributo **`PROY_NOMINA`** de MAY (los doce buques lo tenían): sin él
`ProyectoNominaDe` no puede mandar a nadie a `PN-MAY-NOMINA`. Cargado el 2/10/2026.

**Pendiente**: mover los estados de los cinco de `PN-PPM-NOMINA` a `PN-MAY-NOMINA`. Abarcan de
octubre de 2025 a mayo de 2026, así que hay que saber desde cuándo corresponde el Puente Mayor y no
sólo que en enero estuvieron ahí. Ver [[proyecto-nomina-dos-fuentes]] y
[[valor-franco-por-terna]].

## Relacionado

- [[job-tipo-cero-no-bloquea]]
- [[nomina-no-es-intervalo-presencia]]
- [[novedad-proyecto-sale-del-estado]]
- [[proyecto-nomina-dos-fuentes]]
- [[recorrer-estado-abierto-dia-por-dia]]
- [[tres-capas-fase-estado-asignacion]]
- Tema: `estados-fases` (ver [[_Convenciones del vault]])
