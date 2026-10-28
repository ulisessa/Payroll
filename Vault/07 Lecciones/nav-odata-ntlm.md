---
aliases: ["NAV OData pide NTLM"]
tipo: leccion
tema: integracion-nav
tags: [leccion, integracion-nav, reference]
origen: 9185b3df-1c53-44a4-a540-9174e99644c1
actualizado: 2026-09-12
---

# NAV OData pide NTLM

**En una frase:** El OData de NAV pide NTLM y AL no lo habla; qué hay publicado de verdad (DetalleDescargas y el Change Log) y por qué el documento de servicio engaña

El "NAV" de Arbumasa es técnicamente **Business Central 14** (Spring 2019), no NAV 2018:
`Get-NAVServerInstance` devuelve `MicrosoftDynamicsNavServer$Navision`, versión **14.0.49811.0**
(verificado 12/9/2026). Funcionalmente es 2013R2 porque la aplicación es la vieja convertida — de
ahí que exista `/ODataV4/`, que 2013R2 no tenía.

**Eso cambia dónde están las herramientas:** el módulo de administración NO está en
`C:\Program Files\Microsoft Dynamics NAV\...` sino en
`C:\Program Files\Microsoft Dynamics 365 Business Central\140\Service\NavAdminTool.ps1`. Buscarlo
bajo "Microsoft Dynamics NAV" da "no valid module file was found", que no dice nada sobre la causa.

Endpoints:

- OData V4 — `https://nav.arbumasa.com:7048/Navision/ODataV4/Company('Arbumasa%20S.A.')/<entidad>`
- OData V3 — `https://nav.arbumasa.com:7048/Navision/OData/Company('Arbumasa%20S.A.')/<entidad>`
- SOAP — `https://nav.arbumasa.com:7047/Navision/WS/Arbumasa%20S.A./Page/<entidad>`

**`WWW-Authenticate: NTLM`** (verificado 11/9/2026). El `HttpClient` de AL hace Basic y bearer,
**no hace NTLM ni Kerberos**. La salida NO es cambiar el credential type de la instancia de
producción —eso afectaría a todos los usuarios— sino **levantar una segunda instancia de service
tier sobre la misma base, con `NavUserPassword`, publicando sólo OData/SOAP**. Es el patrón
estándar y deja la instancia actual intacta.

**EL DOCUMENTO DE SERVICIO DE V4 MIENTE: devuelve CERO entity sets.** Los endpoints funcionan igual
si se los pide por nombre. Enumerar el V4 y concluir "no existe" fue el error que hizo creer durante
días que no había endpoint de descargas. Para saber qué hay publicado hay que mirar el documento de
servicio **de V3**, que sí los lista (36 entity sets), o la tabla `Web Service` por SQL.

**`DetalleDescargas` existe y alcanza** (verificado 12/9/2026 en V4, con `$top=1` y datos reales).
Es una Query que junta cabecera y línea en una fila plana:

- De cabecera trae todo menos **`Pallets desde` / `Pallets hasta`**.
- De línea no falta nada (remito, pallet, tara, `Gross_Tare`, temperatura, pesaje, familia,
  subfamilia, los dos manuales).
- `Marea` viene como el código de 6 dígitos directo (`000125`), `Registrado` como Boolean de verdad.
  `Confirmed` y `Status` vuelven como texto de opción, no como ordinal.
- Clave: `AuxiliaryIndex1` + `N_proyecto` + `Line_no`.
- En **V3** `?$top=N` da **400** sobre esta Query (sólo contesta con `$filter`); en **V4** `$top`
  anda bien y devuelve JSON. Usar V4.

**`MovRegistroCambios` sirve de marca de agua Y detecta bajas.** `Entry_No` es monótono (iba por
14.561.571 el 11/9/2026), acepta `$orderby=Entry_No desc`, y trae `Date_and_Time`, `Table_No`,
`Primary_Key_Field_N_Value` y `Type_of_Change`. Registra **un movimiento por campo**, así que es
verboso, pero como reloj sobra.

**Y las tres tablas que importan están registradas** (verificado 12/9/2026):

| Tabla | Último movimiento |
|---|---|
| 167 Proyecto | Entry_No 14416269, 11/9/2026 |
| 50561 Cab. descarga | Entry_No 14237815, 10/9/2026 |
| 50562 Lín. descarga | Entry_No 14211727, 10/9/2026 |

O sea que el camino WS es **viable de punta a punta**: campos, reloj incremental y bajas. Lo que
falta decidir es la segunda instancia para la autenticación, y qué hacer con `Pallets desde/hasta`.

`ListaProyectos` alcanza para `Stg Proyecto NAV`, con dos trampas: `Status` y `Tipo` vuelven como
**caption localizada** ("Pedido", "Improductivo") y el staging los espera Integer; y
`Global_Dimension_2_Code` trae la actividad — la marea está en la dimensión 3, ver
[[dim2-nav-actividad-bc-marea]].

(`DescBuquePorMes` es un agregado mensual de 9 columnas; `DescBuquePorMes2` es de impuestos;
`DiarioAbordoxFecha` vuelve vacío; `MovProductosCajas` es inventario.)

Buques: `HF801`/`HF802` son los **Huafeng**, buques reales con mareas propias (no plantas).

Relacionado: [[migracion-estados-meta4]], [[ares-topologia-bc]], [[dim2-nav-actividad-bc-marea]].

## Relacionado

- [[sincronizacion-valores-dimension]]
- [[transporte-ws-sincronizacion]]
- Tema: `integracion-nav` (ver [[_Convenciones del vault]])
