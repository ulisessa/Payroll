namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;

report 50042 "Asignar Estado Masivo"
{
    ApplicationArea = All;
    Caption = 'Asignar Estado Masivo';
    UsageCategory = Tasks;
    ProcessingOnly = true;

    dataset
    {
        dataitem(Empleado; Employee)
        {
            RequestFilterFields = "No.", Status;

            dataitem(PersonalProy; "Personal Proyecto")
            {
                DataItemLink = "No. Empleado" = field("No.");
                RequestFilterFields = "No. Proyecto";

                trigger OnAfterGetRecord()
                begin
                    if ProcessedEmployees.Contains(Empleado."No.") then
                        exit;
                    ProcessedEmployees.Add(Empleado."No.");
                    Progress.Update(1, Empleado."First Name" + ' ' + Empleado."Last Name");
                    Progress.Update(2, Procesados);
                    EstadoMgt.SetEstado(Empleado."No.", CodEstado, FechaInicio);
                    Contador += 1;
                    Procesados += 1;
                end;
            }

            trigger OnPreDataItem()
            begin
                if CodEstado = '' then
                    Error(ErrFaltaEstado);
                if FechaInicio = 0D then
                    Error(ErrFaltaFecha);
                EstadoMgt.SetSkipConflicts(OmitirConflictos);
                Progress.Open(DlgProgreso);
            end;

            trigger OnPostDataItem()
            begin
                Progress.Close();
            end;
        }
    }

    requestpage
    {
        layout
        {
            area(Content)
            {
                group(Opciones)
                {
                    Caption = 'Opciones';

                    field(CodEstadoField; CodEstado)
                    {
                        ApplicationArea = All;
                        Caption = 'Cód. Estado';
                        TableRelation = "Cód. Estado Empleado".Código;
                        ToolTip = 'Estado que se asignará a los empleados seleccionados.';
                    }
                    field(FechaInicioField; FechaInicio)
                    {
                        ApplicationArea = All;
                        Caption = 'Fecha Inicio';
                        ToolTip = 'Fecha de inicio del nuevo estado.';
                    }
                    field(OmitirConflictosField; OmitirConflictos)
                    {
                        ApplicationArea = All;
                        Caption = 'Omitir conflictos';
                        ToolTip = 'Si está activo, los empleados con un estado en conflicto (fecha cubierta o mismo inicio) se omiten sin preguntar.';
                    }
                }
            }
        }

        trigger OnOpenPage()
        begin
            FechaInicio := WorkDate();
        end;
    }

    trigger OnPostReport()
    begin
        Message(MsgResultado, Contador, Procesados - Contador);
    end;

    var
        EstadoMgt: Codeunit "Gestión Estado Empleado";
        Progress: Dialog;
        ProcessedEmployees: List of [Code[20]];
        CodEstado: Code[20];
        FechaInicio: Date;
        OmitirConflictos: Boolean;
        Contador: Integer;
        Procesados: Integer;
        DlgProgreso: Label 'Asignando estados...\\Empleado: #1########\\Procesados: #2###';
        ErrFaltaEstado: Label 'Debe seleccionar un código de estado.';
        ErrFaltaFecha: Label 'Debe indicar la fecha de inicio.';
        MsgResultado: Label 'Se asignó el estado a %1 empleado(s). %2 omitido(s) por conflicto.';
}
