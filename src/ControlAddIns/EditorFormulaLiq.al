namespace UAS.Payroll;

controladdin "Editor Fórmula Liq."
{
    // Editor de fórmulas con IntelliSense: resaltado de sintaxis, autocompletado mientras se escribe,
    // ayuda de firma de funciones y diagnóstico en vivo (resultado o error).
    //
    // Reparto de trabajo cliente/servidor: el catálogo completo de variables se empuja UNA vez con
    // SetCatalogo y el filtrado del autocompletado ocurre íntegro en el navegador. Consultar al
    // servidor por cada tecla agregaría una ida y vuelta (decenas o cientos de ms) en el camino
    // crítico del tipeo y el editor se sentiría peor que un campo de texto común. Al servidor solo
    // vuelve el texto, con debounce, para evaluarlo de verdad y devolver el diagnóstico.

    Scripts = 'src/ControlAddIns/EditorFormula/editorFormula.js';
    StartupScript = 'src/ControlAddIns/EditorFormula/startup.js';
    StyleSheets = 'src/ControlAddIns/EditorFormula/editorFormula.css';

    RequestedHeight = 380;
    MinimumHeight = 260;
    RequestedWidth = 900;
    MinimumWidth = 300;
    HorizontalStretch = true;
    HorizontalShrink = true;
    VerticalStretch = false;
    VerticalShrink = false;

    /// <summary>El add-in terminó de cargarse y ya puede recibir SetCatalogo/SetValores.</summary>
    event ControlAddInReady();

    /// <summary>El usuario editó un campo. Campo = 'formula' | 'condicion'. Llega con debounce
    /// mientras se escribe, y de inmediato al salir del campo.</summary>
    event OnTextoCambiado(Campo: Text; Texto: Text);

    /// <summary>Catálogo JSON (funciones, operadores, variables, conceptos) para el autocompletado.</summary>
    procedure SetCatalogo(CatalogoJson: Text);

    /// <summary>Carga el contenido de ambos campos. No pisa el campo que el usuario está editando.</summary>
    procedure SetValores(Formula: Text; Condicion: Text);

    /// <summary>Resultado de evaluar un campo en el servidor: { campo, estado, mensaje, valor }.</summary>
    procedure SetDiagnostico(DiagnosticoJson: Text);
}
