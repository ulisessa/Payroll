namespace UAS.Payroll;

page 110019 "Ficha Entidad"
{
    ApplicationArea = All;
    Caption = 'Entidad';
    PageType = Card;
    SourceTable = "Entidad Liq.";
    InsertAllowed = false;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';

                field(Código; Rec.Código)
                {
                    ApplicationArea = All;
                    ToolTip = 'Coincide siempre con el valor de dimensión del que nace. Para cambiarlo, renombrá ese valor: el código se arrastra hasta acá y hasta los estados y atributos.';
                }
                field(Descripción; Rec.Descripción) { ApplicationArea = All; }
                field("Cód. Clase"; Rec."Cód. Clase")
                {
                    ApplicationArea = All;
                    Caption = 'Clase';
                    ToolTip = 'Define qué atributos le corresponden a esta entidad.';
                }
                field(EstadoActual; EstadoActual)
                {
                    ApplicationArea = All;
                    Caption = 'Estado actual';
                    Editable = false;
                }
            }
            part(AtributosVigentes; "Atributos Entidad FactBox")
            {
                ApplicationArea = All;
                Caption = 'Atributos vigentes';
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(AplicarPlantilla)
            {
                ApplicationArea = All;
                Caption = 'Aplicar plantilla de atributos';
                Image = Apply;
                ToolTip = 'Crea los atributos obligatorios de la clase que todavía no estén cargados.';
                trigger OnAction()
                var
                    Plantilla: Codeunit "Plantilla Atributos Liq.";
                    Creados: Integer;
                begin
                    Creados := Plantilla.Aplicar(
                        "Tipo Entidad Estado"::Buque, Rec.Código, Rec."Cód. Clase", WorkDate());
                    if Creados = 0 then
                        Message(MsgNadaQueCrear)
                    else
                        Message(MsgCreados, Creados);
                    CurrPage.Update(false);
                end;
            }
        }
        area(Navigation)
        {
            action(VerHistorialEstados)
            {
                ApplicationArea = All;
                Caption = 'Historial de estados';
                Image = History;
                trigger OnAction()
                var
                    HistPage: Page "Estados de Buque";
                begin
                    HistPage.SetBuque(Rec.Código);
                    HistPage.Run();
                end;
            }
        }
    }

    trigger OnAfterGetCurrRecord()
    var
        EstadoEmp: Record "Estado Empleado";
        EstadoMgt: Codeunit "Gestión Estado Empleado";
    begin
        CurrPage.AtributosVigentes.Page.SetEntidad("Tipo Entidad Estado"::Buque, Rec.Código);
        if EstadoMgt.GetEstadoEntidad("Tipo Entidad Estado"::Buque, Rec.Código, WorkDate(), EstadoEmp) then
            EstadoActual := EstadoEmp."Cód. Estado"
        else
            EstadoActual := '';
    end;

    var
        EstadoActual: Code[20];
        MsgNadaQueCrear: Label 'Esta entidad ya tiene todos los atributos obligatorios de su clase.';
        MsgCreados: Label '%1 atributo(s) creado(s). Quedan vacíos: cargá el valor y la vigencia en cada uno.';
}
