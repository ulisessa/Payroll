namespace UAS.Payroll;

// Buques, plantas y administraciones. Una entidad por valor de dimensión.
//
// No se dan de alta desde acá: se crean desde el valor de dimensión, que es el que fija el código.
// Por eso la lista no permite insertar — el alta suelta produciría entidades con códigos que no le
// corresponden a ningún buque ni planta.
page 110018 Entidades
{
    ApplicationArea = All;
    Caption = 'Entidades';
    PageType = List;
    UsageCategory = Lists;
    SourceTable = "Entidad Liq.";
    CardPageId = "Ficha Entidad";
    InsertAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(Código; Rec.Código) { ApplicationArea = All; }
                field(Descripción; Rec.Descripción) { ApplicationArea = All; }
                field("Cód. Clase"; Rec."Cód. Clase")
                {
                    ApplicationArea = All;
                    Caption = 'Clase';
                    ToolTip = 'Qué clase de entidad es. Define qué atributos le corresponden y cuál es su plantilla.';
                }
                field(EstadoActual; EstadoActual)
                {
                    ApplicationArea = All;
                    Caption = 'Estado Actual';
                    Editable = false;
                }
                field(Atributos; AtributosTxt)
                {
                    ApplicationArea = All;
                    Caption = 'Atributos';
                    Editable = false;
                    StyleExpr = AtributosStyle;
                    ToolTip = 'Cuántos atributos obligatorios de su clase todavía no tiene cargados.';
                }
            }
        }
    }

    actions
    {
        area(Navigation)
        {
            action(VerAtributos)
            {
                ApplicationArea = All;
                Caption = 'Atributos';
                Image = List;
                ToolTip = 'Atributos de esta entidad, con su historial de vigencias.';
                trigger OnAction()
                var
                    Atributo: Record "Atributo Entidad Liq.";
                begin
                    Atributo.SetRange("Tipo Entidad", Atributo."Tipo Entidad"::Buque);
                    Atributo.SetRange("Cód. Entidad", Rec.Código);
                    Page.Run(Page::"Atributos de Entidad", Atributo);
                end;
            }
            action(VerHistorialEstados)
            {
                ApplicationArea = All;
                Caption = 'Historial de estados';
                Image = History;
                ToolTip = 'Historial de estados operativos de esta entidad.';
                trigger OnAction()
                var
                    HistPage: Page "Estados de Buque";
                begin
                    HistPage.SetBuque(Rec.Código);
                    HistPage.Run();
                end;
            }
        }
        area(Processing)
        {
            action(EstablecerEstadoLote)
            {
                ApplicationArea = All;
                Caption = 'Establecer estado';
                Image = Change;
                ToolTip = 'Asigna un estado operativo a las entidades seleccionadas en una fecha, y lo propaga a los empleados asignados a los proyectos activos de cada una.';

                trigger OnAction()
                var
                    EntidadSel: Record "Entidad Liq.";
                    EstadoMgt: Codeunit "Gestión Estado Empleado";
                    Dlg: Page "Estado en Lote Dialog";
                    CodEstado: Code[20];
                    Fecha: Date;
                    Cantidad: Integer;
                begin
                    CurrPage.SetSelectionFilter(EntidadSel);
                    if EntidadSel.IsEmpty() then
                        exit;

                    Dlg.Init(WorkDate(), true);
                    if Dlg.RunModal() <> Action::OK then
                        exit;
                    Dlg.GetResultado(CodEstado, Fecha);
                    if (CodEstado = '') or (Fecha = 0D) then
                        exit;

                    Cantidad := EstadoMgt.SetEstadoEnLoteEntidades(EntidadSel, CodEstado, Fecha);
                    Message(MsgEstadoAplicado, Cantidad, CodEstado, Fecha);
                    CurrPage.Update(false);
                end;
            }
            action(AplicarPlantilla)
            {
                ApplicationArea = All;
                Caption = 'Aplicar plantilla de atributos';
                Image = Apply;
                ToolTip = 'Crea los atributos obligatorios de la clase que todavía no estén cargados. No modifica ninguno existente.';
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
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Proceso';
                actionref(EstablecerEstadoProm; EstablecerEstadoLote) { }
                actionref(VerAtributosProm; VerAtributos) { }
                actionref(AplicarPlantillaProm; AplicarPlantilla) { }
                actionref(VerHistorialProm; VerHistorialEstados) { }
            }
        }
    }

    trigger OnAfterGetRecord()
    var
        EstadoEmp: Record "Estado Empleado";
        EstadoMgt: Codeunit "Gestión Estado Empleado";
        Plantilla: Codeunit "Plantilla Atributos Liq.";
        Faltan: Integer;
    begin
        if EstadoMgt.GetEstadoEntidad("Tipo Entidad Estado"::Buque, Rec.Código, WorkDate(), EstadoEmp) then
            EstadoActual := EstadoEmp."Cód. Estado"
        else
            EstadoActual := '';

        Faltan := Plantilla.ContarFaltantes("Tipo Entidad Estado"::Buque, Rec.Código, Rec."Cód. Clase");
        if Faltan = 0 then begin
            AtributosTxt := TxtCompletos;
            AtributosStyle := 'Standard';
        end else begin
            AtributosTxt := StrSubstNo(TxtFaltan, Faltan);
            AtributosStyle := 'Ambiguous';
        end;
    end;

    var
        EstadoActual: Code[20];
        AtributosTxt: Text;
        AtributosStyle: Text;
        TxtCompletos: Label 'Completos';
        TxtFaltan: Label 'Faltan %1';
        MsgEstadoAplicado: Label '%1 entidad(es) actualizada(s) al estado ''%2'' desde %3, con propagación a los empleados.';
        MsgNadaQueCrear: Label 'Esta entidad ya tiene todos los atributos obligatorios de su clase.';
        MsgCreados: Label '%1 atributo(s) creado(s). Quedan vacíos: cargá el valor y la vigencia en cada uno.';
}
