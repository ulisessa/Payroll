namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;

page 50153 "Parámetro Sufijo Sub"
{
    ApplicationArea = All;
    Caption = 'Valores por alcance';
    PageType = ListPart;
    SourceTable = "Parámetro Vigente";
    // Mismo orden que el árbol completo: la clave primaria, que alfabéticamente ya deja a cada
    // especialización debajo de la clave de la que deriva.
    SourceTableView = sorting("Cód. Parámetro Base", "Cód. Parámetro", "Vigencia Desde");
    DelayedInsert = true;
    // Los tres campos de alcance están SIEMPRE habilitados. Antes se habilitaban y deshabilitaban
    // según qué bandera de sufijo tuviera el parámetro; ahora la clave derivada sale de los campos
    // que se completen, así que la bandera no hace falta y un parámetro puede tener a la vez un
    // valor por defecto, una excepción por convenio y otra por empleado.
    //
    // La clave la arma la tabla (Parámetro Vigente.RecalcularClave) y no esta página: es la misma
    // regla que usa el motor para buscarla, y tenerla en un solo lugar es lo que evita que se
    // desincronicen.

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                // Lista plana, NO árbol. Se probó con ShowAsTree para que la jerarquía de la clave
                // derivada se viera dibujada —valor por defecto arriba, excepciones debajo— y el
                // costo fue desproporcionado: un repeater en modo árbol no ofrece la fila en blanco
                // del pie, que es el modo natural de cargar en BC. Esta pantalla existe sobre todo
                // para CARGAR valores, y perder el alta inline para ganar una sangría es un mal
                // negocio.
                //
                // La jerarquía igual se lee: el orden de la vista agrupa por parámetro base y clave
                // derivada, la columna Alcance la dice en palabras ("Convenio 729/15, categoría
                // MR03") y la clave inconsistente sigue resaltada en rojo. Para verla dibujada está
                // el Árbol de Parámetros, que es una pantalla de consulta y ahí sí corresponde.

                field(Alcance; Alcance)
                {
                    ApplicationArea = All;
                    Caption = 'Alcance';
                    Editable = false;
                    Visible = false;
                }
                field("Cód. Convenio"; Rec."Cód. Convenio")
                {
                    ApplicationArea = All;
                    Caption = 'Cód. Convenio';
                    Editable = not Rec."En Uso";
                    ToolTip = 'Convenio para el que aplica este valor. Solo, arma la excepción por convenio; con la categoría, la excepción por convenio y categoría.';
                }
                field("Cód. Categoría"; Rec."Cód. Categoría")
                {
                    ApplicationArea = All;
                    Caption = 'Cód. Categoría';
                    Editable = not Rec."En Uso";
                    ToolTip = 'Categoría para la que aplica este valor. Se carga junto con el convenio.';
                }
                field("No. Empleado"; Rec."No. Empleado")
                {
                    ApplicationArea = All;
                    Caption = 'No. Empleado';
                    Editable = not Rec."En Uso";
                    ToolTip = 'Empleado para el que aplica este valor. Excluyente con convenio y categoría: al completarlo, esos dos se limpian.';
                }

                field("Vigencia Desde"; Rec."Vigencia Desde") { ApplicationArea = All; }
                field(Valor; Rec.Valor)
                {
                    ApplicationArea = All;
                    Editable = not Rec."En Uso";
                }
                field(Moneda; Rec.Moneda) { ApplicationArea = All; }
                field("En Uso"; Rec."En Uso")
                {
                    ApplicationArea = All;
                    Editable = false;
                    Style = Attention;
                    StyleExpr = Rec."En Uso";
                }
                field(Descripción; Rec.Descripción)
                {
                    ApplicationArea = All;
                    Caption = 'Descripción Versión';
                }
                field("Cód. Parámetro"; Rec."Cód. Parámetro")
                {
                    ApplicationArea = All;
                    Caption = 'Clave Derivada';
                    StyleExpr = EstiloClave;
                    ToolTip = 'La clave con la que el motor busca este valor. Se calcula sola: dejando el alcance vacío queda la clave base, que hace de valor por defecto.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            // El alta normal es la fila en blanco del pie: se tipea el alcance y la tabla arma la
            // clave derivada sola. Estas dos acciones son atajos, no el camino principal.
            action(NuevoValor)
            {
                ApplicationArea = All;
                Caption = 'Nuevo valor...';
                Image = New;
                ToolTip = 'Crea un valor y abre su ficha para completar el alcance con más contexto. Para cargar de a varios, conviene la fila en blanco del final de la lista.';

                trigger OnAction()
                begin
                    CrearValor(false);
                end;
            }
            action(NuevaVigencia)
            {
                ApplicationArea = All;
                Caption = 'Nueva vigencia';
                Image = NewRow;
                ToolTip = 'Crea una vigencia nueva para el alcance de la fila seleccionada, copiando su valor. Es la forma de cambiar un valor ya usado en una liquidación sin tocar el anterior.';

                trigger OnAction()
                begin
                    CrearValor(true);
                end;
            }
        }
    }

    /// <summary>
    /// Da de alta un valor y abre su ficha. Con HeredarAlcance, arranca del alcance de la fila.
    /// </summary>
    /// <remarks>
    /// La fila se inserta ANTES de abrir la ficha, que es como se dan de alta las fichas en toda la
    /// base: la clave derivada la calcula la tabla al insertar, y la ficha necesita un registro real
    /// para poder guardar lo que se edite. Si se abandona la ficha queda una fila con el valor en
    /// cero — visible y borrable, que es mejor que un alta que parece haberse guardado.
    /// </remarks>
    local procedure CrearValor(HeredarAlcance: Boolean)
    var
        Nuevo: Record "Parámetro Vigente";
    begin
        if FBaseCodigo = '' then
            Error(ErrSinParametro);

        Nuevo.Init();
        Nuevo."Cód. Parámetro Base" := FBaseCodigo;
        if HeredarAlcance then begin
            if Rec."Cód. Parámetro" = '' then
                Error(ErrSinFila);
            Nuevo."Cód. Convenio" := Rec."Cód. Convenio";
            Nuevo."Cód. Categoría" := Rec."Cód. Categoría";
            Nuevo."No. Empleado" := Rec."No. Empleado";
            Nuevo.Valor := Rec.Valor;
            Nuevo.Moneda := Rec.Moneda;
        end;
        Nuevo."Vigencia Desde" := WorkDate();
        Nuevo.RecalcularClave();

        // Mismo alcance y misma fecha que una fila que ya está: son dos respuestas para la misma
        // pregunta. Se avisa acá, que es donde se entiende, en vez de dejar salir el error de clave
        // duplicada de la plataforma.
        if not Nuevo.Insert(true) then
            Error(ErrYaExiste, Nuevo."Cód. Parámetro", Nuevo."Vigencia Desde");

        // El Commit es obligatorio, no una precaución: abrir una página MODAL con la transacción de
        // escritura abierta —y el Insert de arriba la deja abierta— la corta con un "se produjo un
        // error y la transacción se detuvo", sin decir cuál. Confirmar acá además es lo coherente
        // con lo que ya pasa: la fila existe desde el Insert, se cancele o no la ficha.
        Commit();
        Page.RunModal(Page::"Ficha Valor Parámetro", Nuevo);
        CurrPage.Update(false);
    end;

    // La clave la calcula la tabla al insertar y al cambiar cualquier campo de alcance. Acá solo se
    // fija el parámetro base: con el alcance vacío, la clave queda igual al código base y esa fila
    // es el valor por defecto.
    trigger OnNewRecord(BelowxRec: Boolean)
    begin
        if FBaseCodigo = '' then exit;
        Rec."Cód. Parámetro Base" := FBaseCodigo;
        Rec.RecalcularClave();
        if Rec."Vigencia Desde" = 0D then
            Rec."Vigencia Desde" := WorkDate();
    end;

    procedure SetBaseCodigo(BaseCodigo: Code[20])
    begin
        FBaseCodigo := BaseCodigo;
        Rec.FilterGroup(2);
        Rec.SetRange("Cód. Parámetro Base", BaseCodigo);
        Rec.FilterGroup(0);
        CurrPage.Update(false);
    end;

    trigger OnAfterGetRecord()
    var
        Claves: Codeunit "Claves Parámetro Liq.";
    begin
        Alcance := DescribirAlcance();
        // Una clave que no coincide con lo que se derivaría de su alcance es inalcanzable para el
        // motor: se resalta acá para que no haya que abrir el diagnóstico para notarla.
        if Rec."Cód. Parámetro" <> Claves.ArmarDeFila(Rec) then
            EstiloClave := 'Attention'
        else
            if Rec.Nivel = 0 then
                EstiloClave := 'Strong'
            else
                EstiloClave := 'Standard';
    end;

    local procedure DescribirAlcance(): Text
    begin
        if Rec."No. Empleado" <> '' then
            exit(StrSubstNo(TxtEmpleado, Rec."No. Empleado"));
        if Rec."Cód. Categoría" <> '' then
            exit(StrSubstNo(TxtCCT, Rec."Cód. Convenio", Rec."Cód. Categoría"));
        if Rec."Cód. Convenio" <> '' then
            exit(StrSubstNo(TxtConvenio, Rec."Cód. Convenio"));
        exit(TxtDefecto);
    end;

    var
        FBaseCodigo: Code[20];
        Alcance: Text;
        EstiloClave: Text;
        TxtDefecto: Label 'Valor por defecto';
        ErrSinParametro: Label 'Abrí la ficha de un parámetro para cargarle valores.';
        ErrSinFila: Label 'Poné el cursor sobre un valor existente para crear una vigencia nueva. Si el parámetro todavía no tiene ninguno, usá "Nuevo valor...".';
        ErrYaExiste: Label 'Ya hay un valor para %1 con vigencia %2. Cambiale la fecha, o editá el que está.', Comment = '%1=clave derivada, %2=fecha de vigencia';
        TxtConvenio: Label 'Convenio %1';
        TxtCCT: Label 'Convenio %1, categoría %2';
        TxtEmpleado: Label 'Empleado %1';
}
