namespace UAS.Payroll;

using Microsoft.Finance.Dimension;
using Microsoft.Finance.GeneralLedger.Setup;

page 50191 "Buques"
{
    // Vessels are Global Dimension 1 values (there is no vessel master). This page lists them and lets
    // the liquidador set an operational state for one or many vessels at once; the state cascades to the
    // employees assigned to each vessel's active projects.
    PageType = List;
    Caption = 'Buques';
    SourceTable = "Dimension Value";
    UsageCategory = Lists;
    ApplicationArea = All;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(Code; Rec.Code)
                {
                    ApplicationArea = All;
                    Caption = 'Buque';
                }
                field(Name; Rec.Name)
                {
                    ApplicationArea = All;
                    Caption = 'Nombre';
                }
                field("Estado Actual"; EstadoActualMostrado)
                {
                    ApplicationArea = All;
                    Caption = 'Estado Actual';
                    Editable = false;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(EstablecerEstadoLote)
            {
                ApplicationArea = All;
                Caption = 'Establecer estado';
                Image = Change;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                ToolTip = 'Asigna un estado a los buques seleccionados en una fecha, y lo propaga a los empleados asignados a los proyectos activos de cada buque.';

                trigger OnAction()
                var
                    DimValueSel: Record "Dimension Value";
                    EstadoMgt: Codeunit "Gestión Estado Empleado";
                    Dlg: Page "Estado en Lote Dialog";
                    CodEstado: Code[20];
                    Fecha: Date;
                    Cantidad: Integer;
                begin
                    CurrPage.SetSelectionFilter(DimValueSel);
                    if DimValueSel.IsEmpty() then exit;

                    Dlg.Init(WorkDate(), true);
                    if Dlg.RunModal() <> Action::OK then exit;
                    Dlg.GetResultado(CodEstado, Fecha);
                    if (CodEstado = '') or (Fecha = 0D) then exit;

                    Cantidad := EstadoMgt.SetEstadoEnLoteBuques(DimValueSel, CodEstado, Fecha);
                    Message(MsgAplicado, Cantidad, CodEstado, Fecha);
                    CurrPage.Update(false);
                end;
            }
            action(VerHistorial)
            {
                ApplicationArea = All;
                Caption = 'Ver historial';
                Image = History;
                ToolTip = 'Muestra el historial de estados del buque seleccionado.';

                trigger OnAction()
                var
                    HistPage: Page "Estados de Buque";
                begin
                    HistPage.SetBuque(Rec.Code);
                    HistPage.Run();
                end;
            }
        }
    }

    trigger OnOpenPage()
    var
        GLSetup: Record "General Ledger Setup";
    begin
        GLSetup.Get();
        GLSetup.TestField("Global Dimension 1 Code");
        Rec.FilterGroup(2);
        Rec.SetRange("Dimension Code", GLSetup."Global Dimension 1 Code");
        Rec.SetRange("Dimension Value Type", Rec."Dimension Value Type"::Standard);
        Rec.FilterGroup(0);
    end;

    trigger OnAfterGetRecord()
    var
        EstadoEmp: Record "Estado Empleado";
        EstadoMgt: Codeunit "Gestión Estado Empleado";
    begin
        if EstadoMgt.GetEstadoEntidad(EstadoEmp."Tipo Entidad"::Buque, Rec.Code, WorkDate(), EstadoEmp) then
            EstadoActualMostrado := EstadoEmp."Cód. Estado"
        else
            EstadoActualMostrado := '';
    end;

    var
        EstadoActualMostrado: Code[20];
        MsgAplicado: Label '%1 buque(s) actualizados al estado ''%2'' desde %3 (con propagación a empleados).';
}
