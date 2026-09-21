# ADR-001: Modelo de firma digital para recibos de sueldo

**Estado:** Propuesto
**Fecha:** 2026-08-26
**Decisores:** Dirección, asesor laboral externo, responsable de RRHH, equipo de desarrollo BC

---

## Contexto

Se busca emitir recibos de sueldo digitales desde el módulo de liquidación (extensión AL
`Liquidación Sueldos Pesca`, BC 25.2 OnPrem) con la misma validez probatoria que ofrecen
plataformas como Humanage, TuRecibo o Intersoft.

### Hallazgo regulatorio que redefine el pedido original

No existe una "habilitación" que replicar. La **Resolución 346/2019** (Ministerio de
Producción y Trabajo) eliminó la autorización previa que otorgaba la Secretaría de Trabajo
bajo la Res. 1455/2011. Cualquier empleador puede emitir recibos digitales sin trámite
previo, cumpliendo condiciones técnicas.

Lo que esas plataformas tienen no es una licencia sino un **stack**: firma digital
respaldada por certificador licenciado (Ley 25.506), circuito de firma electrónica del
trabajador con trazabilidad, y capacidad de conservación y descarga.

### Requisitos funcionales que impone la Res. 346/2019

Válidos para cualquier opción que se elija:

1. Contenido conforme arts. 138, 139 y 140 LCT
2. Firma de ambas partes — empleador y trabajador
3. El trabajador debe poder **guardar y conservar copias** de sus recibos
4. El trabajador debe poder **firmar en disconformidad**

### Riesgo legal abierto

La Res. 346/2019 exige que el recibo esté "firmado digitalmente por ambos". Leído
literalmente requeriría certificado Ley 25.506 por empleado, lo cual es inviable
operativamente. La práctica de mercado — y la de los tres proveedores citados — es **firma
digital para la empresa y firma electrónica para el trabajador**, apoyada en que la carga
de la prueba recae sobre el empleador (art. 5, Ley 25.506).

Es defendible, pero **no es una opinión legal de este documento**. Requiere confirmación
del asesor laboral antes de construir. Es la única dependencia que puede invalidar el
proyecto entero.

### Jurisdicciones

Personal registrado en **Buenos Aires, Santa Cruz/Chubut y CABA**.

**SITRADIB no condiciona este proyecto.** El manual oficial del Sistema de Trabajo Digital
Bonaerense (Res. MTGP 147/24) no menciona la palabra "recibo" en todo su texto: alcanza
exclusivamente a la rúbrica de documentación laboral y a la presentación del libro del
art. 52 LCT. La integración con milegajo.com para recibos es una comodidad ofrecida por el
portal, no una obligación.

Sí es relevante por dos motivos indirectos:

- Su criterio de sujeto es amplio — *"todos los empleadores con domicilio legal y/o fiscal
  y/o que ocupen personal que preste servicios dentro de la provincia de Buenos Aires"* —
  con lo cual la parte bonaerense de la nómina arrastra a la empresa a la obligación del
  libro digital.
- Esa obligación **consume el mismo certificado de firma digital de la empresa**. El
  certificado que se contrate para recibos se amortiza también contra SITRADIB.

### Restricciones técnicas

- **AL no puede firmar PAdES.** No hay librería de firma de PDF en el lenguaje. La firma
  ocurre necesariamente fuera de BC; el rol de BC es orquestar y custodiar la evidencia.
- **No hay uso previo de `HttpClient` en este repositorio**, aunque sí hay precedente de
  integración saliente en la casa: la dependencia `WebServicesAFIP` (`Cod50513 "WS - AFIP"`)
  resuelve el login ticket de WSAA. Ver más abajo por qué ese precedente no es reutilizable.
- `target: OnPrem` habilita DotNet interop, pero usarlo clavaría la extensión a on-premise
  y trasladaría criptografía sensible al proceso del servicio de BC. Se descarta.
- El recibo ya existe (`Rep50041.ReciboDeSueldo`) con layout RDL, disparado desde
  `Pag50117.FichaLiquidacion`. El estado `Aprobada` de `Enum 50304 "Estado Liq."` es el
  disparador natural del circuito de firma.

