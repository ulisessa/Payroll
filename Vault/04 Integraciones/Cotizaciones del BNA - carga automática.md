---
tipo: proceso
tema: integraciones
tags: [cotizaciones, bna, tipo-de-cambio, job-queue, httpclient]
fuente: [src/Codeunits/Cod110090.CotizacionesBNA.al, src/PageExtensions/PagExt110035.CotizacionesBNAExt.al, scripts/ImportarCotizacionesBNA.ps1, test/Codeunits/Cod110091.TestCotizacionesBNA.al]
actualizado: 2026-10-23
---

# Cotizaciones del BNA - carga automática

Trae del Banco Nación las cotizaciones de **billetes** (euro y dólar) a `Currency Exchange Rate`, con **Compra en el TC comprador** (`Relational Exch. Rate Amount`) y **Venta en el vendedor** (`Relational Adjmt Exch Rate Amt`). Qué TC usa cada concepto: [[que-tc-usa-cada-concepto]].

**Por qué existe.** Pegar valores a mano en la lista estándar iguala el vendedor al comprador (el `OnValidate` de la tabla), y el gap no es fijo: 50 en el dólar y 100 o 110 en el euro. La carga asigna los campos sin `Validate`.

**Fuente.** El botón "Descarga por rango de fechas" del BNA es un GET público, sin sesión ni token: `https://www.bna.com.ar/Cotizador/DescargarPorFecha?id=billetes&fechaDesde=dd/MM/aaaa&fechaHasta=dd/MM/aaaa&idMonedaDescarga=<id>` (12 euro, 22 dólar, 23 real). Verificado el 23/10/2026: 116 filas del USD de abril a octubre coinciden con el BNA. Los días sin cotización no se cargan; la liquidación toma la última fila con fecha menor o igual.

## Tres formas de usarlo

1. **Codeunit 110090 "Cotizaciones BNA" como tarea programada** (Job Queue Entry): `Parameter String` = `EUR;USD` y opcionalmente `DESDE=aaaa-mm-dd`; vacío = EUR y USD, cada una a partir del día siguiente a su última cotización cargada (sin ninguna, últimos 15 días); `DESDE=` fuerza el inicio y sirve para corregir días ya cargados.
2. **Acción "Traer cotizaciones del BNA"** en la lista "Tipos de cambio" (`PagExt110035`): a partir del día siguiente a la última cotización de cada moneda.
3. **`scripts/ImportarCotizacionesBNA.ps1`**: por SQL directo, para cargar un rango largo. Previsualiza por defecto; con `-Aplicar` escribe y hay que reiniciar el servicio (caché).

## Requisitos de puesta en marcha

- Extension Management → la extensión → **Permitir solicitudes HttpClient**.
- El service tier (mimir) tiene que salir a `www.bna.com.ar` (443). **No se probó desde el servidor**: sólo se bajó el CSV desde la PC de desarrollo.
- Crear la Job Queue Entry (codeunit 110090, recurrente, después de las 17:00, cuando el BNA publica el cierre).

Sólo EUR y USD: otra moneda corta con error (agregarla en `IdBna`).
