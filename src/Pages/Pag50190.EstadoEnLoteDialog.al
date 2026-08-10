namespace UAS.Payroll;

page 50190 "Estado en Lote Dialog"
{
    // Modal dialog to capture a state code + effective date for a batch/vessel state assignment.
    // The Cód. Estado lookup is filtered by Ámbito so vessels only see vessel-applicable states.
    PageType = StandardDialog;
    Caption = 'Establecer Estado en Lote';

    layout
    {
        area(Content)
        {
            group(g)
            {
                ShowCaption = false;

                field(CodEstado; CodEstado)
                {
                    ApplicationArea = All;
                    Caption = 'Estado';
                    NotBlank = true;
                    ToolTip = 'Estado a asignar a las entidades seleccionadas.';

                    trigger OnLookup(var Text: Text): Boolean
                    var
                        CodEst: Record "Cód. Estado Empleado";
                    begin
                        AplicarFiltroAmbito(CodEst);
                        if Page.RunModal(Page::"Cód. Estados Empleado", CodEst) = Action::LookupOK then begin
                            CodEstado := CodEst.Código;
                            exit(true);
                        end;
                    end;

                    trigger OnValidate()
                    var
                        CodEst: Record "Cód. Estado Empleado";
                    begin
                        if CodEstado <> '' then
                            CodEst.Get(CodEstado);
                    end;
                }
                field(FechaInicio; FechaInicio)
                {
                    ApplicationArea = All;
                    Caption = 'Fecha';
                    NotBlank = true;
                    ToolTip = 'Fecha efectiva desde la cual rige el estado (modelo effective-dated).';
                }
            }
        }
    }

    procedure Init(DefFecha: Date; EsBuque: Boolean)
    begin
        FechaInicio := DefFecha;
        FEsBuque := EsBuque;
    end;

    procedure GetResultado(var CodEstadoOut: Code[20]; var FechaOut: Date)
    begin
        CodEstadoOut := CodEstado;
        FechaOut := FechaInicio;
    end;

    local procedure AplicarFiltroAmbito(var CodEst: Record "Cód. Estado Empleado")
    begin
        CodEst.SetRange(Activo, true);
        if FEsBuque then
            CodEst.SetFilter("Ámbito", '%1|%2', CodEst."Ámbito"::Buque, CodEst."Ámbito"::Ambos)
        else
            CodEst.SetFilter("Ámbito", '%1|%2', CodEst."Ámbito"::Empleado, CodEst."Ámbito"::Ambos);
    end;

    var
        CodEstado: Code[20];
        FechaInicio: Date;
        FEsBuque: Boolean;
}