### El precedente de WSAFIP: por qué no se reutiliza

La dependencia `WebServicesAFIP` ya firma con un certificado X.509. Es tentador reutilizarla y
conviene cerrar la puerta explícitamente, por dos motivos independientes.

**El certificado AFIP no sirve para firmar recibos.** El de WSAA es un certificado de sistema
que emite AFIP para autenticar una máquina contra sus web services. No lo emite un certificador
licenciado, no está vinculado a la identidad del representante legal y no encadena a la AC Raíz
de la infraestructura de firma digital. Un recibo firmado con él no produce firma digital en el
sentido de la Ley 25.506: produce un archivo criptográficamente firmado que no acredita quién
firmó. Ante una impugnación equivale a no tener nada.

**El toolchain tampoco alcanza.** `fntWSAA` arma un script PowerShell por concatenación de
strings, lo escribe a disco y shellea `openssl cms -sign` para firmar el TRA en PKCS#7.
`openssl` produce un CMS suelto; **no firma PDFs**. No genera el PAdES embebido con su
`ByteRange`, el diccionario de firma, el DSS ni el sello de tiempo. No le ahorra trabajo a la
Opción B.

Mirado como implementación de firma, ese código además tiene clave privada en texto plano en el
filesystem (ruta en `General Ledger Setup`), PowerShell generado interpolando configuración sin
escapar, `New-WebServiceProxy` —deprecado, inexistente en PS7—, archivos temporales de nombre
fijo que colisionan entre sesiones concurrentes, un busy-loop
`while not process.WaitForExit(10000) do;` y dependencia de que openssl esté instalado en el
servidor.

Para un login ticket que dura doce horas y falla ruidosamente, es tolerable: funciona hace años.
Para un recibo que debe resistir una impugnación cinco años después, no. **Es la evidencia
empírica del argumento de este ADR**: así es como sale la firma cuando se construye en casa.

Lo que sí conviene reutilizar es el **modelado**: el par `AFIP Interface Register` /
`AFIP Interface Register detail` —cabecera de interfaz con detalle y trazabilidad de qué campo
cambió y de qué valor a cuál— es casi exactamente la forma que necesitan `Documento Firmable` y
`Log Auditoría Firma`. Seguir ese precedente hace que el módulo se lea como el resto de la casa.

### Decisión previa ya tomada

El canal del empleado será un **portal web propio**. Esto condiciona la evaluación: las
opciones se juzgan por su capacidad de firma, no por el portal que traigan.

---

## Decisión

**Se propone la Opción A: firma digital remota vía API de certificador licenciado**, con la
integración encapsulada detrás de una interfaz AL que permita sustituir el proveedor sin
tocar el motor de liquidación.

---

## Opciones consideradas

### Opción A — API de certificador licenciado (firma remota)

Firma con custodia centralizada de claves, habilitada por la **Res. SIP 86/2020**, que
autoriza a los certificadores licenciados a prestar el servicio vía API. BC llama por
`HttpClient`, recibe el PDF firmado en PAdES con sello de tiempo y lo persiste.

| Dimensión | Evaluación |
|---|---|
| Complejidad | Media |
| Costo | Certificado + costo por documento o abono |
| Escalabilidad | Alta — sin intervención humana por documento |
| Familiaridad del equipo | Baja (primer `HttpClient` del repo) |
| Reversibilidad | Alta si se encapsula tras interfaz |

**A favor**

- Sin token físico: es la única opción de las dos propias que permite **firma masiva
  desatendida**, condición necesaria para el cierre mensual y los picos por marea.
- Sello de tiempo y PAdES-LTV provistos por el certificador — la firma sigue siendo
  verificable después de que el certificado caduque.
- La responsabilidad del acto de firma recae parcialmente en un tercero regulado.
- El certificado se reutiliza para SITRADIB.
- La evidencia queda en BC, no en un tercero.

**En contra**

