namespace UAS.Payroll;

// Valores de parámetro cuya clave derivada NO se corresponde con sus campos de alcance.
//
// El motor arma la clave que busca a partir del código base y del contexto de la liquidación
// (ver Claves Parámetro Liq.). Si la clave guardada no coincide con ninguna de las que puede armar,
// esa fila es inalcanzable: el cálculo cae al valor genérico y nadie se entera, porque no hay error
// ni advertencia — simplemente se usa otro número.
//
// El caso típico es una carga histórica donde la clave se tipeó a mano sin el prefijo del código
// base: "130/75_EC01" en vez de "BASICO_130/75_EC01", con convenio y categoría sin completar.
//
// La pantalla NO corrige sola. Reparar una de estas filas la vuelve alcanzable, y eso cambia el
// importe de las liquidaciones que se recalculen: es una decisión de negocio, no de mantenimiento.
page 110016 "Claves de Parámetro a Revisar"
{
    ApplicationArea = All;
    Caption = 'Claves de parámetro a revisar';
    PageType = List;
    UsageCategory = Administration;
    SourceTable = "Parámetro Vigente";
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Cód. Parámetro"; Rec."Cód. Parámetro")
                {
                    ApplicationArea = All;
                    Caption = 'Clave guardada';
                    Style = Attention;
                }
                field("Cód. Parámetro Base"; Rec."Cód. Parámetro Base")
                {
                    ApplicationArea = All;
                    Caption = 'Parámetro';
                }
                field(ClaveEsperada; ClaveEsperada)
                {
                    ApplicationArea = All;
                    Caption = 'Clave que el motor busca';
                    ToolTip = 'La clave que se derivaría hoy de los campos de alcance de esta fila. Si difiere de la guardada, el motor no encuentra este valor.';
                }
                field(Diagnóstico; Diagnóstico)
                {
                    ApplicationArea = All;
                    Caption = 'Diagnóstico';
                }
                field(Sugerencia; Sugerencia)
                {
                    ApplicationArea = All;
                    Caption = 'Interpretación posible';
                    ToolTip = 'Cómo se leería la clave guardada si se la desarma en convenio y categoría. Solo se propone cuando esos códigos existen de verdad.';
                }
                field("Cód. Convenio"; Rec."Cód. Convenio") { ApplicationArea = All; }
                field("Cód. Categoría"; Rec."Cód. Categoría") { ApplicationArea = All; }
                field("No. Empleado"; Rec."No. Empleado") { ApplicationArea = All; }
                field("Vigencia Desde"; Rec."Vigencia Desde") { ApplicationArea = All; }
                field(Valor; Rec.Valor) { ApplicationArea = All; }
                field("En Uso"; Rec."En Uso")
                {
                    ApplicationArea = All;
                    ToolTip = 'Si está marcado, este valor ya se usó en una liquidación registrada. Repararlo cambiaría el resultado de un recálculo.';
                }
                field(Descripción; Rec.Descripción) { ApplicationArea = All; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(AplicarSugerencia)
            {
                ApplicationArea = All;
                Caption = 'Aplicar interpretación';
                Image = Apply;
                ToolTip = 'Completa convenio y categoría con la interpretación propuesta y recalcula la clave, de modo que el motor pueda encontrar este valor. Cambia el resultado de los recálculos.';

                trigger OnAction()
                begin
                    AplicarSugerenciaFila();
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Proceso';
                actionref(AplicarSugerenciaProm; AplicarSugerencia) { }
            }
        }
    }

    trigger OnOpenPage()
    begin
        MarcarInconsistentes();
    end;

    trigger OnAfterGetRecord()
    begin
        Analizar();
    end;

    // Se recorre y se marca en vez de filtrar: "la clave no coincide con lo que se derivaría" no es
    // una condición que se pueda expresar como filtro, porque el valor esperado se calcula por fila.
    local procedure MarcarInconsistentes()
    var
        ParamVig: Record "Parámetro Vigente";
        Claves: Codeunit "Claves Parámetro Liq.";
        Encontradas: Integer;
    begin
        Rec.Reset();
        Rec.ClearMarks();
        if ParamVig.FindSet() then
            repeat
                if ParamVig."Cód. Parámetro" <> Claves.ArmarDeFila(ParamVig) then
                    if Rec.Get(ParamVig."Cód. Parámetro Base", ParamVig."Cód. Parámetro", ParamVig."Vigencia Desde") then begin
                        Rec.Mark(true);
                        Encontradas += 1;
                    end;
            until ParamVig.Next() = 0;
        Rec.MarkedOnly(true);

        if Encontradas = 0 then
            Message(MsgTodoBien);
    end;

    local procedure Analizar()
    var
        Claves: Codeunit "Claves Parámetro Liq.";
        Conv: Code[20];
        Cat: Code[20];
    begin
        ClaveEsperada := Claves.ArmarDeFila(Rec);
        Sugerencia := '';

        if Rec."Cód. Parámetro Base" = '' then begin
            Diagnóstico := TxtSinBase;
            exit;
        end;

        if not EmpiezaConBase() then
            Diagnóstico := TxtHuerfana
        else
            Diagnóstico := TxtDesalineada;

        if InterpretarClave(Conv, Cat) then
            if Cat <> '' then
                Sugerencia := StrSubstNo(TxtSugCCT, Conv, Cat)
            else
                Sugerencia := StrSubstNo(TxtSugConvenio, Conv);
    end;

    // Alcance cargado = la fila ya sabe a quién aplica, y entonces la clave se puede rearmar sin
    // adivinar nada. Un valor genérico —sin empleado ni convenio— no entra acá: su clave es el
    // código base a secas, y si no coincide es porque le falta el alcance, no porque esté vieja.
    local procedure TieneAlcanceCargado(): Boolean
    begin
        exit((Rec."No. Empleado" <> '') or (Rec."Cód. Convenio" <> ''));
    end;

    local procedure EmpiezaConBase(): Boolean
    var
        Clave: Text;
    begin
        Clave := Rec."Cód. Parámetro";
        exit((Rec."Cód. Parámetro" = Rec."Cód. Parámetro Base") or
             Clave.StartsWith(Rec."Cód. Parámetro Base" + '_'));
    end;

    // Desarma la clave guardada en convenio y categoría, pero solo devuelve una interpretación si
    // esos códigos EXISTEN. Sin esa verificación, cualquier clave con guiones bajos produciría una
    // sugerencia inventada.
    local procedure InterpretarClave(var Conv: Code[20]; var Cat: Code[20]): Boolean
    var
        Convenio: Record "Convenio Colectivo";
        Categoria: Record "Categoría CCT";
        Resto: Text;
        Partes: List of [Text];
        P1: Text;
        P2: Text;
    begin
        Clear(Conv);
        Clear(Cat);
        Resto := Rec."Cód. Parámetro";
        if EmpiezaConBase() and (Rec."Cód. Parámetro" <> Rec."Cód. Parámetro Base") then
            Resto := CopyStr(Resto, StrLen(Rec."Cód. Parámetro Base") + 2);

        Partes := Resto.Split('_');
        if Partes.Count() = 0 then
            exit(false);

        Partes.Get(1, P1);
        if not Convenio.Get(CopyStr(P1, 1, MaxStrLen(Conv))) then
            exit(false);
        Conv := CopyStr(P1, 1, MaxStrLen(Conv));

        if Partes.Count() = 1 then
            exit(true);

        Partes.Get(2, P2);
        if Categoria.Get(Conv, CopyStr(P2, 1, MaxStrLen(Cat))) then begin
            Cat := CopyStr(P2, 1, MaxStrLen(Cat));
            exit(true);
        end;
        // Convenio válido pero categoría desconocida: se propone solo el convenio, que es lo único
        // que se puede afirmar.
        exit(true);
    end;

    /// <summary>
    /// Repara la fila seleccionada dejando la clave derivada y el alcance de acuerdo.
    /// </summary>
    /// <remarks>
    /// Dos situaciones muy distintas se ven igual en esta pantalla, y hay que resolverlas al revés
    /// una de la otra:
    ///
    /// a) La fila NO tiene alcance cargado y hay que deducirlo de la clave que alguien tipeó a
    ///    mano. Es el caso histórico para el que se escribió InterpretarClave: la clave manda.
    ///
    /// b) El alcance ya está bien y la vieja es la CLAVE — por ejemplo porque se renombró el código
    ///    base del parámetro después de haber cargado los valores. Acá no hay nada que interpretar:
    ///    alcanza con rearmar la clave desde los campos, que es lo que hace RecalcularClave. El
    ///    alcance manda.
    ///
    /// Antes se intentaba (a) siempre, así que (b) moría con "no se pudo interpretar la clave"
    /// aunque tuviera a la vista todo lo necesario para repararse. Pasó con los nueve valores de
    /// PRECIO_FRANCO, que quedaron con claves VALOR_FRANCO_* de una nomenclatura anterior.
    /// </remarks>
    local procedure AplicarSugerenciaFila()
    var
        Conv: Code[20];
        Cat: Code[20];
        ClaveVieja: Code[50];
    begin
        if TieneAlcanceCargado() then begin
            if Rec."Cód. Parámetro" = ClaveEsperada then
                exit;
            if Rec."En Uso" then
                if not Confirm(QstEnUso, false, Rec."Cód. Parámetro") then
                    exit;
            ClaveVieja := Rec."Cód. Parámetro";
            if not Confirm(QstRearmar, false, ClaveVieja, ClaveEsperada) then
                exit;

            Rec.RecalcularClave();
            // La clave es parte de la clave primaria: cambiarla es un rename, no un Modify.
            Rec.Rename(Rec."Cód. Parámetro Base", Rec."Cód. Parámetro", Rec."Vigencia Desde");
            Message(MsgAplicada, Rec."Cód. Parámetro");
            MarcarInconsistentes();
            CurrPage.Update(false);
            exit;
        end;

        if not InterpretarClave(Conv, Cat) then
            Error(ErrSinSugerencia, Rec."Cód. Parámetro");
        if Rec."En Uso" then
            if not Confirm(QstEnUso, false, Rec."Cód. Parámetro") then
                exit;
        if not Confirm(QstAplicar, false, Rec."Cód. Parámetro", Conv, Cat) then
            exit;

        Rec.Validate("Cód. Convenio", Conv);
        if Cat <> '' then
            Rec.Validate("Cód. Categoría", Cat);
        // La clave es parte de la clave primaria: cambiarla es un rename, no un Modify.
        Rec.Rename(Rec."Cód. Parámetro Base", Rec."Cód. Parámetro", Rec."Vigencia Desde");
        Message(MsgAplicada, Rec."Cód. Parámetro");
        MarcarInconsistentes();
        CurrPage.Update(false);
    end;

    var
        ClaveEsperada: Code[50];
        Diagnóstico: Text;
        Sugerencia: Text;
        TxtSinBase: Label 'Sin código de parámetro base: el motor no puede asociar esta fila a ningún parámetro.';
        TxtHuerfana: Label 'La clave no arranca con el código base, así que el motor nunca la va a encontrar. El cálculo cae al valor genérico.';
        TxtDesalineada: Label 'La clave arranca con el código base pero no coincide con los campos de alcance cargados.';
        TxtSugConvenio: Label 'Convenio %1';
        TxtSugCCT: Label 'Convenio %1, categoría %2';
        MsgTodoBien: Label 'Todas las claves derivadas coinciden con sus campos de alcance.';
        ErrSinSugerencia: Label 'No se pudo interpretar la clave %1: los códigos que la componen no corresponden a un convenio conocido. Completá el alcance a mano.';
        QstRearmar: Label 'El alcance de esta fila ya está cargado, así que la clave se rearma a partir de él: %1 pasa a ser %2. ¿Continuar?', Comment = '%1=clave guardada, %2=clave que el motor busca';
        QstEnUso: Label 'El valor %1 ya se usó en una liquidación registrada. Repararlo cambia el resultado de cualquier recálculo de ese período. ¿Continuar igual?';
        QstAplicar: Label 'Se va a interpretar la clave %1 como convenio %2 y categoría %3, y se recalculará la clave para que el motor la encuentre. Esto cambia el importe que resuelve ese parámetro. ¿Continuar?';
        MsgAplicada: Label 'Clave recalculada: %1.';
}
