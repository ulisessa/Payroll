namespace UAS.Payroll;

page 50135 "Nuevo Estado Empleado"
{
    // Used modally via RunModal() to collect state code and start date,
    // then the caller invokes GestionEstadoEmpleado.SetEstado.
    // Returns Action::LookupOK when the user confirms.
    ApplicationArea = All;
    Caption = 'Establecer Nuevo Estado';
    PageType = Card;
    SourceTable = "Estado Empleado";
    SourceTableTemporary = true;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = '';

                field("Nombre Empleado"; NombreEmpleado)
                {
                    ApplicationArea = All;
                    Caption = 'Empleado';
                    Editable = false;
                }
                field("Cód. Estado"; Rec."Cód. Estado")
                {
                    ApplicationArea = All;
                    Caption = 'Nuevo Estado';
                    NotBlank = true;
                }
                field("Fecha Inicio"; Rec."Fecha Inicio")
                {
                    ApplicationArea = All;
                    Caption = 'Fecha Inicio';
                    NotBlank = true;
                }
                field(Observaciones; Rec.Observaciones)
                {
                    ApplicationArea = All;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Confirmar)
            {
                ApplicationArea = All;
                Caption = 'Confirmar';
                Image = Approve;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;

                trigger OnAction()
                begin
                    Rec.TestField("Cód. Estado");
                    Rec.TestField("Fecha Inicio");
                    CurrPage.Close();
                end;
            }
        }
    }

    procedure SetEmpleado(EmployeeNo: Code[20]; Nombre: Text[100])
    begin
        Rec.Init();
        Rec."No. Empleado" := EmployeeNo;
        Rec."Fecha Inicio" := WorkDate();
        Rec.Insert();
        NombreEmpleado := Nombre;
    end;

    procedure GetResultado(var CodEstado: Code[20]; var FechaInicio: Date; var Obs: Text[250])
    begin
        CodEstado := Rec."Cód. Estado";
        FechaInicio := Rec."Fecha Inicio";
        Obs := Rec.Observaciones;
    end;

    var
        NombreEmpleado: Text[100];
}
