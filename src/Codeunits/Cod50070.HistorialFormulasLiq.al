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
        Almacenado: Record "Concepto Liquidación";
    begin
        // xRec NO sirve como "texto anterior" cuando el guardado viene del editor con IntelliSense.
        //
        // El editor es un control add-in: cada cambio de texto es un viaje cliente→servidor, y al
        // entrar al evento BC reconstruye el estado de la página con Rec y xRec ya sincronizados.
        // GuardarTextoDeEditor (Pag50145) asigna Rec.Fórmula recién DESPUÉS de esa sincronización,
        // así que el Modify llega con xRec.Fórmula = Rec.Fórmula, la comparación de abajo no ve
        // ningún cambio y el registro se saltea EN SILENCIO. Ese fue el motivo real de que el
        // historial dejara de escribir: no falla nada, simplemente nadie ve la diferencia.
        //
        // La fuente confiable es la base. OnModify corre ANTES de escribir la fila, así que la
        // versión almacenada todavía es la anterior. Si el Get fallara —no debería, la fila
        // existe— se cae de vuelta a xRec, que sigue siendo correcto en los caminos que no pasan
        // por el add-in.
        if Almacenado.Get(Concepto.Código, Concepto."Vigencia Desde") then
            ConceptoAnterior := Almacenado;

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

    /// <summary>
    /// Deja constancia de un reformateo: mismo cálculo, distinto texto.
    /// </summary>
    /// <remarks>
    /// La escriben las acciones de formateo, que guardan con Modify(false) —sin disparadores— porque
    /// pasar por OnModify registraría una Modificación, y decir que la fórmula cambió cuando no
    /// cambió es peor que no decir nada. Pero no decir NADA también estaba mal: la fórmula es un
    /// objeto versionado y auditado, y una reescritura masiva sin rastro deja sin respuesta la
    /// pregunta de por qué el texto no es igual al que alguien recuerda haber cargado.
    ///
    /// No se agrupa con las entradas abiertas: no es una sesión de edición, es un proceso que corre
    /// una vez. Y AgruparConEntradaAbierta solo mira las de tipo Modificación, así que un formateo
    /// tampoco se come la agrupación de una edición en curso.
    /// </remarks>
    procedure RegistrarFormato(Concepto: Record "Concepto Liquidación"; FormulaAnterior: Text; CondicionAnterior: Text)
    var
        Historial: Record "Historial Fórmula Concepto";
    begin
        if (Concepto.Fórmula = FormulaAnterior) and (Concepto.Condición = CondicionAnterior) then
            exit;

        InicializarEntrada(Historial, Concepto, "Tipo Cambio Fórmula"::Formato);
        Historial."Fórmula Anterior" := CopyStr(FormulaAnterior, 1, MaxStrLen(Historial."Fórmula Anterior"));
        Historial."Fórmula Nueva" := Concepto.Fórmula;
        Historial."Condición Anterior" := CopyStr(CondicionAnterior, 1, MaxStrLen(Historial."Condición Anterior"));
        Historial."Condición Nueva" := Concepto.Condición;
        Historial."Cambió Fórmula" := Concepto.Fórmula <> FormulaAnterior;
        Historial."Cambió Condición" := Concepto.Condición <> CondicionAnterior;
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

    /// <summary>
    /// Si el mismo usuario ya venía editando esta misma fórmula hace poco, actualiza esa entrada en
    /// vez de crear otra: el "anterior" queda como estaba —el texto con el que arrancó la sesión— y
    /// solo avanza el "nuevo".
    /// </summary>
    /// <remarks>
    /// La ventana se mide contra "Fecha Hora", que es el INICIO de la sesión y no se toca. Antes se
    /// la pisaba en cada guardado, y eso tenía dos consecuencias malas:
    ///
    /// 1. La ventana no se cerraba nunca mientras se siguiera editando. Una tarde entera de trabajo
    ///    sobre la misma fórmula era UNA entrada, y el historial perdía todos los pasos intermedios.
    /// 2. Peor: el Delete de más abajo borra la entrada cuando el texto vuelve al del inicio de la
    ///    sesión. Con la ventana corriéndose, bastaba pasar una vez por el texto original —al final
    ///    de esa tarde— para que desapareciera el registro de TODO lo anterior.
    ///
    /// Anclada al inicio, una sesión dura como mucho VentanaAgrupacion() minutos, y el Delete solo
    /// puede alcanzar lo que se hizo dentro de ese rato: exactamente el caso para el que se escribió
    /// —escribí y me arrepentí en el momento— y nada más. Pasada la ventana se abre una entrada
    /// nueva, encadenada a la anterior por su "Fórmula Anterior".
    /// </remarks>
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
        Historial."Última Edición" := CurrentDateTime();

        // Volvió a dejarlo como estaba: la entrada ya no documenta ningún cambio y se borra, así el
        // historial no se llena de ediciones que terminaron en nada. Con la ventana anclada al
        // inicio, esto solo puede borrar lo hecho dentro de la sesión en curso.
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
        Historial."Última Edición" := Historial."Fecha Hora";
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
