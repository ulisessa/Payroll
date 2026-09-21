namespace UAS.Payroll;

// Los valores de parámetro vistos como árbol, que es la forma que ya tienen: cada clave derivada es
// una especialización de la de arriba.
//
//   BASICO                        valor por defecto
//     BASICO_175/75               excepción del convenio
//       BASICO_175/75_CAPITAN     excepción de la categoría
//     BASICO_E00123               excepción del empleado
//
// El orden del árbol sale solo de la clave primaria (base, clave derivada, vigencia): ordenada
// alfabéticamente, la clave derivada ya deja a cada hijo debajo de su padre. La indentación la da
// el campo Nivel, que se calcula junto con la clave.
//
// Es también la mejor forma de ver la cascada del motor: al resolver, se busca de la hoja hacia la
// raíz y gana la primera rama que tenga valor cargado a la fecha.
page 110013 "Árbol de Parámetros"
{
    ApplicationArea = All;
    Caption = 'Árbol de Parámetros';
    PageType = List;
    UsageCategory = Lists;
    SourceTable = "Parámetro Vigente";
    SourceTableView = sorting("Cód. Parámetro Base", "Cód. Parámetro", "Vigencia Desde");
    DelayedInsert = true;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                ShowAsTree = true;
                IndentationColumn = Rec.Nivel;
                IndentationControls = "Cód. Parámetro";

                field("Cód. Parámetro"; Rec."Cód. Parámetro")
                {
                    ApplicationArea = All;
                    Caption = 'Clave';
                    StyleExpr = EstiloFila;
                    ToolTip = 'Clave con la que el motor busca este valor. Se calcula sola a partir del parámetro base y de los campos de alcance.';
                }
                field("Cód. Parámetro Base"; Rec."Cód. Parámetro Base")
                {
                    ApplicationArea = All;
                    Caption = 'Parámetro';
                    ToolTip = 'Parámetro del que este valor es una especialización.';
                }
                field(Alcance; Alcance)
                {
                    ApplicationArea = All;
                    Caption = 'Alcance';
                    ToolTip = 'A quién aplica este valor. Vacío = valor por defecto del parámetro.';
                }
                field("Cód. Convenio"; Rec."Cód. Convenio") { ApplicationArea = All; }
                field("Cód. Categoría"; Rec."Cód. Categoría") { ApplicationArea = All; }
                field("No. Empleado"; Rec."No. Empleado") { ApplicationArea = All; }
                field("Vigencia Desde"; Rec."Vigencia Desde") { ApplicationArea = All; }
                field(Valor; Rec.Valor)
                {
                    ApplicationArea = All;
                    StyleExpr = EstiloFila;
                }
                field(Moneda; Rec.Moneda) { ApplicationArea = All; }
                field("En Uso"; Rec."En Uso")
                {
                    ApplicationArea = All;
                    ToolTip = 'Marcado cuando este valor ya fue utilizado en una liquidación registrada. Los valores en uso no se pueden modificar: hay que cargar una vigencia nueva.';
                }
                field(Descripción; Rec.Descripción) { ApplicationArea = All; }
                field(Nivel; Rec.Nivel)
                {
                    ApplicationArea = All;
                    Visible = false;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(RecalcularNiveles)
            {
                ApplicationArea = All;
                Caption = 'Recalcular niveles del árbol';
                Image = Refresh;
                ToolTip = 'Recalcula la indentación de todas las filas. Hace falta una única vez, sobre los valores cargados antes de que existiera el árbol: solo toca la columna de nivel, nunca la clave ni el valor.';
                trigger OnAction()
                var
                    Claves: Codeunit "Claves Parámetro Liq.";
                    Actualizadas: Integer;
                begin
                    Actualizadas := Claves.RecalcularNiveles();
                    Message(MsgNiveles, Actualizadas);
                    CurrPage.Update(false);
                end;
            }
            action(RevisarClaves)
            {
                ApplicationArea = All;
                Caption = 'Revisar claves inconsistentes';
                Image = CheckList;
                ToolTip = 'Lista los valores cuya clave derivada no coincide con sus campos de alcance. Esas filas son inalcanzables para el motor: el cálculo cae al valor genérico sin ningún aviso.';
                RunObject = Page "Claves de Parámetro a Revisar";
            }
            action(NuevaEspecializacion)
            {
                ApplicationArea = All;
                Caption = 'Nueva especialización';
                Image = Hierarchy;
                ToolTip = 'Crea un valor más específico a partir de la fila seleccionada, heredando su parámetro base y su alcance.';
                trigger OnAction()
                begin
                    CrearEspecializacion();
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Proceso';
                actionref(NuevaEspecializacionProm; NuevaEspecializacion) { }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        Alcance := DescribirAlcance();
        // La raíz de cada parámetro se resalta: es el valor por defecto, el que aplica a todo lo que
        // no tenga una excepción cargada.
        if Rec.Nivel = 0 then
            EstiloFila := 'Strong'
        else
            EstiloFila := 'Standard';
    end;

    trigger OnNewRecord(BelowxRec: Boolean)
    begin
        if Rec."Vigencia Desde" = 0D then
            Rec."Vigencia Desde" := WorkDate();
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

    // Hereda el alcance de la fila desde la que se crea, para que la especialización nazca en la
    // rama correcta en vez de tener que recomponerla a mano.
    local procedure CrearEspecializacion()
    var
        Nueva: Record "Parámetro Vigente";
    begin
        Rec.TestField("Cód. Parámetro Base");
        Nueva.Init();
        Nueva."Cód. Parámetro Base" := Rec."Cód. Parámetro Base";
        Nueva."Cód. Convenio" := Rec."Cód. Convenio";
        Nueva."Cód. Categoría" := Rec."Cód. Categoría";
        Nueva."Vigencia Desde" := Rec."Vigencia Desde";
        Nueva.Valor := Rec.Valor;
        Nueva.Moneda := Rec.Moneda;
        Nueva.RecalcularClave();
        Page.Run(Page::"Ficha Valor Parámetro", Nueva);
        CurrPage.Update(false);
    end;

    var
        Alcance: Text;
        EstiloFila: Text;
        TxtDefecto: Label 'Valor por defecto';
        TxtConvenio: Label 'Convenio %1';
        TxtCCT: Label 'Convenio %1, categoría %2';
        TxtEmpleado: Label 'Empleado %1';
        MsgNiveles: Label '%1 fila(s) actualizada(s). Solo se recalculó la indentación: ninguna clave ni valor se modificó.';
}