- Costo variable atado al volumen de recibos.
- Dependencia de disponibilidad en tiempo de ejecución: si el certificador está caído, no
  se firma. Exige reintentos, idempotencia y una cola de pendientes.
- Requiere negociación contractual y SLA.
- Encode emite certificados por software y por token; Lakaut, Box Custodia y Digilogix
  **sólo por token**. El universo de proveedores viables para este modelo es más chico de
  lo que sugiere la lista de licenciados.

### Opción B — Token/HSM propio + microservicio .NET

Certificado en poder de la empresa y un servicio .NET propio (iText7 + BouncyCastle) que
firma PAdES y expone un endpoint a BC.

| Dimensión | Evaluación |
|---|---|
| Complejidad | Alta |
| Costo | Certificado + HSM + desarrollo + hosting + mantenimiento |
| Escalabilidad | Alta con HSM; nula con token físico |
| Familiaridad del equipo | Baja — criptografía de firma de documentos |
| Reversibilidad | Baja: la evidencia depende de la implementación propia |

**A favor**

- Sin costo por documento. A volumen muy alto es la opción más barata en marginal.
- Control total del circuito, sin dependencia de terceros en tiempo de ejecución.
- Puede operar íntegramente on-premise.

**En contra**

- **El token físico no es automatizable.** Firmar cientos de recibos exige un HSM, cuyo
  costo y operación borran buena parte de la ventaja económica.
- **Igual hay que contratar una TSA externa** para el sello de tiempo: la dependencia de
  terceros no desaparece, sólo se mueve.
- Concentra el riesgo legal en código propio. Una implementación PAdES defectuosa no falla
  ruidosamente: produce recibos que parecen firmados y se caen recién cuando alguien los
  impugna, potencialmente años y miles de documentos después. Es el modo de falla de mayor
  consecuencia y menor visibilidad de las tres opciones.
- Custodia de claves, rotación y auditoría pasan a ser responsabilidad interna.

### Opción C — Integrar con plataforma existente

BC genera el PDF y lo exporta a milegajo, Humanage, TuRecibo o similar, que resuelve firma
y portal.

| Dimensión | Evaluación |
|---|---|
| Complejidad | Baja para la firma; alta en integración de datos |
| Costo | Abono recurrente por empleado/mes |
| Escalabilidad | Alta, provista |
| Familiaridad del equipo | N/A |
| Reversibilidad | Muy baja — lock-in de datos y de evidencia |

**A favor**

- Menor desarrollo propio y riesgo legal delegado a un proveedor con recorrido.
- Circuito probado, con soporte y actualizaciones regulatorias incluidas.

**En contra**

- **Contradice la decisión ya tomada de portal propio.** Se pagaría una plataforma completa
  para usar sólo su módulo de firma. Si se usara únicamente su API de firma, converge
  funcionalmente con la Opción A pero a mayor costo.
- La evidencia probatoria vive fuera de BC, en poder de un tercero comercial.
- Costo recurrente por empleado que crece con la nómina.
- La integración de datos hay que construirla igual.

---

## Análisis de trade-offs

La diferencia real entre A y B no es tecnológica sino **dónde vive la clave privada y quién
responde por el acto de firma**. C se juega en otro eje: **quién es dueño del circuito y de
la evidencia**.

Tres razonamientos deciden:

1. **C queda descartada por coherencia interna.** Con el portal propio ya definido, C
   duplica capacidad y desplaza la evidencia fuera de BC. Su versión reducida —usar sólo la
   API de firma— es la Opción A con otro proveedor y peor precio.

2. **La ventaja económica de B es en gran medida aparente.** El token obliga a HSM para
   automatizar, y la TSA hay que contratarla igual. Se paga infraestructura y desarrollo
   para terminar con la misma dependencia externa que en A.

3. **A y B no fallan igual de mal.** El peor escenario de A es una caída del proveedor:
   ruidosa, inmediata, recuperable con una cola de reintentos. El peor escenario de B es
   una firma mal construida: silenciosa, diferida y potencialmente masiva. No es una
   hipótesis: `Cod50513 "WS - AFIP"` muestra cómo termina la firma construida en casa
   cuando nadie la audita.

