namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;

// Las fases de alta de un empleado: una fila por tramo entre un alta y su baja.
//
// ANTES ERA UNA VISTA, AHORA ES LA FUENTE. Las altas y las bajas vivían como filas del historial de
// estados y esta página las apareaba en memoria. Desde que son su propia tabla, acá se cargan y se
// corrigen: el historial de estados dejó de aceptarlas, porque mezclar "cuándo pertenece a la
// empresa" con "qué estaba haciendo ese día" hacía que las dos cosas compitieran por la misma fecha.
//
// De acá sale la antigüedad. Lo que se ve en esta grilla y lo que se paga no pueden discrepar.
page 110028 "Fases de Alta"
{
    ApplicationArea = All;
    Caption = 'Fases de Alta';
    PageType = List;
    UsageCategory = Lists;
    SourceTable = "Fase Alta Empleado";
    // Sin Editable = false a nivel página: apagaría también el filtro de la cabecera, que no está
    // ligado al registro.

    layout
    {
        area(Content)
        {
            group(Filtro)
            {
                ShowCaption = false;

                field(FEmpleado; FEmpleado)
                {
                    ApplicationArea = All;
                    Caption = 'Cód. Legajo';
                    TableRelation = Employee."No.";
                    ToolTip = 'El empleado cuyas fases se muestran.';

                    trigger OnValidate()
                    begin
                        AplicarFiltro();
                    end;
                }
                field(FFechaRef; FFechaRef)
                {
                    ApplicationArea = All;
                    Caption = 'Antigüedad al';
                    ToolTip = 'Fecha contra la que se mide la fase abierta y el total de antigüedad.';

                    trigger OnValidate()
                    begin
                        AplicarFiltro();
                    end;
                }
                field(TotalTexto; TotalTexto)
                {
                    ApplicationArea = All;
                    Caption = 'Antigüedad acumulada';
                    Editable = false;
                    ToolTip = 'Lo que suma el motor con estas fases más la Antigüedad Reconocida cargada en el legajo. Es el número que usan las fórmulas.';
                }
            }

            repeater(Fases)
            {
                field("No. Empleado"; Rec."No. Empleado")
                {
                    ApplicationArea = All;
                    Visible = false;
                    ToolTip = 'El legajo. Está oculto porque la grilla ya está filtrada por el legajo de arriba.';
                }
                field("No. Fase"; Rec."No. Fase")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Correlativo por empleado. La primera fase de cada persona es la 1.';
                }
                field("Fecha Alta"; Rec."Fecha Alta")
                {
                    ApplicationArea = All;
                    ToolTip = 'Cuándo empezó esta relación laboral.';
                }
                field("Cód. Motivo Alta"; Rec."Cód. Motivo Alta") { ApplicationArea = All; }
                field("Fecha Baja"; Rec."Fecha Baja")
                {
                    ApplicationArea = All;
                    StyleExpr = EstiloAbierta;
                    ToolTip = 'Vacía = la fase sigue abierta y la persona sigue en la empresa. Cargarla cierra el tramo y frena la antigüedad.';
                }
                field("Cód. Motivo Baja"; Rec."Cód. Motivo Baja")
                {
                    ApplicationArea = All;
                    ToolTip = 'De acá salen los atributos indemnizatorios de la baja.';
                }
                field(Días; Rec.Días)
                {
                    ApplicationArea = All;
                    ToolTip = 'Días calendario de la fase cerrada. La fase abierta va en cero: sus días dependen de contra qué fecha se midan, y eso lo resuelve el total de arriba.';
                }
                field(Abierta; Rec.Abierta) { ApplicationArea = All; }
                field("Comentario Alta"; Rec."Comentario Alta") { ApplicationArea = All; Visible = false; }
                field("Comentario Baja"; Rec."Comentario Baja") { ApplicationArea = All; Visible = false; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(VerHistorial)
            {
                ApplicationArea = All;
                Caption = 'Historial de Estados';
                Image = History;
                ToolTip = 'Abre el historial operativo del empleado: qué estaba haciendo cada día y en qué proyecto. Las altas y las bajas ya no están ahí — se cargan en esta pantalla.';

                trigger OnAction()
                var
                    Estado: Record "Estado Empleado";
                begin
                    if FEmpleado = '' then
                        exit;
                    Estado.SetRange("Tipo Entidad", Estado."Tipo Entidad"::Empleado);
                    Estado.SetRange("No. Empleado", FEmpleado);
                    Page.Run(Page::"Estados Empleado", Estado);
                end;
            }
            action(Recargar)
            {
                ApplicationArea = All;
                Caption = 'Actualizar';
                Image = Refresh;
                ToolTip = 'Vuelve a calcular el total de antigüedad.';

                trigger OnAction()
                begin
                    AplicarFiltro();
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                actionref(VerHistorial_Promoted; VerHistorial) { }
            }
        }
    }

    trigger OnOpenPage()
    begin
        if FFechaRef = 0D then
            FFechaRef := WorkDate();
        AplicarFiltro();
    end;

    trigger OnAfterGetRecord()
    begin
        EstiloAbierta := 'Standard';
        if Rec.Abierta then
            EstiloAbierta := 'Favorable';
    end;

    trigger OnNewRecord(BelowxRec: Boolean)
    begin
        // La fila nueva nace con el legajo del filtro ya puesto: cargar una fase para otra persona
        // desde una grilla filtrada por ésta sería un error difícil de ver.
        if FEmpleado <> '' then
            Rec."No. Empleado" := FEmpleado;
    end;

    /// <summary>Abre la página ya apuntada a un empleado.</summary>
    procedure SetEmpleado(EmployeeNo: Code[20])
    begin
        FEmpleado := EmployeeNo;
    end;

    local procedure AplicarFiltro()
    var
        EstadoMgt: Codeunit "Gestión Estado Empleado";
        Emp: Record Employee;
    begin
        if FFechaRef = 0D then
            FFechaRef := WorkDate();

        Rec.Reset();
        if FEmpleado <> '' then
            Rec.SetRange("No. Empleado", FEmpleado);
        CurrPage.Update(false);

        TotalTexto := '';
        if FEmpleado = '' then
            exit;

        // El total sale del MISMO cálculo que usan las fórmulas, no de sumar la columna Días: así, si
        // alguna vez difieren, la diferencia se ve acá en lugar de aparecer en un recibo.
        TotalTexto := CopyStr(StrSubstNo(TxtTotal, EstadoMgt.CalcAntiguedadAlFecha(FEmpleado, FFechaRef)), 1, MaxStrLen(TotalTexto));
        if Emp.Get(FEmpleado) then
            if Emp."Antigüedad Reconocida" > 0 then
                TotalTexto := CopyStr(TotalTexto + StrSubstNo(TxtReconocida, Emp."Antigüedad Reconocida"), 1, MaxStrLen(TotalTexto));
    end;

    var
        FEmpleado: Code[20];
        FFechaRef: Date;
        TotalTexto: Text[100];
        EstiloAbierta: Text[20];
        TxtTotal: Label '%1 año(s)', Comment = '%1 = años';
        TxtReconocida: Label ' (incluye %1 reconocido/s)', Comment = '%1 = años reconocidos';
}
