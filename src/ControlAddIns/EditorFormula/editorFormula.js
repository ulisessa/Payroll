'use strict';

// Editor de fórmulas de liquidación con IntelliSense.
//
// El tokenizador de acá abajo es un ESPEJO del de NextTok (Cod50015.EvaluadorFormula.al). No es una
// aproximación "linda" pensada para que el resaltado se vea bien: replica las mismas reglas raras del
// motor a propósito, porque el valor del editor está justamente en mostrar lo que el motor ve. Dos
// ejemplos que sorprenden y que acá quedan visibles:
//   · el motor distingue mayúsculas: 'basico' NO es 'BASICO', y 'and' no es el operador AND;
//   · la coma es SIEMPRE separador de argumentos: el decimal se escribe con punto (0.0001).
// Si se toca el tokenizador de AL, hay que tocar este.

var UASEditorFormula = (function () {

    var DEBOUNCE_MS = 500;
    var MAX_ITEMS = 120;
    // Ancla invisible que se intercala en la capa de resaltado en la posición del cursor. Como vive
    // dentro de la MISMA capa que el texto coloreado, su offsetLeft/offsetTop dan la posición exacta
    // del caret sin tener que reconstruir las métricas del textarea en un div espejo.
    var MARCA = '<span class="uas-marca">&#8203;</span>';

    // El alto es fijo y el textarea crece hasta el de su contenido: quien scrollea es el contenedor.
    // 264 px son unos 13 renglones a 19,5 px de interlineado, que es lo que ocupa la fórmula más
    // larga del sistema —la base imponible de Ganancias— ya formateada. Con los 132 originales
    // entraba media: alcanzaban cuando todo se guardaba en una sola línea.
    var CAMPOS = [
        { id: 'formula', etiqueta: 'Fórmula', alto: 264 },
        { id: 'condicion', etiqueta: 'Condición (opcional)', alto: 72 }
    ];

    var catalogo = { funciones: [], operadores: [], variables: [], conceptos: [] };
    var mapaFunciones = Object.create(null);
    var mapaOperadores = Object.create(null);
    var mapaVariables = Object.create(null);
    var mapaVariablesUp = Object.create(null);
    var mapaConceptos = Object.create(null);

    var raiz = null;
    var contenedorRef = null;
    var vigilante = null;
    var reconstrucciones = 0;
    var MAX_RECONSTRUCCIONES = 20;
    var editores = {};
    var popup = null;
    var pop = { abierto: false, ed: null, items: [], sel: 0, rango: null };

    // ── Tokenizador (espejo de NextTok en Cod50015) ───────────────────────────

    function esDigito(c) { return c >= '0' && c <= '9'; }
    // Las letras del español entran en los identificadores, igual que en IsAlpha (Cod50015). Los
    // nombres los escribe una persona en campos Code, que aceptan Ñ y acentos: sin esto el editor
    // cortaba AÑOS_ANTIGUEDAD en la Ñ y marcaba en rojo "OS_ANTIGUEDAD" —el pedazo de atrás— sobre
    // una fórmula que el motor calcula perfecto.
    var LETRAS_ES = 'ÑñÁáÉéÍíÓóÚúÜü';
    function esAlfa(c) { return (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || LETRAS_ES.indexOf(c) >= 0; }
    function esAlfaNum(c) { return esAlfa(c) || esDigito(c); }

    function tokenizar(s) {
        var toks = [];
        var i = 0;
        var n = s.length;

        function agregar(tipo, ini, fin, extra) {
            var tk = { tipo: tipo, ini: ini, fin: fin, texto: s.substring(ini, fin) };
            if (extra) { for (var k in extra) { if (extra.hasOwnProperty(k)) tk[k] = extra[k]; } }
            toks.push(tk);
        }

        while (i < n) {
            var c = s.charAt(i);

            // Espacios, tabulaciones y saltos de línea: el motor los saltea a todos por igual, y las
            // fórmulas se guardan formateadas en varias líneas.
            if (c === ' ' || c === '\t' || c === '\n' || c === '\r') {
                var j0 = i;
                while (j0 < n && ' \t\n\r'.indexOf(s.charAt(j0)) >= 0) j0++;
                agregar('espacio', i, j0);
                i = j0;
                continue;
            }
            if ('+-*/'.indexOf(c) >= 0) { agregar('op', i, i + 1); i++; continue; }
            if (c === '(' || c === ')') { agregar('par', i, i + 1); i++; continue; }
            if (c === ',') { agregar('coma', i, i + 1); i++; continue; }
            if (c === '=') { agregar('op', i, i + 1); i++; continue; }
            if (c === '<') {
                var j1 = i + 1;
                if (s.charAt(j1) === '>' || s.charAt(j1) === '=') j1++;
                agregar('op', i, j1); i = j1; continue;
            }
            if (c === '>') {
                var j2 = i + 1;
                if (s.charAt(j2) === '=') j2++;
                agregar('op', i, j2); i = j2; continue;
            }
            if (c === "'") {
                var j3 = i + 1;
                while (j3 < n && s.charAt(j3) !== "'") j3++;
                var cerrada = j3 < n;
                if (cerrada) j3++;
                agregar('cadena', i, j3, { cerrada: cerrada });
                i = j3; continue;
            }
            if (esDigito(c) || c === '.') {
                // Solo dígitos y punto: la coma es siempre separador de argumentos, igual que en
                // NextTok. Mientras la coma entre dígitos se comía como decimal, IF(cond,0,otra)
                // quedaba con dos argumentos y fallaba sin que se notara en el texto.
                var j4 = i;
                while (j4 < n && (esDigito(s.charAt(j4)) || s.charAt(j4) === '.')) j4++;
                agregar('numero', i, j4); i = j4; continue;
            }
            if (esAlfa(c) || c === '_' || c === '@' || c === '#') {
                var j5 = i + 1;
                while (j5 < n && (esAlfaNum(s.charAt(j5)) || s.charAt(j5) === '_')) j5++;
                agregar('ident', i, j5); i = j5; continue;
            }
            agregar('desconocido', i, i + 1);
            i++;
        }
        return toks;
    }

    function siguienteReal(toks, idx) {
        for (var i = idx + 1; i < toks.length; i++)
            if (toks[i].tipo !== 'espacio') return toks[i];
        return null;
    }

    function anteriorReal(toks, idx) {
        for (var i = idx - 1; i >= 0; i--)
            if (toks[i].tipo !== 'espacio') return toks[i];
        return null;
    }

    // ── Clasificación para el resaltado ───────────────────────────────────────

    function slugTipo(t) {
        return (t || '')
            .toLowerCase()
            .replace(/[áàä]/g, 'a').replace(/[éèë]/g, 'e').replace(/[íìï]/g, 'i')
            .replace(/[óòö]/g, 'o').replace(/[úùü]/g, 'u')
            .replace(/[^a-z0-9]+/g, '-')
            .replace(/^-|-$/g, '') || 'otro';
    }

    // Devuelve la clase CSS y, si corresponde, el motivo por el que el token está mal.
    function clasificar(tok, toks, idx) {
        if (tok.tipo === 'cadena') return { cls: tok.cerrada ? 'cadena' : 'error', motivo: tok.cerrada ? null : 'Falta cerrar la comilla simple.' };
        if (tok.tipo !== 'ident') return { cls: tok.tipo === 'desconocido' ? 'error' : tok.tipo, motivo: tok.tipo === 'desconocido' ? 'Carácter no válido: "' + tok.texto + '".' : null };

        var t = tok.texto;
        var up = t.toUpperCase();
        var sigla = t.charAt(0);

        if (sigla === '@' || sigla === '#') {
            // En mayúsculas por lo mismo: el motor uppercasea la fórmula antes de resolver la
            // referencia, así que @conc01 y @CONC01 son el mismo concepto.
            var cod = t.substring(1).toUpperCase();
            if (mapaConceptos[cod]) return { cls: 'concepto', ref: mapaConceptos[cod] };
            return { cls: 'error', motivo: 'No existe un concepto "' + cod + '".' };
        }

        // Los operadores se comparan igual que las funciones (FTokText <> 'OR' en Cod50015), así que
        // tampoco distinguen mayúsculas.
        //
        // Va ANTES de la detección de llamada a función, y no después: en "AND (X = 0)" el token que
        // sigue a AND es un paréntesis, que es exactamente la firma de una llamada. Clasificándolo
        // después, todo AND/OR/NOT seguido de un paréntesis —la forma normal de escribirlos— caía en
        // la rama de funciones y salía subrayado como "Función desconocida", aunque el motor lo
        // evalúa perfecto. No hay ambigüedad posible: ningún operador comparte nombre con función.
        if (mapaOperadores[up]) return { cls: 'operador', ref: mapaOperadores[up] };

        var sig = siguienteReal(toks, idx);
        var esLlamada = sig && sig.texto === '(';

        if (esLlamada) {
            // Las FUNCIONES no distinguen mayúsculas y las VARIABLES sí. No es un capricho: en
            // Cod50015 las funciones se resuelven con 'case FuncName of ROUND', y la comparación de
            // texto de AL es case-insensitive; las variables salen de FContext, que es un Dictionary
            // y compara ordinal. Antes se avisaba en los dos casos por igual, así que un round() en
            // minúscula —que el motor calcula perfecto— aparecía subrayado como si estuviera mal.
            if (mapaFunciones[up]) return { cls: 'funcion', ref: mapaFunciones[up] };
            return { cls: 'error', motivo: 'Función desconocida: "' + t + '".' };
        }

        // Las variables TAMPOCO distinguen mayúsculas en la fórmula: Cod50015 hace
        // BeginParse(Formula.ToUpper()), o sea que pasa el texto entero a mayúsculas ANTES de
        // tokenizar. Escribir BASICO_EsFCY o basico_esfcy da exactamente lo mismo.
        //
        // Lo que sí rompe es el otro lado: como el motor busca siempre la versión en mayúsculas, un
        // parámetro configurado con el Nombre Variable en minúsculas no se encuentra NUNCA. Eso es
        // un error de configuración, no de la fórmula, y hasta ahora no lo detectaba nadie.
        var vr = mapaVariables[t] || mapaVariables[up] || mapaVariablesUp[up];
        if (vr) {
            if (String(vr.nombre) !== String(vr.nombre).toUpperCase())
                return {
                    cls: 'error',
                    motivo: 'La variable está configurada como "' + vr.nombre + '", con minúsculas. ' +
                            'El motor pasa la fórmula a mayúsculas antes de resolverla, así que nunca la va a ' +
                            'encontrar: renombrala a ' + String(vr.nombre).toUpperCase() + '.'
                };
            return { cls: 'var-' + slugTipo(vr.tipo), ref: vr };
        }
        return { cls: 'error', motivo: 'Variable desconocida: "' + t + '". No está en el catálogo cargado.' };
    }

    // ── Render del resaltado ──────────────────────────────────────────────────

    function escapar(s) {
        return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    }

    function tramo(cls, texto) {
        if (texto === '') return '';
        return '<span class="uas-tk uas-tk-' + cls + '">' + escapar(texto) + '</span>';
    }

    function render(ed) {
        var texto = ed.ta.value;
        var toks = tokenizar(texto);
        var caret = ed.ta.selectionStart;
        var html = '';
        var marcaPuesta = false;

        for (var i = 0; i < toks.length; i++) {
            var tk = toks[i];
            var cls = clasificar(tk, toks, i).cls;
            if (!marcaPuesta && caret >= tk.ini && caret < tk.fin) {
                // El cursor cae dentro de este token: se parte en dos para poder anclar la marca
                // invisible que después se usa para posicionar el popup.
                html += tramo(cls, texto.substring(tk.ini, caret)) + MARCA + tramo(cls, texto.substring(caret, tk.fin));
                marcaPuesta = true;
            } else {
                html += tramo(cls, tk.texto);
            }
        }
        if (!marcaPuesta) html += MARCA;

        // El '\n' final le da altura a la última línea cuando el texto termina en salto.
        ed.hl.innerHTML = html + '\n';
        ed.marca = ed.hl.querySelector('.uas-marca');
        ed.toks = toks;
        renderNombres(ed, toks);
        // Con el panel de nombres a la vista el lienzo está oculto, y medir un elemento oculto da
        // scrollHeight 0: autoAlto dejaría el textarea colapsado y al volver se vería el salto.
        if (ed.lienzo.style.display !== 'none') {
            autoAlto(ed);
            if (document.activeElement === ed.ta) asegurarVisible(ed);
        }
    }

    // ── Panel de nombres de referencias ───────────────────────────────────────

    // Muestra la misma fórmula con la descripción de cada concepto referenciado al lado. Es SÓLO
    // una vista: no toca ta.value, no llama a emitir() y no vuelve al servidor. El nombre sale de
    // mapaConceptos, que ya está en el navegador desde el SetCatalogo inicial.
    //
    // Va en un bloque aparte y no anotando el resaltado, porque .uas-hl tiene que coincidir carácter
    // por carácter con el textarea que está debajo: cualquier texto de más ahí corre el resaltado
    // respecto de las letras reales.
    //
    // Recibe los tokens que render() ya calculó en vez de volver a tokenizar: esto corre en cada
    // tecla.
    function renderNombres(ed, toks) {
        if (!ed.btnNombres) return;

        var html = '';
        var hayRefs = false;
        for (var i = 0; i < toks.length; i++) {
            var tk = toks[i];
            var c = clasificar(tk, toks, i);
            html += tramo(c.cls, tk.texto);

            var sigla = tk.tipo === 'ident' ? tk.texto.charAt(0) : '';
            if (sigla !== '@' && sigla !== '#') continue;
            hayRefs = true;
            if (c.ref && c.ref.desc) html += '<span class="uas-nom">' + escapar(c.ref.desc) + '</span>';
            else html += '<span class="uas-nom uas-nom-falta">no existe</span>';
        }

        // Sin referencias el botón no tiene nada que mostrar, así que desaparece en vez de quedar
        // como un control que no hace nada.
        ed.btnNombres.style.display = hayRefs ? '' : 'none';

        // El panel OCUPA la caja del campo en vez de sumarse debajo: se muestra uno u otro, nunca
        // los dos. De ahí que tenga exactamente el alto del editor.
        if (!hayRefs || !ed.verNombres) {
            ed.nombres.style.display = 'none';
            ed.lienzo.style.display = '';
            return;
        }
        ed.nombres.innerHTML = html;
        ed.nombres.style.display = '';
        ed.lienzo.style.display = 'none';
    }

    // Ya no hace falta limitar a un panel por vez: cada uno ocupa la caja de su propio campo, así
    // que abrir los dos no suma alto y ninguno queda fuera del control.
    function alternarNombres(ed) {
        ed.verNombres = !ed.verNombres;
        sincronizarBotonNombres(ed);
        render(ed);
        // Al volver a la vista editable conviene devolver el cursor donde estaba: si no, hay que
        // hacer un clic de más para seguir escribiendo.
        if (!ed.verNombres) ed.ta.focus();
    }

    function sincronizarBotonNombres(ed) {
        if (!ed.btnNombres) return;
        ed.btnNombres.setAttribute('aria-pressed', ed.verNombres ? 'true' : 'false');
        if (ed.verNombres) ed.btnNombres.classList.add('uas-btn-nom-on');
        else ed.btnNombres.classList.remove('uas-btn-nom-on');
    }

    // El textarea crece hasta el alto de su contenido y quien scrollea es el contenedor. Así hay UNA
    // sola barra de scroll para las dos capas: si scrollearan por separado, en cuanto apareciera la
    // barra en el textarea su ancho de texto cambiaría y el resaltado quedaría corrido respecto de
    // las letras reales.
    function autoAlto(ed) {
        ed.ta.style.height = 'auto';
        ed.ta.style.height = ed.ta.scrollHeight + 'px';
    }

    function asegurarVisible(ed) {
        var m = ed.marca;
        if (!m) return;
        var top = m.offsetTop;
        var bot = top + (m.offsetHeight || 18);
        if (top < ed.editor.scrollTop) ed.editor.scrollTop = top;
        else if (bot > ed.editor.scrollTop + ed.editor.clientHeight) ed.editor.scrollTop = bot - ed.editor.clientHeight;
    }

    function coordsCaret(ed) {
        if (!ed.marca) return null;
        return {
            x: ed.marca.offsetLeft,
            y: ed.marca.offsetTop - ed.editor.scrollTop,
            h: ed.marca.offsetHeight || 18
        };
    }

    // ── Prefijo bajo el cursor y sugerencias ──────────────────────────────────

    function prefijoEnCursor(ed) {
        var s = ed.ta.value;
        var p = ed.ta.selectionStart;
        var i = p;
        while (i > 0) {
            var c = s.charAt(i - 1);
            if (esAlfaNum(c) || c === '_') { i--; continue; }
            if (c === '@' || c === '#') i--;
            break;
        }
        return { texto: s.substring(i, p), ini: i, fin: p };
    }

    function itemFuncion(f) {
        // Se inserta el paréntesis de apertura y cierre y el cursor queda adentro: en TRAMO además
        // entre las comillas del primer argumento, que siempre es un literal de texto.
        var ins = f.primerArgTexto ? f.nombre + "('')" : f.nombre + '()';
        return {
            nombre: f.nombre, tipo: 'Función', valor: '', desc: f.ayuda,
            insertar: ins, caretRel: f.nombre.length + (f.primerArgTexto ? 2 : 1)
        };
    }

    function itemOperador(o) {
        return { nombre: o.nombre, tipo: 'Operador', valor: '', desc: o.ayuda, insertar: o.nombre + ' ', caretRel: o.nombre.length + 1 };
    }

    function itemVariable(v) {
        return { nombre: v.nombre, tipo: v.tipo || 'Variable', valor: v.valor, desc: v.desc, insertar: v.nombre, caretRel: v.nombre.length };
    }

    function itemConcepto(c, sigla) {
        var txt = sigla + c.codigo;
        var etiq = sigla === '@' ? 'Concepto (reevalúa)' : 'Concepto (ya calculado)';
        return { nombre: txt, tipo: etiq, valor: '', desc: c.desc, insertar: txt, caretRel: txt.length };
    }

    function sugerencias(pref) {
        var out = [];
        var i;

        if (pref.charAt(0) === '@' || pref.charAt(0) === '#') {
            var sigla = pref.charAt(0);
            var q = pref.substring(1).toUpperCase();
            for (i = 0; i < catalogo.conceptos.length; i++) {
                var c = catalogo.conceptos[i];
                var cod = String(c.codigo).toUpperCase();
                var pun = -1;
                if (q === '' || cod.indexOf(q) === 0) pun = 0;
                else if (cod.indexOf(q) > 0) pun = 1;
                else if (String(c.desc).toUpperCase().indexOf(q) >= 0) pun = 2;
                if (pun >= 0) out.push({ pun: pun, it: itemConcepto(c, sigla) });
            }
            return ordenar(out);
        }

        var up = pref.toUpperCase();

        function considerar(it, texto) {
            var T = texto.toUpperCase();
            var pun = -1;
            if (up === '' || T.indexOf(up) === 0) pun = 0;
            else if (T.indexOf(up) > 0) pun = 1;
            else if (String(it.desc || '').toUpperCase().indexOf(up) >= 0) pun = 2;
            if (pun >= 0) out.push({ pun: pun, it: it });
        }

        for (i = 0; i < catalogo.funciones.length; i++) considerar(itemFuncion(catalogo.funciones[i]), catalogo.funciones[i].nombre);
        for (i = 0; i < catalogo.operadores.length; i++) considerar(itemOperador(catalogo.operadores[i]), catalogo.operadores[i].nombre);
        for (i = 0; i < catalogo.variables.length; i++) considerar(itemVariable(catalogo.variables[i]), catalogo.variables[i].nombre);

        return ordenar(out);
    }

    function ordenar(lista) {
        lista.sort(function (a, b) {
            if (a.pun !== b.pun) return a.pun - b.pun;
            return a.it.nombre < b.it.nombre ? -1 : (a.it.nombre > b.it.nombre ? 1 : 0);
        });
        var out = [];
        for (var i = 0; i < lista.length && i < MAX_ITEMS; i++) out.push(lista[i].it);
        out.truncado = lista.length - out.length;
        return out;
    }

    // ── Popup ─────────────────────────────────────────────────────────────────

    function abrirPopup(ed, rango, items) {
        pop.abierto = true;
        pop.ed = ed;
        pop.items = items;
        pop.rango = rango;
        pop.sel = 0;

        var html = '';
        for (var i = 0; i < items.length; i++) {
            var it = items[i];
            html += '<div class="uas-item" data-i="' + i + '">' +
                '<span class="uas-item-tipo uas-tipo-' + slugTipo(it.tipo) + '">' + escapar(it.tipo) + '</span>' +
                '<span class="uas-item-nom">' + escapar(it.nombre) + '</span>' +
                '<span class="uas-item-val">' + escapar(it.valor || '') + '</span>' +
                '<span class="uas-item-desc">' + escapar(it.desc || '') + '</span>' +
                '</div>';
        }
        if (items.truncado > 0)
            html += '<div class="uas-item-mas">…y ' + items.truncado + ' más. Seguí escribiendo para filtrar.</div>';

        popup.innerHTML = html;
        popup.style.display = 'block';
        posicionarPopup(ed);
        marcarSeleccion();
    }

    function posicionarPopup(ed) {
        var c = coordsCaret(ed);
        if (!c) return;

        // El popup se posiciona absoluto dentro de .uas-root, y el bloque contenedor de un absoluto es
        // la caja de PADDING, no la de borde. Por eso hay que descontar el padding de la raíz: si se
        // usaran directo las coordenadas de getBoundingClientRect, el popup aparecería corrido
        // exactamente lo que mida ese padding.
        var estilo = window.getComputedStyle(raiz);
        var padIzq = parseFloat(estilo.paddingLeft) || 0;
        var padSup = parseFloat(estilo.paddingTop) || 0;
        var rEd = ed.editor.getBoundingClientRect();
        var rRaiz = raiz.getBoundingClientRect();
        var x = rEd.left - rRaiz.left - padIzq + c.x;
        var y = rEd.top - rRaiz.top - padSup + c.y;

        // El add-in vive dentro de un iframe de tamaño fijo: lo que se dibuje fuera queda recortado,
        // no se puede desbordar como un popup nativo. Por eso el popup se limita al alto disponible y
        // se da vuelta hacia arriba si abajo no entra.
        var altoDisp = raiz.clientHeight;
        var anchoDisp = raiz.clientWidth;

        popup.style.maxHeight = '';
        popup.style.top = '0px';
        popup.style.left = '0px';
        var alto = Math.min(popup.scrollHeight, 168);
        var espacioAbajo = altoDisp - (y + c.h) - 4;
        var espacioArriba = y - 4;

        if (espacioAbajo < 64 && espacioArriba > espacioAbajo) {
            alto = Math.min(alto, espacioArriba);
            popup.style.top = Math.max(0, y - alto) + 'px';
        } else {
            alto = Math.min(alto, Math.max(espacioAbajo, 64));
            popup.style.top = (y + c.h) + 'px';
        }
        popup.style.maxHeight = alto + 'px';

        var ancho = popup.offsetWidth;
        if (x + ancho > anchoDisp - 4) x = Math.max(0, anchoDisp - ancho - 4);
        popup.style.left = x + 'px';
    }

    function cerrarPopup() {
        if (!pop.abierto) return;
        pop.abierto = false;
        pop.ed = null;
        pop.items = [];
        popup.style.display = 'none';
    }

    function marcarSeleccion() {
        var filas = popup.querySelectorAll('.uas-item');
        for (var i = 0; i < filas.length; i++) {
            if (i === pop.sel) {
                filas[i].className = 'uas-item uas-item-sel';
                var f = filas[i];
                if (f.offsetTop < popup.scrollTop) popup.scrollTop = f.offsetTop;
                else if (f.offsetTop + f.offsetHeight > popup.scrollTop + popup.clientHeight)
                    popup.scrollTop = f.offsetTop + f.offsetHeight - popup.clientHeight;
            } else {
                filas[i].className = 'uas-item';
            }
        }
    }

    function mover(delta) {
        if (!pop.items.length) return;
        pop.sel = (pop.sel + delta + pop.items.length) % pop.items.length;
        marcarSeleccion();
    }

    function aceptar() {
        if (!pop.abierto || !pop.items.length) return false;
        var it = pop.items[pop.sel];
        var ed = pop.ed;
        var rango = pop.rango;
        var s = ed.ta.value;
        ed.ta.value = s.substring(0, rango.ini) + it.insertar + s.substring(rango.fin);
        var np = rango.ini + it.caretRel;
        cerrarPopup();
        ed.ta.focus();
        ed.ta.setSelectionRange(np, np);
        alCambiar(ed);
        return true;
    }

    function actualizarPopup(ed, forzado) {
        var pref = prefijoEnCursor(ed);
        if (!forzado && pref.texto.length === 0) { cerrarPopup(); return; }
        var items = sugerencias(pref.texto);
        if (!items.length) { cerrarPopup(); return; }
        abrirPopup(ed, pref, items);
    }

    // ── Ayuda de firma y barra de estado ──────────────────────────────────────

    // Recorre los tokens hasta el cursor manteniendo la pila de llamadas abiertas, para saber en qué
    // función y en qué argumento está parado el cursor.
    function firmaEnCursor(ed) {
        var toks = ed.toks || tokenizar(ed.ta.value);
        var p = ed.ta.selectionStart;
        var pila = [];
        for (var i = 0; i < toks.length; i++) {
            var tk = toks[i];
            if (tk.ini >= p) break;
            if (tk.tipo === 'par' && tk.texto === '(') {
                var prev = anteriorReal(toks, i);
                var nom = (prev && prev.tipo === 'ident') ? prev.texto.toUpperCase() : null;
                pila.push({ nombre: nom, arg: 0 });
            } else if (tk.tipo === 'par' && tk.texto === ')') {
                pila.pop();
            } else if (tk.tipo === 'coma' && pila.length) {
                pila[pila.length - 1].arg++;
            }
        }
        for (var k = pila.length - 1; k >= 0; k--)
            if (pila[k].nombre && mapaFunciones[pila[k].nombre])
                return { fn: mapaFunciones[pila[k].nombre], arg: pila[k].arg };
        return null;
    }

    function firmaHtml(f) {
        var args = f.fn.args || [];
        var html = '<b>' + escapar(f.fn.nombre) + '</b>(';
        for (var i = 0; i < args.length; i++) {
            if (i > 0) html += ', ';
            html += (i === f.arg) ? '<u>' + escapar(args[i]) + '</u>' : escapar(args[i]);
        }
        return html + ')';
    }

    function tokenEnCursor(ed) {
        var toks = ed.toks || [];
        var p = ed.ta.selectionStart;
        for (var i = 0; i < toks.length; i++) {
            var tk = toks[i];
            if (tk.tipo === 'espacio') continue;
            // Se acepta el borde derecho para que, recién terminada de escribir una palabra, el
            // cursor pegado al final siga mostrando su información.
            if (p >= tk.ini && p <= tk.fin) return { tk: tk, info: clasificar(tk, toks, i) };
        }
        return null;
    }

    function actualizarEstado(ed) {
        var partes = [];
        var f = firmaEnCursor(ed);
        if (f) partes.push(firmaHtml(f));

        var t = tokenEnCursor(ed);
        if (t) {
            if (t.info.motivo) {
                partes.push('<span class="uas-alerta">' + escapar(t.info.motivo) + '</span>');
            } else if (t.info.ref) {
                var r = t.info.ref;
                var txt = '<b>' + escapar(t.tk.texto) + '</b>';
                if (r.tipo) txt += ' · ' + escapar(r.tipo);
                if (r.valor) txt += ' · <span class="uas-valor">' + escapar(r.valor) + '</span>';
                if (r.desc || r.ayuda) txt += ' · ' + escapar(r.desc || r.ayuda);
                partes.push(txt);
            }
        }
        ed.info.innerHTML = partes.join('<span class="uas-sep">|</span>');
    }

    // ── Envío al servidor ─────────────────────────────────────────────────────

    function invocar(nombre, args) {
        if (window.Microsoft && window.Microsoft.Dynamics && window.Microsoft.Dynamics.NAV)
            window.Microsoft.Dynamics.NAV.InvokeExtensibilityMethod(nombre, args);
    }

    // inmediato = true al salir del campo, para que las acciones de la cinta (Evaluar, Aplicar y
    // Cerrar) trabajen sobre el texto actual y no sobre el de hace medio segundo.
    function emitir(ed, inmediato) {
        if (ed.timer) { clearTimeout(ed.timer); ed.timer = null; }
        var enviar = function () {
            ed.timer = null;
            if (ed.ultimoEnviado === ed.ta.value) return;
            ed.ultimoEnviado = ed.ta.value;
            invocar('OnTextoCambiado', [ed.id, ed.ta.value]);
        };
        if (inmediato) enviar();
        else ed.timer = setTimeout(enviar, DEBOUNCE_MS);
    }

    // ¿Dos textos son la misma fórmula, ignorando el espacio en blanco? Se comparan los tokens, que
    // es el mismo criterio con el que el formateador de AL se autoverifica antes de devolver nada.
    function mismaFormula(a, b) {
        var ta = tokenizar(a || '').filter(function (t) { return t.tipo !== 'espacio'; });
        var tb = tokenizar(b || '').filter(function (t) { return t.tipo !== 'espacio'; });
        if (ta.length !== tb.length) return false;
        for (var i = 0; i < ta.length; i++)
            if (ta[i].texto !== tb[i].texto) return false;
        return true;
    }

    function alCambiar(ed) {
        render(ed);
        actualizarEstado(ed);
        emitir(ed, false);
    }

    // ── Construcción del DOM y eventos ────────────────────────────────────────

    function crearEditor(def) {
        var campo = document.createElement('div');
        campo.className = 'uas-campo';

        var lbl = document.createElement('div');
        lbl.className = 'uas-label';
        var lblTexto = document.createElement('span');
        lblTexto.textContent = def.etiqueta;
        lbl.appendChild(lblTexto);

        var btnNombres = document.createElement('button');
        btnNombres.type = 'button';
        btnNombres.className = 'uas-btn-nom';
        btnNombres.textContent = 'Ver nombres';
        btnNombres.title = 'Cambia el campo a una vista de sólo lectura con la misma fórmula y la descripción de cada concepto referenciado (@ y #). Volvés a editar apretando otra vez: es sólo una vista, no modifica la fórmula.';
        btnNombres.setAttribute('aria-pressed', 'false');
        btnNombres.style.display = 'none';
        lbl.appendChild(btnNombres);

        var editor = document.createElement('div');
        editor.className = 'uas-editor';
        editor.style.height = def.alto + 'px';

        var lienzo = document.createElement('div');
        lienzo.className = 'uas-lienzo';

        var hl = document.createElement('div');
        hl.className = 'uas-hl';
        hl.setAttribute('aria-hidden', 'true');

        var ta = document.createElement('textarea');
        ta.className = 'uas-ta';
        ta.setAttribute('spellcheck', 'false');
        ta.setAttribute('autocomplete', 'off');
        ta.setAttribute('autocapitalize', 'off');
        ta.setAttribute('aria-label', def.etiqueta);

        lienzo.appendChild(hl);
        lienzo.appendChild(ta);
        editor.appendChild(lienzo);

        var barra = document.createElement('div');
        barra.className = 'uas-barra';
        var info = document.createElement('div');
        info.className = 'uas-info';
        var diag = document.createElement('div');
        diag.className = 'uas-diag';
        barra.appendChild(info);
        barra.appendChild(diag);

        // Va DENTRO de .uas-editor, no debajo: así hereda la caja del campo —mismo alto, mismo
        // borde, mismo scroll— sin necesidad de que el control crezca. Debajo no entraba: el add-in
        // tiene alto fijo (RequestedHeight = 500) y entre los dos editores ya se van unos 416 px.
        var nombres = document.createElement('div');
        nombres.className = 'uas-nombres';
        nombres.setAttribute('aria-live', 'polite');
        nombres.style.display = 'none';
        editor.appendChild(nombres);

        campo.appendChild(lbl);
        campo.appendChild(editor);
        campo.appendChild(barra);
        raiz.appendChild(campo);

        var ed = { id: def.id, campo: campo, editor: editor, lienzo: lienzo, hl: hl, ta: ta, info: info, diag: diag, btnNombres: btnNombres, nombres: nombres, verNombres: false, toks: [], ultimoEnviado: null, timer: null };
        editores[def.id] = ed;

        // mousedown y no click para el preventDefault: sin esto el botón le roba el foco al textarea,
        // y al volver el cursor queda al principio de la fórmula.
        btnNombres.addEventListener('mousedown', function (e) { e.preventDefault(); });
        btnNombres.addEventListener('click', function (e) {
            e.preventDefault();
            e.stopPropagation();
            alternarNombres(ed);
        });

        conectar(ed);
        // Primer render aunque esté vacío: deja creada la marca del caret, que es de donde sale la
        // posición del popup. Sin esto, Ctrl+Espacio en un editor recién abierto no sabría dónde
        // dibujarse.
        render(ed);
        return ed;
    }

    function reemplazar(ed, ini, fin, texto, caretRel) {
        var s = ed.ta.value;
        ed.ta.value = s.substring(0, ini) + texto + s.substring(fin);
        var np = ini + (caretRel === undefined ? texto.length : caretRel);
        ed.ta.setSelectionRange(np, np);
    }

    function conectar(ed) {
        var ta = ed.ta;

        ta.addEventListener('keydown', function (e) {
            if (pop.abierto && pop.ed === ed) {
                if (e.key === 'ArrowDown') { mover(1); e.preventDefault(); e.stopPropagation(); return; }
                if (e.key === 'ArrowUp') { mover(-1); e.preventDefault(); e.stopPropagation(); return; }
                if (e.key === 'PageDown') { mover(5); e.preventDefault(); e.stopPropagation(); return; }
                if (e.key === 'PageUp') { mover(-5); e.preventDefault(); e.stopPropagation(); return; }
                if (e.key === 'Enter' || e.key === 'Tab') {
                    if (aceptar()) { e.preventDefault(); e.stopPropagation(); }
                    return;
                }
                // stopPropagation es imprescindible: si Escape llega al cliente de BC, cierra la
                // página modal entera en vez de cerrar el popup.
                if (e.key === 'Escape') { cerrarPopup(); e.preventDefault(); e.stopPropagation(); return; }
            }

            if (e.ctrlKey && (e.key === ' ' || e.code === 'Space')) {
                actualizarPopup(ed, true);
                e.preventDefault(); e.stopPropagation();
                return;
            }

            var ini = ta.selectionStart, fin = ta.selectionEnd;
            if (e.key === '(' && ini === fin) {
                reemplazar(ed, ini, fin, '()', 1);
                alCambiar(ed); e.preventDefault(); return;
            }
            if (e.key === ')' && ini === fin && ta.value.charAt(ini) === ')') {
                ta.setSelectionRange(ini + 1, ini + 1);
                render(ed); actualizarEstado(ed); e.preventDefault(); return;
            }
            if (e.key === "'" && ini === fin) {
                if (ta.value.charAt(ini) === "'") ta.setSelectionRange(ini + 1, ini + 1);
                else reemplazar(ed, ini, fin, "''", 1);
                alCambiar(ed); e.preventDefault(); return;
            }
        });

        ta.addEventListener('input', function () {
            alCambiar(ed);
            actualizarPopup(ed, false);
        });

        ta.addEventListener('keyup', function (e) {
            if (!e.key) return;
            if (e.key.indexOf('Arrow') === 0 || e.key === 'Home' || e.key === 'End') {
                render(ed);
                actualizarEstado(ed);
                if (pop.abierto && pop.ed === ed) actualizarPopup(ed, false);
            }
        });

        ta.addEventListener('click', function () {
            cerrarPopup();
            render(ed);
            actualizarEstado(ed);
        });

        ed.editor.addEventListener('scroll', function () { if (pop.abierto && pop.ed === ed) posicionarPopup(ed); });

        ta.addEventListener('focus', function () { ed.editor.className = 'uas-editor uas-editor-foco'; });

        ta.addEventListener('blur', function () {
            ed.editor.className = 'uas-editor';
            cerrarPopup();
            emitir(ed, true);
        });

        // El textarea solo mide lo que ocupa su texto; sin esto, clickear en el espacio vacío de
        // abajo del recuadro no haría nada.
        ed.editor.addEventListener('mousedown', function (e) {
            if (e.target === ta) return;
            var fin = ta.value.length;
            ta.focus();
            ta.setSelectionRange(fin, fin);
            render(ed);
            actualizarEstado(ed);
            e.preventDefault();
        });
    }

    function conectarPopup() {
        // mousedown con preventDefault: si el textarea perdiera el foco al clickear, blur cerraría el
        // popup antes de que llegue el click y el ítem nunca se insertaría.
        popup.addEventListener('mousedown', function (e) {
            var fila = e.target;
            while (fila && fila !== popup && !fila.getAttribute('data-i')) fila = fila.parentNode;
            if (fila && fila !== popup) {
                pop.sel = parseInt(fila.getAttribute('data-i'), 10);
                aceptar();
            }
            e.preventDefault();
        });
        popup.addEventListener('mousemove', function (e) {
            var fila = e.target;
            while (fila && fila !== popup && !fila.getAttribute('data-i')) fila = fila.parentNode;
            if (fila && fila !== popup) {
                var i = parseInt(fila.getAttribute('data-i'), 10);
                if (i !== pop.sel) { pop.sel = i; marcarSeleccion(); }
            }
        });
    }

    // ── Tema ──────────────────────────────────────────────────────────────────

    // El control tiene que verse como la página que lo contiene, y la única fuente confiable de eso
    // es el color que hay REALMENTE detrás del control: BC no le pasa su tema al add-in, y
    // (prefers-color-scheme) responde al sistema operativo, que puede estar en oscuro con BC en claro
    // — que es justamente cómo el editor terminaba negro dentro de una página blanca.
    //
    // Se lee subiendo desde el propio iframe hasta el primer ancestro con fondo opaco. Si el iframe
    // resultara de otro origen, window.frameElement tira SecurityError: ahí se asume claro, que es el
    // tema con el que BC se muestra por defecto.
    function rgbDeTexto(txt) {
        if (!txt) return null;
        var m = txt.replace(/\s/g, '').match(/^rgba?\((\d+),(\d+),(\d+)(?:,([\d.]+))?\)$/i);
        if (!m) return null;
        return {
            r: parseInt(m[1], 10),
            g: parseInt(m[2], 10),
            b: parseInt(m[3], 10),
            a: m[4] === undefined ? 1 : parseFloat(m[4])
        };
    }

    function fondoDelHost() {
        var el, doc, vista, rgb;
        try {
            el = window.frameElement;
        } catch (e) {
            return null; // otro origen: no hay nada que mirar
        }
        if (!el) return null;
        doc = el.ownerDocument;
        vista = doc && doc.defaultView;
        if (!vista) return null;

        try {
            while (el) {
                rgb = rgbDeTexto(vista.getComputedStyle(el).backgroundColor);
                // Un fondo casi transparente deja ver el de más arriba: no sirve para decidir.
                if (rgb && rgb.a > 0.1) return rgb;
                el = el.parentElement;
            }
            return rgbDeTexto(vista.getComputedStyle(doc.documentElement).backgroundColor);
        } catch (e) {
            return null;
        }
    }

    function esOscuro(rgb) {
        if (!rgb) return false;
        // Luminancia percibida (ITU-R BT.601): el verde pesa más que el rojo y mucho más que el azul.
        return (0.299 * rgb.r + 0.587 * rgb.g + 0.114 * rgb.b) / 255 < 0.5;
    }

    function aplicarTema() {
        if (!raiz) return;
        var oscuro = esOscuro(fondoDelHost());
        if (oscuro) raiz.className = 'uas-root uas-oscuro';
        else raiz.className = 'uas-root';
    }

    // BC puede cambiar de tema sin recrear el add-in, así que no alcanza con detectarlo una vez.
    function observarTemaDelHost() {
        var el, doc, obs;
        try {
            el = window.frameElement;
            doc = el && el.ownerDocument;
            if (!doc || typeof MutationObserver !== 'function') return;
            obs = new MutationObserver(aplicarTema);
            obs.observe(doc.documentElement, { attributes: true, attributeFilter: ['class', 'style', 'data-theme'] });
            if (doc.body)
                obs.observe(doc.body, { attributes: true, attributeFilter: ['class', 'style', 'data-theme'] });
        } catch (e) {
            // Otro origen: el tema no se puede observar. Queda el claro por defecto.
        }
    }

    // ── Vigilancia del DOM ────────────────────────────────────────────────────
    //
    // El módulo vive en el window del iframe, que sobrevive a que BC vacíe el contenedor del add-in.
    // Cuando eso pasa, 'raiz' sigue apuntando a un árbol de nodos que ya no está en la página: los
    // editores existen, SetValores les escribe sin fallar, el diagnóstico se pinta —y el usuario ve
    // un rectángulo en blanco. Nada da error porque, técnicamente, nada falló. Es el modo en que el
    // control queda 'colgado en la pestaña'.
    //
    // Un chequeo cada dos segundos —una llamada a contains(), nada más— alcanza para detectarlo y
    // rearmarse. El tope de reconstrucciones está para que, si BC estuviera destruyendo el control
    // en un ciclo, esto no se convierta en un motor de reintentos infinitos comiéndose la pestaña.
    function estaVivo() {
        return !!(raiz && document.body && document.body.contains(raiz));
    }

    function vigilar() {
        if (vigilante) return;
        vigilante = window.setInterval(function () {
            var c;
            if (estaVivo()) return;

            c = document.getElementById('controlAddIn') || contenedorRef;
            // Si el contenedor tampoco está en la página, BC se llevó el add-in entero y no hay nada
            // que reparar: reconstruir contra un nodo huérfano dejaría todo igual de invisible.
            if (!c || !document.body || !document.body.contains(c)) return;

            if (++reconstrucciones > MAX_RECONSTRUCCIONES) {
                window.clearInterval(vigilante);
                vigilante = null;
                c.textContent = 'El editor de fórmulas se reinició demasiadas veces y dejó de intentarlo.' +
                    ' Recargá la página con Ctrl+F5 y, mientras tanto, usá "Ver texto plano".';
                return;
            }

            try {
                c.innerHTML = '';
                construir(c);
            } catch (e) {
                return;
            }

            // Avisarle a AL que el control está listo OTRA VEZ: la reconstrucción trae los editores
            // vacíos, y el catálogo y la fórmula solo puede reenviarlos el servidor. Del lado de AL
            // el trigger es idempotente, justamente para poder llamarlo así.
            if (window.Microsoft && window.Microsoft.Dynamics && window.Microsoft.Dynamics.NAV)
                window.Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('ControlAddInReady', []);
        }, 2000);
    }

    function alFocoVentana() {
        aplicarTema();
    }

    function alBlurVentana() {
        // Red de seguridad para que las acciones de la cinta (Evaluar, Aplicar y Cerrar) nunca
        // trabajen con texto viejo: clickear fuera del iframe dispara el blur del textarea, pero si
        // por algún camino no llegara, el blur de la ventana igual fuerza el envío pendiente.
        for (var k in editores)
            if (editores.hasOwnProperty(k)) emitir(editores[k], true);
    }

    function construir(contenedor) {
            // Se puede llamar más de una vez sobre el mismo iframe —eso es lo que hace el vigilante—
            // así que primero se descarta el estado anterior. Sin esto, cada reconstrucción dejaría
            // otro par de listeners en window apuntando a editores muertos.
            window.removeEventListener('focus', alFocoVentana);
            window.removeEventListener('blur', alBlurVentana);
            editores = {};
            pop = { abierto: false, ed: null, items: [], sel: 0, rango: null };

            raiz = document.createElement('div');
            raiz.className = 'uas-root';
            contenedor.appendChild(raiz);

            for (var i = 0; i < CAMPOS.length; i++) crearEditor(CAMPOS[i]);

            popup = document.createElement('div');
            popup.className = 'uas-popup';
            popup.style.display = 'none';
            raiz.appendChild(popup);
            conectarPopup();

            var pista = document.createElement('div');
            pista.className = 'uas-pista';
            pista.textContent = 'Ctrl+Espacio: sugerencias · Tab/Enter: aceptar · @código: reevalúa otro concepto · #código: importe ya calculado';
            raiz.appendChild(pista);

            aplicarTema();
            observarTemaDelHost();
            // Volver a la pestaña o cambiar el tamaño puede venir después de un cambio de tema que el
            // observer no vio (por ejemplo si el iframe es de otro origen y el usuario recargó).
            window.addEventListener('focus', alFocoVentana);
            window.addEventListener('blur', alBlurVentana);
    }

    // ── API pública (la usa el envoltorio global que llama AL) ────────────────

    return {
        init: function (contenedor) {
            contenedorRef = contenedor;
            reconstrucciones = 0;
            construir(contenedor);
            vigilar();
        },

        setCatalogo: function (json) {
            try {
                catalogo = JSON.parse(json);
            } catch (e) {
                catalogo = { funciones: [], operadores: [], variables: [], conceptos: [] };
            }
            catalogo.funciones = catalogo.funciones || [];
            catalogo.operadores = catalogo.operadores || [];
            catalogo.variables = catalogo.variables || [];
            catalogo.conceptos = catalogo.conceptos || [];

            // Object.create(null) y no {}: los nombres vienen de datos de configuración, y un
            // parámetro llamado 'constructor' o 'toString' daría un falso positivo contra las
            // propiedades heredadas de Object.
            mapaFunciones = Object.create(null);
            mapaOperadores = Object.create(null);
            mapaVariables = Object.create(null);
            mapaVariablesUp = Object.create(null);
            mapaConceptos = Object.create(null);
            var i;
            for (i = 0; i < catalogo.funciones.length; i++) mapaFunciones[catalogo.funciones[i].nombre.toUpperCase()] = catalogo.funciones[i];
            for (i = 0; i < catalogo.operadores.length; i++) mapaOperadores[catalogo.operadores[i].nombre.toUpperCase()] = catalogo.operadores[i];
            // Índice adicional por nombre en MAYÚSCULAS: es la forma en que el motor va a buscar la
            // variable, porque uppercasea la fórmula antes de parsear. El mapa con el nombre tal
            // cual se conserva para poder detectar el caso al revés — una variable configurada en
            // minúsculas, que el motor no encontraría jamás.
            for (i = 0; i < catalogo.variables.length; i++) {
                mapaVariables[catalogo.variables[i].nombre] = catalogo.variables[i];
                mapaVariablesUp[String(catalogo.variables[i].nombre).toUpperCase()] = catalogo.variables[i];
            }
            for (i = 0; i < catalogo.conceptos.length; i++) mapaConceptos[String(catalogo.conceptos[i].codigo).toUpperCase()] = catalogo.conceptos[i];

            for (var k in editores) if (editores.hasOwnProperty(k)) { render(editores[k]); actualizarEstado(editores[k]); }
        },

        setValores: function (formula, condicion) {
            var vals = { formula: formula || '', condicion: condicion || '' };
            for (var k in editores) {
                if (!editores.hasOwnProperty(k)) continue;
                var ed = editores[k];
                // No se pisa el campo que el usuario está editando: el servidor puede reenviar valores
                // (por ejemplo al recrearse el add-in tras un CurrPage.Update) mientras se tipea.
                if (document.activeElement === ed.ta && ed.ta.value !== '') continue;
                if (ed.ta.value === vals[k]) continue;
                // Y tampoco se pisa cuando lo que llega es LA MISMA FÓRMULA escrita distinto.
                //
                // Es el caso que aparece en cada guardado desde que el texto se guarda formateado: el
                // Modify refresca la ficha, OnAfterGetRecord reenvía los valores, y lo que vuelve es
                // el mismo texto pero con saltos y sangría. Reemplazarlo le mueve el cursor al usuario
                // y le come lo que haya tipeado desde el último envío — o sea, parece que el editor
                // "no guarda": en realidad guardó, y le devolvió el texto reacomodado encima.
                //
                // El chequeo de foco de arriba no alcanza: el refresco del propio guardado puede
                // sacarle el foco al iframe, y entonces la guarda no se activa justo cuando hace falta.
                if (ed.ta.value !== '' && mismaFormula(ed.ta.value, vals[k])) continue;
                ed.ta.value = vals[k];
                ed.ultimoEnviado = vals[k];
                render(ed);
                actualizarEstado(ed);
            }
        },

        setDiagnostico: function (json) {
            var d;
            try { d = JSON.parse(json); } catch (e) { return; }
            var ed = editores[d.campo];
            if (!ed) return;
            ed.diag.className = 'uas-diag uas-diag-' + (d.estado || 'neutro');
            if (d.estado === 'ok') ed.diag.textContent = '= ' + (d.valor || '');
            else ed.diag.textContent = d.mensaje || '';
            ed.diag.title = d.mensaje || '';
        }
    };
})();

// Explícito, en vez de confiar en que un `var` de nivel superior termine siendo propiedad de
// window: startup.js lo busca ahí para saber si el módulo ya se cargó antes de inicializarlo.
window.UASEditorFormula = UASEditorFormula;

// Puntos de entrada que invoca AL (los nombres deben coincidir con los procedure del controladdin).
function SetCatalogo(catalogoJson) { UASEditorFormula.setCatalogo(catalogoJson); }
function SetValores(formula, condicion) { UASEditorFormula.setValores(formula, condicion); }
function SetDiagnostico(diagnosticoJson) { UASEditorFormula.setDiagnostico(diagnosticoJson); }
