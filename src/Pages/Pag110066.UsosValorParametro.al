namespace UAS.Payroll;

// Dónde se está usando un valor de parámetro que figura "En Uso": las liquidaciones que lo resolvieron.
//
// "En Uso" es una marca que bloquea editar el valor, pero hasta ahora no decía POR QUÉ: quien la veía
// no tenía forma de saber qué liquidación la sostenía, y liberarla a ciegas es justo lo que el
// registro de uso existe para evitar. La tabla "Uso Parámetro Liq." guarda, por cada liquidación, la
// versión concreta que usó cada variable; acá se la lee desde la versión hacia las liquidaciones.
page 110066 "Usos Valor Parámetro"
{
    ApplicationArea = All;
    Caption = 'Dónde se usa este valor';
    PageType = List;
    SourceTable = "Uso Parámetro Liq.";
    SourceTableView = sorting("Cód. Parámetro", "Vigencia Desde", "No. Liquidación");
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;
    Editable = false;

    layout
    {
        area(Content)
        {
            group(GrpResumen)
            {
                ShowCaption = false;
                field(Resumen; Resumen)
                {
                    ApplicationArea = All;
                    Caption = 'Resumen';
                    Editable = false;
                    Style = Strong;
                    MultiLine = true;
                }
                field(AvisoSinRegistro; AvisoSinRegistro)
                {
                    ApplicationArea = All;
                    Caption = 'Aviso';
                    Editable = false;
                    Visible = AvisoSinRegistro <> '';
                    Style = Attention;
                    MultiLine = true;
                }
            }
            repeater(Lines)
            {
                field("No. Liquidación"; Rec."No. Liquidación")
                {
                    ApplicationArea = All;
                    ToolTip = 'La liquidación que resolvió este valor. Hacé clic para abrirla.';

                    trigger OnDrillDown()
                    begin
                        AbrirLiquidacion();
                    end;
                }
                field(Empleado; LiqNoEmpleado) { ApplicationArea = All; Caption = 'No. Empleado'; }
                field(NombreEmpleado; LiqNombre) { ApplicationArea = All; Caption = 'Nombre'; }
                field(Periodo; LiqPeriodo) { ApplicationArea = All; Caption = 'Período'; }
                field(Tipo; LiqTipo) { ApplicationArea = All; Caption = 'Tipo Liquidación'; }
                field(Estado; LiqEstado)
                {
                    ApplicationArea = All;
                    Caption = 'Estado';
                    ToolTip = 'Una liquidación en Borrador ya no bloquea el valor: sólo cuentan las Calculadas, Aprobadas y Contabilizadas.';
                    StyleExpr = EstadoStyle;
                }
                field("Nombre Variable"; Rec."Nombre Variable") { ApplicationArea = All; }
                field("Cód. Parámetro"; Rec."Cód. Parámetro") { ApplicationArea = All; Visible = false; }
                field("Vigencia Desde"; Rec."Vigencia Desde") { ApplicationArea = All; Visible = false; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(AbrirLiq)
            {
                ApplicationArea = All;
                Caption = 'Abrir liquidación';
                Image = Document;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Abre la ficha de la liquidación de la fila.';

                trigger OnAction()
                begin
                    AbrirLiquidacion();
                end;
            }
        }
    }

    trigger OnOpenPage()
    begin
        CalcularResumen();
    end;

    trigger OnAfterGetRecord()
    var
        Liq: Record "Liquidación";
    begin
        Clear(LiqNoEmpleado);
        Clear(LiqNombre);
        Clear(LiqPeriodo);
        Clear(LiqTipo);
        LiqEstado := '';
        EstadoStyle := 'Standard';
        if not Liq.Get(Rec."No. Liquidación") then
            exit;
        LiqNoEmpleado := Liq."No. Empleado";
        LiqNombre := Liq."Nombre Empleado";
        LiqPeriodo := Liq."Cód. Período";
        LiqTipo := Liq."Cód. Tipo Liq.";
        LiqEstado := Format(Liq.Estado);
        if Liq.Estado = Liq.Estado::Borrador then
            EstadoStyle := 'Subordinate'
        else
            EstadoStyle := 'Favorable';
    end;

    local procedure AbrirLiquidacion()
    var
        Liq: Record "Liquidación";
    begin
        if Liq.Get(Rec."No. Liquidación") then
            Page.Run(Page::"Ficha Liquidación", Liq);
    end;

    // Cuántas liquidaciones sostienen el valor y, aparte, cuántas liquidaciones activas NO tienen
    // registro de uso: las que se calcularon antes de que existiera la tabla. De ésas no se puede
    // decir qué versiones usaron, y el valor puede seguir "En Uso" por culpa de una de ellas sin que
    // acá aparezca. Es el único caso en que una pantalla vacía no quiere decir "nadie lo usa".
    local procedure CalcularResumen()
    var
        UsoFiltrado: Record "Uso Parámetro Liq.";
        Liq: Record "Liquidación";
        Uso: Record "Uso Parámetro Liq.";
        Total: Integer;
        Activas: Integer;
        SinRegistro: Integer;
    begin
        UsoFiltrado.CopyFilters(Rec);
        Total := UsoFiltrado.Count();
        Resumen := StrSubstNo(TxtResumen, Total);

        Liq.SetFilter(Estado, '%1|%2|%3', Liq.Estado::Calculada, Liq.Estado::Aprobada, Liq.Estado::Contabilizada);
        // HIST_REMUN queda afuera: es la historia importada de Meta4 (más de 10.000 cabeceras), no la
        // calculó el motor ni usó ningún parámetro, y contarla haría saltar el aviso siempre.
        Liq.SetFilter("Cód. Tipo Liq.", '<>%1', 'HIST_REMUN');
        Liq.SetLoadFields("No.");
        if Liq.FindSet() then
            repeat
                Activas += 1;
                Uso.SetRange("No. Liquidación", Liq."No.");
                if Uso.IsEmpty() then
                    SinRegistro += 1;
            until Liq.Next() = 0;
        if SinRegistro > 0 then
            AvisoSinRegistro := StrSubstNo(TxtSinRegistro, SinRegistro, Activas)
        else
            AvisoSinRegistro := '';
    end;

    var
        Resumen: Text;
        AvisoSinRegistro: Text;
        LiqNoEmpleado: Code[20];
        LiqNombre: Text[100];
        LiqPeriodo: Code[10];
        LiqTipo: Code[20];
        LiqEstado: Text;
        EstadoStyle: Text;
        TxtResumen: Label '%1 liquidación(es) resolvieron este valor. Mientras alguna esté Calculada, Aprobada o Contabilizada el valor queda "En Uso".', Comment = '%1 = cantidad de liquidaciones';
        TxtSinRegistro: Label '%1 de %2 liquidaciones activas se calcularon antes de que existiera el registro de uso y no figuran acá: pueden estar usando este valor sin que se vea. Recalcularlas las incorpora.', Comment = '%1 = sin registro, %2 = activas';
}
