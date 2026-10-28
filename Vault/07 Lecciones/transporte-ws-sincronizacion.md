---
aliases: ["Transporte WS de la sincronización"]
tipo: leccion
tema: integracion-nav
tags: [leccion, integracion-nav, project]
origen: 9185b3df-1c53-44a4-a540-9174e99644c1
actualizado: 2026-09-13
---

# Transporte WS de la sincronización

**En una frase:** La sincronización NAV→BC tiene dos transportes (SQL y Web Services); qué hizo falta del lado de NAV y las trampas que sólo aparecen por OData

**Construido el 12-13/9/2026.** La sincronización NAV→BC ahora tiene **dos transportes**, elegibles por empresa en `Config Sinc NAV`. Los dos llenan **las mismas tablas de staging** y el que aplica sobre `Job`, `Employee` y las descargas sigue siendo `Sinc NAV Liq.`, así que se cambia de uno al otro sin migrar datos.

| | SQL (linked server) | Web Services (OData V4) |
|---|---|---|
| Reloj | rowversion por tabla | `Entry_No` del Change Log |
| Detecta bajas | **no** | sí |
| Infraestructura | linked server | segunda instancia de service tier |

**LA MARCA DE AGUA SIGNIFICA COSAS DISTINTAS EN CADA UNO.** Cambiar de transporte sin vaciarla no da error: un rowversion (~17.500 millones) leído como `Entry_No` (~14,5 millones) deja todo afuera, para siempre, en silencio. Pasó de verdad.

**Objetos nuevos:** Cod110040 `Cliente NAV WS` (HTTP + JSON + paginado), Cod110041 `Traer NAV WS` (el traedor), Cod110042 `Traer y Procesar NAV` (la entrada de proyecto, sirve para los dos transportes), Cod110043 `Sin Dialogo Dim Job`, Enum50330, Pag110039.

## Lo que hubo que hacer del lado de NAV

1. **Segunda instancia de service tier** (`NavisionWS`) sobre la misma base, con `NavUserPassword`. La de producción está en `Windows` y responde NTLM, que el `HttpClient` de AL no habla. **La clave de acceso a servicio web del usuario NO alcanza**: el credential type es de la INSTANCIA, no del usuario, y con `Windows` esa clave nunca se usa. Verificado con un 401.
2. `NavUserPassword` **exige SSL**, y la cuenta de servicio necesita permiso de lectura sobre la **clave privada** del certificado — un permiso aparte de tenerlo instalado. Es el primer error que aparece al arrancar la instancia nueva.
3. **Publicar `Employees` sobre la FICHA del empleado, no sobre la lista.** OData expone sólo los campos que la página MUESTRA: la lista no trae `Employment_Date`, `Address`, `City` ni `Social_Security_No`. Sin fecha de ingreso no se abre la fase de alta y la antigüedad da cero. Lo mismo con proyectos: la lista no traía `Description_2`, `Patron`, `Puerto_zarpada` ni `Año_marea`.
4. **Activar el Change Log** para 167, 5200, 349, 50561 y 50562. Están las cinco en `2` (todos los campos).

## Trampas que sólo aparecen por OData

- **El `Entry_No` va PRIMERO en el filtro del Change Log.** `Table_No eq X` sobre 14,5 millones de filas tarda **más de dos minutos**; `Entry_No gt <marca> and Table_No eq X` es instantáneo. La marca de agua no es sólo el reloj: es lo que hace viable la consulta.
- **La marca inicial se planta ANTES del barrido completo.** Al revés, lo que cambie durante el barrido queda entre la foto y la marca y no lo trae nadie.
- **Las opciones llegan como texto, y a veces como ordinal.** El mismo campo `Tipo` devuelve `"Productivo"` en un proyecto y `"0"` en otro (cuando la opción no tiene caption). Hay que probar el número PRIMERO.
- **La fecha vacía de NAV llega como `0001-01-01`, no como nulo.** Convertida tal cual da una fecha válida del año 1.
- **`HttpClient.Timeout` tope 5 minutos en BC.** Pedir más lanza `NavNclHttpClientTimeoutTooLargeException` y la llamada ni sale. Es por pedido, no por corrida: NAV pagina de a 20.000.
- **`DetalleDescargas` trae `Buque`, `Marea`, `Puerto`, `Location` y `Actividad` DOS veces**: sin sufijo son los de la cabecera, con sufijo `Detalle` los de la línea.
- **Falta `Pallets desde/hasta`** en esa Query: es lo único que el transporte WS no cubre de lo que sí cubre el de SQL.

Relacionado: [[nav-odata-ntlm]], [[dim2-nav-actividad-bc-marea]], [[sincronizacion-valores-dimension]], [[job-confirm-dimension-inocuo]].

## Relacionado

- [[nav-odata-ntlm]]
- [[sincronizacion-valores-dimension]]
- Tema: `integracion-nav` (ver [[_Convenciones del vault]])
