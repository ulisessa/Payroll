---
aliases: ["Vacío en Tipos Liq. Aplicables es comodín"]
tipo: leccion
tema: motor-calculo
tags: [leccion, motor-calculo, project]
actualizado: 2026-10-04
---

# Vacío en Tipos Liq. Aplicables es comodín

> [!warning] Falla en silencio
> 185 conceptos no declaran tipo y por eso corren en todos; cada tipo extra duplica el recibo entero, no sólo su concepto

`Concepto Liquidación."Tipos Liq. Aplicables"` es una **lista blanca donde vacío significa
TODOS**, y **185 conceptos activos lo tienen vacío**. Consecuencia: cualquier tipo de
liquidación que se cree de más no duplica su concepto — **duplica el recibo entero**.

En enero de 2026, 133 empleados cobraron dos veces el SAC devengado, la ART, las contribuciones
patronales, la jubilación, la cuota sindical, el acuerdo del Dto 633/18, el art. 48 y hasta
Ganancias: una vez en su Regular y otra en su Vacaciones. El síntoma que se ve es "las
vacaciones se pagan dos veces", y es apenas uno de los diecinueve conceptos.

**En Meta4 una corrida de vacaciones paga UN devengo**, `VACACIONES`, más `REDONDEO` — y
`AC_SIND_EXEN_MT` en 58 de 354 corridas. Nada del recibo mensual. Los `TP_IMPUT` lo separan:
3 = corrida de vacaciones, 1 = mensual, y ningún empleado cobra vacaciones en las dos.

**El modelo no permitía decir "en este tipo corren SOLAMENTE estos"** sin tocar los 185. Por eso
`Tipo Liquidación."Sólo Conceptos Declarados"`: marcado, el tipo corre únicamente los conceptos
que lo nombran y el vacío deja de ser comodín. Cinco asignaciones en vez de ciento ochenta y
cinco. La pantalla para asignarlos ya existía: *Conceptos por Tipo de Liquidación*.

**Encenderlo con la lista incompleta deja de pagar cosas**, así que el flag no se siembra
prendido: primero se asignan los conceptos, después se marca.

Ver [[lote-tipo-liq-en-blanco]] y [[cuando-corresponde-una-liquidacion]].

**`Sólo Conceptos Declarados` NO va junto con el reparto por tramos.** Son dos modelos de reparto
incompatibles y mezclarlos pierde plata: la liquidación de Vacaciones se queda con los días —27
contra 4 de la Regular— pero no paga los conceptos de esos días, y la Regular no los ve porque no
son suyos. En enero de 2026 eso dejó **18 conceptos sin pagar**, entre ellos 52 millones de 3553,
el sueldo de franco de quien tenía los francos dentro del tramo de vacaciones, y la antigüedad a
la mitad en 29 empleados.

**Con los tramos alcanza**: cada liquidación paga todos los conceptos sobre *sus* días, y como
ningún día pertenece a dos, nada se duplica. Los únicos que no se pueden repartir por días son los
que usan `DIAS_VAC_INICIO` —el art. 155 de la LCT hace cobrar el intervalo entero si empieza en el
mes— y ésos van por [[exclusividad-vacaciones]].

El campo queda en la tabla, apagado: sirve para un tipo que pague una cosa puntual y no compita
por días con nadie. Vacaciones no era ese caso.

**Al 2/10/2026 el flag está PRENDIDO en `VACACIONES` y en `ANTICIPO`** (los otros ocho tipos en
cero). O sea: la nota de arriba ya no describe el estado de la base, y en esos dos tipos **vacío
NO es comodín — es exclusión**. Hay que mirarlo antes de concluir que un concepto "corre en
todos".

Así se perdió el 8553 (centro de capacitación) en la liquidación de Vacaciones de enero: lista
vacía, tipo en lista blanca, **ninguna línea y ningún aviso**. El motor no registra nada cuando
`ConceptoAplicaATipoLiq` devuelve false (Cod50014:1085), así que el informe de avisos tampoco lo
delata. El único síntoma es un concepto que falta en el recibo.

## Relacionado

- [[lote-tipo-liq-en-blanco]]
- [[novedad-con-proyecto-queda-huerfana]]
- [[novedad-en-cero-no-apagaba-el-concepto]]
- [[novedad-estado-apunta-a-proyecto-sin-liquidar]]
- [[novedad-tipo-liq-y-fecha-se-pelean]]
- [[novedades-pre-liquidacion]]
- Tema: `motor-calculo` (ver [[_Convenciones del vault]])
