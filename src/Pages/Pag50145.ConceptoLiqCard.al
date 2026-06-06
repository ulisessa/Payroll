namespace UAS.Payroll;

page 50145 "Concepto Liq. Card"
{
    ApplicationArea = All;
    Caption = 'Concepto Liquidación';
    PageType = Card;
    SourceTable = "Concepto Liquidación";

    layout
    {
        area(Content)
        {
            group(GrpGeneral)
            {
                Caption = 'General';
                field(Código; Rec.Código) { ApplicationArea = All; }
                field("Vigencia Desde"; Rec."Vigencia Desde") { ApplicationArea = All; }
                field(Descripción; Rec.Descripción) { ApplicationArea = All; }
                field("Nombre Impresión"; Rec."Nombre Impresión") { ApplicationArea = All; }
                field("Variable Cantidad"; Rec."Variable Cantidad")
                {
                    ApplicationArea = All;
                    ToolTip = 'Variable del contexto que representa la cantidad (ej: DIAS_VAC, TONELADAS). Se imprime junto al importe en el recibo.';
                }
                field("Unidad Cantidad"; Rec."Unidad Cantidad")
                {
                    ApplicationArea = All;
                    ToolTip = 'Texto de la unidad (ej: días, tn). Acompaña la cantidad en el recibo.';
                }
                field("Tipo Concepto"; Rec."Tipo Concepto")
                {
                    ApplicationArea = All;
                    StyleExpr = TipoStyle;
                }
                field("Aplica A"; Rec."Aplica A") { ApplicationArea = All; }
                field("Aplica Tipo Liq."; Rec."Aplica Tipo Liq.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Tipo de liquidación al que aplica este concepto. Vacío = todos los tipos.';
                }
                field("Orden Cálculo"; Rec."Orden Cálculo") { ApplicationArea = All; }
                field(Activo; Rec.Activo) { ApplicationArea = All; }
                field("Es Acumulador"; Rec."Es Acumulador") { ApplicationArea = All; }
                field("Etiqueta Det. Ganancias"; Rec."Etiqueta Det. Ganancias")
                {
                    ApplicationArea = All;
                    ToolTip = 'Si se completa, el resultado de este concepto aparece como un paso de cálculo en el detalle de Ganancias del recibo de sueldo.';
                }
                field("Imprime en Recibo"; Rec."Imprime en Recibo")
                {
                    ApplicationArea = All;
                    ToolTip = 'Si está desactivado, el concepto no aparece en el recibo de sueldo aunque tenga importe. Por defecto activo (imprime).';
                }
            }
            group(GrpFormula)
            {
                Caption = 'Fórmula';
                field(Fórmula; Rec.Fórmula)
                {
                    ApplicationArea = All;
                    MultiLine = true;
                    ShowCaption = false;
                }
            }
            group(GrpCondicion)
            {
                Caption = 'Condición';
                field(Condición; Rec.Condición)
                {
                    ApplicationArea = All;
                    MultiLine = true;
                    ShowCaption = false;
                }
            }
            part(Fracciones; "Fracción Acumulador Sub")
            {
                ApplicationArea = All;
                Caption = 'Distribución en acumuladores';
                SubPageLink = "Cód. Concepto" = FIELD(Código), "Vigencia Desde" = FIELD("Vigencia Desde");
                Visible = not Rec."Es Acumulador";
            }
            part(Alimentadores; "Alimentadores Acumulador Sub")
            {
                ApplicationArea = All;
                Caption = 'Conceptos que alimentan este acumulador';
                SubPageLink = "Cód. Acumulador" = FIELD(Código);
                Visible = Rec."Es Acumulador";
            }
            part(ConveniosCCT; "Concepto CCT Sub")
            {
                ApplicationArea = All;
                Caption = 'Convenios aplicables (vacío = todos)';
                SubPageLink = "Cód. Concepto" = FIELD(Código), "Vigencia Desde" = FIELD("Vigencia Desde");
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(NuevaVigencia)
            {
                ApplicationArea = All;
                Caption = 'Nueva Vigencia';
                Image = NewRow;
                Promoted = true;
                PromotedCategory = New;
                ToolTip = 'Crea una nueva versión del concepto con la misma fórmula, lista para editar.';
                trigger OnAction()
                var
                    NuevoConcepto: Record "Concepto Liquidación";
                    DupCheck: Record "Concepto Liquidación";
                begin
                    Rec.TestField(Código);
                    if DupCheck.Get(Rec.Código, WorkDate()) then
                        Error(ErrVigenciaExiste, Rec.Código, WorkDate());
                    NuevoConcepto := Rec;
                    NuevoConcepto."Vigencia Desde" := WorkDate();
                    NuevoConcepto.Insert(true);
                    CurrPage.SetRecord(NuevoConcepto);
                    CurrPage.Update(false);
                end;
            }
            action(AsistenteFórmula)
            {
                ApplicationArea = All;
                Caption = 'Probar Fórmula';
                Image = PreviewChecks;
                Promoted = true;
                PromotedCategory = Process;
                trigger OnAction()
                var
                    Asistente: Page "Asistente Fórmula Liq.";
                begin
                    Asistente.SetFormula(Rec.Fórmula, Rec.Condición);
                    Asistente.RunModal();
                end;
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        case Rec."Tipo Concepto" of
            Rec."Tipo Concepto"::"Haber Remunerativo":
                TipoStyle := 'Favorable';
            Rec."Tipo Concepto"::"Haber No Remunerativo":
                TipoStyle := 'Subordinate';
            Rec."Tipo Concepto"::"Descuento Empleado",
            Rec."Tipo Concepto"::Retención:
                TipoStyle := 'Unfavorable';
            Rec."Tipo Concepto"::"Contribución Patronal":
                TipoStyle := 'Attention';
        end;
    end;

    var
        TipoStyle: Text;
        ErrVigenciaExiste: Label 'Ya existe una vigencia del concepto %1 con fecha %2. Insertá manualmente la nueva versión con otra fecha.';
}
