'use strict';

// BC ejecuta este script cuando el add-in ya está montado en la página. Recién ahí existe el div
// contenedor 'controlAddIn' y tiene sentido avisarle a AL que puede empujar catálogo y valores.
//
// Si el usuario vuelve a esta página o BC recrea el control, este startup corre de nuevo: por eso
// ControlAddInReady en AL siempre reenvía TODO el estado (catálogo + valores + diagnóstico) en vez de
// asumir que el editor ya lo tiene.
(function () {
    var contenedor = document.getElementById('controlAddIn');
    if (!contenedor) return;
    contenedor.innerHTML = '';
    UASEditorFormula.init(contenedor);
    if (window.Microsoft && window.Microsoft.Dynamics && window.Microsoft.Dynamics.NAV)
        window.Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('ControlAddInReady', []);
})();