El costo por documento de A es el precio de transferir ese riesgo a un tercero regulado.
A la escala de una empresa pesquera, es un buen negocio.

---

## Consecuencias

**Se vuelve más fácil**

- Automatizar el cierre mensual y absorber los picos por marea sin intervención manual.
- Reutilizar el certificado para la obligación SITRADIB del libro de sueldos.
- Mantener la cadena probatoria completa dentro de BC.

**Se vuelve más difícil**

- BC pasa a tener una dependencia externa en tiempo de ejecución, con todo lo que implica:
  reintentos, idempotencia, timeouts, cola de pendientes y monitoreo.
- Aparece un costo operativo recurrente atado al volumen.
- El proceso por lotes debe **recolectar las claves antes de iterar**, no filtrar por el
  campo que se está modificando.

**Habrá que revisar**

- Si el volumen crece mucho, renegociar tarifa o reevaluar B con HSM.
- Si el asesor laboral rechaza la firma electrónica para el trabajador, todo el circuito del
  empleado cambia y hay que reabrir este ADR.

**Riesgo abierto no resuelto por esta decisión**

Se optó por portal web propio como único canal del empleado. **La tripulación embarcada no
tiene conectividad durante la marea.** Un recibo que no se puede firmar hasta el regreso a
puerto deja un hueco en el circuito justo en el grupo más numeroso de la nómina. Hay que
definir el mecanismo offline o presencial antes de implementar, o el portal quedará
resolviendo sólo al personal de tierra.

---

## Acciones

1. [ ] **Bloqueante** — Obtener la opinión del asesor laboral sobre firma electrónica del
       trabajador. Nada más se construye sin esto.
2. [ ] Relevar la dotación total y su distribución por jurisdicción, para dimensionar
       volumen y negociar tarifa.
3. [ ] Definir el circuito de firma para tripulación embarcada sin conectividad.
4. [ ] Pedir cotización a al menos dos certificadores licenciados. Preguntar
       específicamente: API REST, PAdES-B-LT, sello de tiempo incluido, SLA de
       disponibilidad, escalones de precio por volumen y entorno de sandbox.
5. [ ] Verificar si el certificado cotizado sirve también para SITRADIB.
6. [ ] Diseñar la interfaz AL de firma (patrón `interface` + implementaciones) para que el
       proveedor sea sustituible.
7. [ ] PoC: firmar un recibo real de punta a punta y validar la firma con un verificador
       independiente.
8. [ ] Recién entonces, diseñar el modelo de datos de evidencia y el portal.

---

## Fuentes

- [Resolución 346/2019 — Boletín Oficial](https://www.boletinoficial.gob.ar/detalleAviso/primera/207708/20190517)
- [Se podrán emitir recibos de sueldo con firma digital — Argentina.gob.ar](https://www.argentina.gob.ar/noticias/se-podran-emitir-recibos-de-sueldo-con-firma-digital)
- [Ley 25.506 de Firma Digital — InfoLeg](https://servicios.infoleg.gob.ar/infolegInternet/anexos/70000-74999/70749/norma.htm)
- [Normativa de Firma Digital Remota — Argentina.gob.ar](https://www.argentina.gob.ar/jefatura/innovacion-publica/innovacion-administrativa/firma-digital/plataforma-de-firma-digital-3)
- [Certificadores Licenciados — Argentina.gob.ar](https://www.argentina.gob.ar/jefatura/innovacion-ciencia-y-tecnologia/innovacion/firma-digital/certificadores-licenciados)
- [Manual de usuario SITRADIB — CPBA](https://www.cpba.com.ar/ipit/Materiales/MA60004345.pdf)
- [SITRADIB: las otras exigencias además de la firma digital — Contadores en Red](https://contadoresenred.com/sitradib-las-otras-exigencias-ademas-de-la-firma-digital-y-un-sistema-de-sueldos-que-ya-esta-preparado/)
