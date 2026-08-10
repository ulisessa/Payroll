namespace UAS.Payroll;

codeunit 50070 "Historial Fórmulas Liq."
{
    // Registra los cambios de Fórmula y Condición de los conceptos. Se llama desde los triggers de
    // Concepto Liquidación, así que cubre TODOS los caminos de edición: la ficha, el editor con
    // IntelliSense, el asistente de fórmulas, la copia de conceptos y la carga de configuración.

    var
        MinutosAgrupacion: Integer;

    /// <summary>
    /// Ventana en minutos dentro de la cual las ediciones sucesivas del mismo usuario sobre la misma
    /// fórmula se agrupan en una sola entrada.
    /// </summary>
    /// <remarks>
    /// Sin esto el historial sería inservible: el editor con IntelliSense guarda mientras se escribe
    /// (con debounce), así que escribir una fórmula de una línea generaría diez o quince entradas,
    /// cada una con un carácter de diferencia. Agrupando queda una entrada por sesión de edición,
    /// con el texto que había ANTES de empezar y el que quedó al final — que es la pregunta que uno
    /// le hace al historial.
    /// </remarks>
    local procedure VentanaAgrupacion(): Integer
    begin
        if MinutosAgrupacion = 0 then
            MinutosAgrupacion := 15;
        exit(MinutosAgrupacion);
    end;

    procedure RegistrarAlta(Concepto: Record "Concepto Liquidación")
    var
        Historial: Record "Historial Fórmula Concepto";
    begin
        // Una vigencia nueva sin fórmula ni condición no es un cambio que valga la pena guardar.
        if (Concepto.Fórmula = '') and (Concepto.Condición = '') then
            exit;

        InicializarEntrada(Historial, Concepto, "Tipo Cambio Fórmula"::Alta);
        Historial."Fórmula Nueva" := Concepto.Fórmula;
        Historial."Condición Nueva" := Concepto.Condición;
        Historial."Cambió Fórmula" := Concepto.Fórmula <> '';
        Historial."Cambió Condición" := Concepto.Condición <> '';
        Historial.Insert();
    end;

    procedure RegistrarModificacion(Concepto: Record "Concepto Liquidación"; ConceptoAnterior: Record "Concepto Liquidación")
    var
        Historial: Record "Historial Fórmula Concepto";
    begin
        if (Concepto.Fórmula = ConceptoAnterior.Fórmula) and (Concepto.Condición = ConceptoAnterior.Condición) then
            exit;

        if AgruparConEntradaAbierta(Concepto) then
            exit;

        InicializarEntrada(Historial, Concepto, "Tipo Cambio Fórmula"::Modificación);
        Historial."Fórmula Anterior" := ConceptoAnterior.Fórmula;
        Historial."Fórmula Nueva" := Concepto.Fórmula;
        Historial."Condición Anterior" := ConceptoAnterior.Condición;
        Historial."Condición Nueva" := Concepto.Condición;
        Historial."Cambió Fórmula" := Concepto.Fórmula <> ConceptoAnterior.Fórmula;
        Historial."Cambió Condición" := Concepto.Condición <> ConceptoAnterior.Condición;
        Historial.Insert();
    end;

    procedure RegistrarBaja(Concepto: Record "Concepto Liquidación")
    var
        Historial: Record "Historial Fórmula Concepto";
    begin
        if (Concepto.Fórmula = '') and (Concepto.Condición = '') then
            exit;

        // Se guarda el texto que se lleva la eliminación: es el único momento en que se puede.
        InicializarEntrada(Historial, Concepto, "Tipo Cambio Fórmula"::Eliminación);
        Historial."Fórmula Anterior" := Concepto.Fórmula;
        Historial."Condición Anterior" := Concepto.Condición;
        Historial."Cambió Fórmula" := Concepto.Fórmula <> '';
        Historial."Cambió Condición" := Concepto.Condición <> '';
        Historial.Insert();
    end;

    // Si el mismo usuario ya venía editando esta misma fórmula hace poco, se actualiza esa entrada
    // en vez de crear otra: el "anterior" queda como estaba (el texto con el que arrancó la sesión)
    // y solo avanza el "nuevo".
    local procedure AgruparConEntradaAbierta(Concepto: Record "Concepto Liquidación"): Boolean
    var
        Historial: Record "Historial Fórmula Concepto";
    begin
        Historial.SetCurrentKey("Cód. Concepto", "Vigencia Desde", "Fecha Hora");
        Historial.SetRange("Cód. Concepto", Concepto.Código);
        Historial.SetRange("Vigencia Desde", Concepto."Vigencia Desde");
        Historial.SetRange(Usuario, CopyStr(UserId(), 1, MaxStrLen(Historial.Usuario)));
        Historial.SetRange("Tipo Cambio", "Tipo Cambio Fórmula"::Modificación);
        if not Historial.FindLast() then
            exit(false);
        if CurrentDateTime() - Historial."Fecha Hora" > VentanaAgrupacion() * 60000 then
            exit(false);

        Historial."Fórmula Nueva" := Concepto.Fórmula;
        Historial."Condición Nueva" := Concepto.Condición;
        Historial."Cambió Fórmula" := Historial."Fórmula Nueva" <> Historial."Fórmula Anterior";
        Historial."Cambió Condición" := Historial."Condición Nueva" <> Historial."Condición Anterior";
        Historial."Fecha Hora" := CurrentDateTime();

        // Volvió a dejarlo como estaba: la entrada ya no documenta ningún cambio y se borra, así el
        // historial no se llena de ediciones que terminaron en nada.
        if not Historial."Cambió Fórmula" and not Historial."Cambió Condición" then
            Historial.Delete()
        else
            Historial.Modify();
        exit(true);
    end;

    local procedure InicializarEntrada(var Historial: Record "Historial Fórmula Concepto"; Concepto: Record "Concepto Liquidación"; TipoCambio: Enum "Tipo Cambio Fórmula")
    begin
        Historial.Init();
        Historial."No. Entrada" := 0;
        Historial."Cód. Concepto" := Concepto.Código;
        Historial."Vigencia Desde" := Concepto."Vigencia Desde";
        Historial."Descripción Concepto" := Concepto.Descripción;
        Historial."Fecha Hora" := CurrentDateTime();
        Historial.Usuario := CopyStr(UserId(), 1, MaxStrLen(Historial.Usuario));
        Historial."Tipo Cambio" := TipoCambio;
    end;

    /// <summary>
    /// Devuelve el concepto al texto anterior de esta entrada. El propio restore queda registrado
    /// como un cambio más, así que el historial nunca miente sobre cómo se llegó al texto actual.
    /// </summary>
    procedure Restaurar(Historial: Record "Historial Fórmula Concepto")
    var
        Concepto: Record "Concepto Liquidación";
    begin
        if Historial."Tipo Cambio" = Historial."Tipo Cambio"::Alta then
            Error(ErrRestaurarAlta);
        if not Concepto.Get(Historial."Cód. Concepto", Historial."Vigencia Desde") then
            Error(ErrConceptoNoExiste, Historial."Cód. Concepto", Historial."Vigencia Desde");

        if not Confirm(QstRestaurar, false, Historial."Cód. Concepto", Historial."Vigencia Desde") then
            exit;

        Concepto.Fórmula := CopyStr(Historial."Fórmula Anterior", 1, MaxStrLen(Concepto.Fórmula));
        Concepto.Condición := CopyStr(Historial."Condición Anterior", 1, MaxStrLen(Concepto.Condición));
        Concepto.Modify(true);
        Message(MsgRestaurado, Historial."Cód. Concepto");
    end;

    var
        ErrRestaurarAlta: Label 'Esta entrada es el alta del concepto: no hay texto anterior al que volver.';
        ErrConceptoNoExiste: Label 'Ya no existe la vigencia %2 del concepto %1.';
        QstRestaurar: Label '¿Restaurar la fórmula y la condición anteriores en el concepto %1, vigencia %2?';
        MsgRestaurado: Label 'Se restauró la fórmula anterior del concepto %1.';
}
