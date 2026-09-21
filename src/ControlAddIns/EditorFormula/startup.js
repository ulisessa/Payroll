'use strict';

// BC ejecuta este script cuando el add-in ya está montado en la página. En teoría, para entonces
// existen el div 'controlAddIn' y el módulo UASEditorFormula que define el otro script. En la
// práctica no siempre: al abrir la ficha desde otra página, o cuando BC recrea el control al volver
// a ella, el startup a veces corre antes de que alguna de las dos cosas esté lista.
//
// La versión anterior se rendía en silencio —un 'if (!contenedor) return;'— y entonces el control
// quedaba en blanco para siempre: la única salida era recargar la página y esperar que la segunda
// vez el orden saliera bien. Por eso ahora REINTENTA. Un chequeo cada 100 ms durante unos segundos
// no le cuesta nada a nadie; rendirse le cuesta al usuario no poder editar la fórmula.
(function () {
    var MAX_INTENTOS = 60; // ~6 segundos
    var intentos = 0;

    function arrancar() {
        var contenedor = document.getElementById('controlAddIn');
        var modulo = window.UASEditorFormula;

        if (!contenedor || !modulo || typeof modulo.init !== 'function') {
            if (++intentos <= MAX_INTENTOS) {
                window.setTimeout(arrancar, 100);
                return;
            }
            // Se agotaron los reintentos. Rendirse en silencio deja un rectángulo en blanco que no
            // dice nada y manda a recargar a ciegas — que es exactamente el problema que este
            // startup vino a resolver. Si hay dónde escribir, se escribe qué faltó.
            if (contenedor)
                contenedor.textContent = 'El editor de fórmulas no cargó' +
                    (modulo ? '.' : ': el script del editor no llegó a definirse.') +
                    ' Probá recargar con Ctrl+F5 —el navegador cachea los archivos del control— y, si sigue igual,' +
                    ' usá "Ver texto plano" para editar la fórmula mientras tanto.';
            return;
        }

        try {
            contenedor.innerHTML = '';
            modulo.init(contenedor);
        } catch (e) {
            // Un editor en blanco no dice nada y manda a recargar a ciegas. Con el motivo a la vista
            // se sabe qué pasó, y la ficha tiene "Ver texto plano" para seguir trabajando igual.
            contenedor.textContent = 'No se pudo iniciar el editor de fórmulas (' +
                ((e && e.message) ? e.message : e) +
                '). Usá "Ver texto plano" para editar la fórmula.';
            return;
        }

        // El aviso va DESPUÉS de un init exitoso: ControlAddInReady dispara en AL el envío del
        // catálogo y de los valores, y empujarlos contra un editor que no se construyó los perdería
        // sin que nadie se entere. Si el usuario vuelve a la página y BC recrea el control, este
        // startup corre de nuevo y AL reenvía todo el estado, que es lo que lo hace idempotente.
        if (window.Microsoft && window.Microsoft.Dynamics && window.Microsoft.Dynamics.NAV)
            window.Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('ControlAddInReady', []);
    }

    arrancar();
})();
