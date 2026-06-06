namespace UAS.Payroll;

page 50107 "Conceptos Liquidación"
{
    ApplicationArea = All;
    Caption = 'Conceptos Liquidación';
    CardPageId = "Concepto Liq. Card";
    PageType = List;
    SourceTable = "Concepto Liquidación";
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(Código; Rec.Código) { ApplicationArea = All; }
                field("Vigencia Desde"; Rec."Vigencia Desde") { ApplicationArea = All; }
                field(Descripción; Rec.Descripción) { ApplicationArea = All; }
                field("Nombre Impresión"; Rec."Nombre Impresión") { ApplicationArea = All; }
                field("Tipo Concepto"; Rec."Tipo Concepto")
                {
                    ApplicationArea = All;
                    StyleExpr = TipoStyle;
                }
                field("Aplica A"; Rec."Aplica A") { ApplicationArea = All; }
                field("Aplica Tipo Liq."; Rec."Aplica Tipo Liq.") { ApplicationArea = All; }
                field("Orden Cálculo"; Rec."Orden Cálculo") { ApplicationArea = All; }
                field(Activo; Rec.Activo) { ApplicationArea = All; }
                field(Fórmula; Rec.Fórmula) { ApplicationArea = All; }
                field(Condición; Rec.Condición) { ApplicationArea = All; Visible = false; }
                field("Es Acumulador"; Rec."Es Acumulador") { ApplicationArea = All; Visible = false; }
                field("Imprime en Recibo"; Rec."Imprime en Recibo") { ApplicationArea = All; Visible = false; }
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
                ToolTip = 'Crea una nueva versión del concepto con la misma fórmula, lista para editar. La versión anterior se conserva para auditoría.';

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
                    Page.Run(Page::"Concepto Liq. Card", NuevoConcepto);
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
                ToolTip = 'Abre el asistente de fórmulas con la fórmula y condición del concepto seleccionado pre-cargadas.';

                trigger OnAction()
                var
                    Asistente: Page "Asistente Fórmula Liq.";
                begin
                    Asistente.SetFormula(Rec.Fórmula, Rec.Condición);
                    Asistente.Run();
                end;
            }
            action(ActivarImprimeEnRecibo)
            {
                ApplicationArea = All;
                Caption = 'Activar "Imprime en Recibo" en todos';
                Image = Approve;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Marca "Imprime en Recibo" = Sí en todos los conceptos existentes. Ejecutar una sola vez luego de actualizar la extensión.';

                trigger OnAction()
                var
                    Concepto: Record "Concepto Liquidación";
                    Cant: Integer;
                begin
                    if not Confirm('¿Activar "Imprime en Recibo" en todos los conceptos existentes?') then
                        exit;
                    Concepto.SetRange("Imprime en Recibo", false);
                    Cant := Concepto.Count();
                    Concepto.ModifyAll("Imprime en Recibo", true);
                    Message('%1 concepto(s) actualizados.', Cant);
                    CurrPage.Update(false);
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
        ErrVigenciaExiste: Label 'Ya existe una vigencia del concepto %1 con fecha %2. Insertá manualmente la nueva versión con otra fecha desde la lista.';
}
