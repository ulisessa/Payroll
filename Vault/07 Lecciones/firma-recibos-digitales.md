---
aliases: ["Firma de recibos digitales"]
tipo: leccion
tema: firma-recibos
tags: [leccion, firma-recibos, project]
origen: bf12e952-7c0b-4af0-a657-fd82f3078d3e
actualizado: 2026-08-26
---

# Firma de recibos digitales

No hay habilitación que tramitar para recibos digitales; SITRADIB es sólo libro de sueldos; AL no puede firmar PAdES

Módulo de recibos de sueldo digitales (ADR-001, propuesto el 26/8/2026, en `ADR_001_FIRMA_DIGITAL_RECIBOS.md`).

Tres hechos que se investigaron y conviene no volver a investigar:

1. **No existe habilitación previa.** La Res. 346/2019 eliminó la autorización de la Secretaría de Trabajo que exigía la Res. 1455/2011. Humanage, TuRecibo e Intersoft no tienen una licencia que replicar, tienen un stack. Lo que sí exige la 346/2019: contenido arts. 138-140 LCT, firma de ambas partes, que el trabajador pueda conservar copias y que pueda firmar en disconformidad.

2. **SITRADIB (Res. MTGP 147/24, Buenos Aires) no alcanza a los recibos.** El manual oficial no menciona la palabra "recibo" ni una vez: es rúbrica de documentación laboral y libro del art. 52 LCT. La integración con milegajo.com es opcional. Importa igual porque su criterio de sujeto es amplio (domicilio legal, fiscal *o* personal prestando servicios en PBA) y porque consume el mismo certificado de firma digital.

3. **AL no puede firmar PAdES.** No hay librería de firma de PDF en el lenguaje, así que la firma ocurre sí o sí fuera de BC. Ese es el hecho que genera las opciones del ADR, no una preferencia de diseño. DotNet interop está disponible por ser `target: OnPrem` pero se descartó: clava la extensión a on-premise y mete criptografía sensible en el proceso del servicio.

4. **El certificado de WSAFIP no se puede reutilizar.** El de WSAA es un certificado de sistema que emite AFIP para autenticar una máquina contra sus web services: no lo emite un certificador licenciado, no está atado a la identidad del representante legal y no encadena a la AC Raíz de firma digital. Firmar un recibo con él no produce firma digital Ley 25.506. Y `openssl cms -sign`, que es lo que usa `fntWSAA` en `Cod50513 "WS - AFIP"`, produce un CMS suelto — **openssl no firma PDFs**, no genera el PAdES embebido con ByteRange, DSS y sello de tiempo.

Decisión propuesta: firma remota vía certificador licenciado (Res. SIP 86/2020), encapsulada tras una interfaz AL para poder cambiar de proveedor. Ojo: Lakaut, Box Custodia y Digilogix emiten certificado sólo por token; Encode también por software, que es lo que permite automatizar.

Para el modelo de datos vale seguir el precedente de `AFIP Interface Register` / `AFIP Interface Register detail`: cabecera de interfaz con detalle y trazabilidad campo/valor anterior/valor nuevo. Es la forma que necesitan `Documento Firmable` y `Log Auditoría Firma`.

**Riesgo abierto:** la 346/2019 dice "firmado digitalmente por ambos". Aplicarlo literal exigiría certificado por empleado. Se asume firma electrónica para el trabajador, como hace el mercado, pero falta el visto del asesor laboral y es bloqueante.

**Riesgo abierto:** se eligió portal web propio como único canal del empleado, y la tripulación embarcada no tiene conectividad durante la marea. Falta definir el circuito offline.

Al implementar el proceso masivo, aplica [[bucle-modifica-campo-filtrado]]. El disparador natural del circuito es el estado `Aprobada` de `Enum 50304 "Estado Liq."`.

## Relacionado

- [[bucle-modifica-campo-filtrado]]
