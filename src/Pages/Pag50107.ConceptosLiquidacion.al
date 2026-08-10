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
                field("Tipos Liq. Aplicables"; Rec."Tipos Liq. Aplicables") { ApplicationArea = All; }
                field("Orden Cálculo"; Rec."Orden Cálculo") { ApplicationArea = All; }
                field(Activo; Rec.Activo) { ApplicationArea = All; }
                field(Fórmula; Rec.Fórmula) { ApplicationArea = All; }
                field(Condición; Rec.Condición) { ApplicationArea = All; Visible = false; }
                field("Es Acumulador"; Rec."Es Acumulador") { ApplicationArea = All; Visible = false; }
                field("Imprime en Recibo"; Rec."Imprime en Recibo") { ApplicationArea = All; }
                field("Es Devengo"; Rec."Es Devengo") { ApplicationArea = All; }
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
                    Dlg: Page "Nueva Vigencia Dialog";
                    FechaNueva: Date;
                begin
                    Rec.TestField(Código);
                    Dlg.SetFecha(WorkDate());
                    if Dlg.RunModal() <> Action::OK then exit;
                    FechaNueva := Dlg.GetFecha();
                    if FechaNueva = 0D then exit;
                    if DupCheck.Get(Rec.Código, FechaNueva) then
                        Error(ErrVigenciaExiste, Rec.Código, FechaNueva);
                    NuevoConcepto := Rec;
                    NuevoConcepto."Vigencia Desde" := FechaNueva;
                    NuevoConcepto.Insert(true);
                    Page.Run(Page::"Concepto Liq. Card", NuevoConcepto);
                    CurrPage.Update(false);
                end;
            }
            action(HistorialFórmulas)
            {
                ApplicationArea = All;
                Caption = 'Historial de Fórmulas';
                Image = History;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Filtra la lista para mostrar solo las versiones del concepto seleccionado con su fórmula y vigencia.';

                trigger OnAction()
                var
                    Historial: Record "Concepto Liquidación";
                    HistorialPage: Page "Conceptos Liquidación";
                begin
                    Rec.TestField(Código);
                    Historial.SetRange(Código, Rec.Código);
                    HistorialPage.SetTableView(Historial);
                    HistorialPage.Run();
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
            action(AsignarGrupoCosto)
            {
                ApplicationArea = All;
                Caption = 'Asignar Grupo Costo Laboral';
                Image = Category;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Asigna automáticamente el Grupo Costo Laboral a conceptos de Seguridad Social y Contribución Patronal según su descripción.';

                trigger OnAction()
                var
                    Concepto: Record "Concepto Liquidación";
                    Cant: Integer;
                    Desc: Text;
                begin
                    if not Confirm('¿Asignar Grupo Costo Laboral automáticamente a los conceptos que no lo tengan?') then
                        exit;

                    Concepto.SetRange("Grupo Costo Laboral", "Grupo Costo Laboral Liq."::" ");
                    Concepto.SetFilter("Tipo Concepto", '%1|%2',
                        Concepto."Tipo Concepto"::"Seguridad Social",
                        Concepto."Tipo Concepto"::"Contribución Patronal");
                    if Concepto.FindSet(true) then
                        repeat
                            Desc := LowerCase(Concepto.Descripción);
                            if Desc.Contains('obra social') or Desc.Contains('o.s.') then
                                Concepto."Grupo Costo Laboral" := "Grupo Costo Laboral Liq."::"Obra Social"
                            else if Desc.Contains('19032') or Desc.Contains('inssjp') or Desc.Contains('pami') then
                                Concepto."Grupo Costo Laboral" := "Grupo Costo Laboral Liq."::INSSJP
                            else if Desc.Contains('art') or Desc.Contains('lrt') then
                                Concepto."Grupo Costo Laboral" := "Grupo Costo Laboral Liq."::ART
                            else if Desc.Contains('scvo') or Desc.Contains('seguro colectivo') then
                                Concepto."Grupo Costo Laboral" := "Grupo Costo Laboral Liq."::SCVO
                            else
                                Concepto."Grupo Costo Laboral" := "Grupo Costo Laboral Liq."::"Seguridad Social";
                            Concepto.Modify();
                            Cant += 1;
                        until Concepto.Next() = 0;

                    Concepto.Reset();
                    Concepto.SetRange("Grupo Costo Laboral", "Grupo Costo Laboral Liq."::" ");
                    Concepto.SetFilter("Tipo Concepto", '%1', Concepto."Tipo Concepto"::"Descuento Empleado");
                    if Concepto.FindSet(true) then
                        repeat
                            Desc := LowerCase(Concepto.Descripción);
                            if Desc.Contains('sindical') or Desc.Contains('cuota sind') or
                               Desc.Contains('solidari') or Desc.Contains('caja comp') or
                               Desc.Contains('capacitacion') or Desc.Contains('fondo de desempleo')
                            then begin
                                Concepto."Grupo Costo Laboral" := "Grupo Costo Laboral Liq."::Sindical;
                                Concepto.Modify();
                                Cant += 1;
                            end;
                        until Concepto.Next() = 0;

                    Message('%1 concepto(s) actualizados.', Cant);
                    CurrPage.Update(false);
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
            Rec."Tipo Concepto"::"Deducción Remunerativa":
                TipoStyle := 'Ambiguous';
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
