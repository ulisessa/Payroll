namespace UAS.Payroll;

// Las fases de alta de UN empleado, para incrustar en su ficha.
//
// Misma grilla que "Fases de Alta" sin la cabecera de filtro —el legajo lo pone el vínculo— y sin
// el total de antigüedad, que depende de una fecha de referencia que acá no hay dónde elegir. Para
// eso está la acción que abre la pantalla completa.
//
// POR QUÉ ESTÁ EN LA FICHA Y NO SÓLO EN SU PÁGINA: de estas fechas sale la antigüedad, y la
// antigüedad entra en el recibo. Tenerlas a la vista al lado del historial de estados es lo que
// permite notar de un vistazo los dos errores que ya aparecieron en la migración — una fase abierta
// de alguien que se fue, y un estado operativo que cae fuera de toda fase.
//
// Lo que decide sigue viviendo en la tabla: la contigüidad, que no se superpongan y el orden de las
// fechas los valida "Fase Alta Empleado". Acá sólo hay disposición.
page 110044 "Fases Alta Empleado Sub"
{
    ApplicationArea = All;
    Caption = 'Fases de Alta';
    PageType = ListPart;
    SourceTable = "Fase Alta Empleado";
    // Lo más nuevo arriba, igual que el resto de las subpáginas de la ficha. Un tripulante de
    // temporada acumula una fase por contrato y la vigente es la que se mira.
    SourceTableView = sorting("No. Empleado", "No. Fase") order(descending);
    DelayedInsert = true;

    layout
    {
        area(Content)
        {
            repeater(Fases)
            {
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
                    ToolTip = 'Días calendario de la fase cerrada. La fase abierta va en cero: sus días dependen de contra qué fecha se midan, y eso lo resuelve la pantalla completa.';
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
            action(VerCompleta)
            {
                ApplicationArea = All;
                Caption = 'Antigüedad';
                Image = History;
                ToolTip = 'Abre la pantalla completa de fases, que además calcula la antigüedad acumulada contra la fecha que elijas.';

                trigger OnAction()
                var
                    Fases: Page "Fases de Alta";
                begin
                    if Rec."No. Empleado" = '' then
                        exit;
                    // RunModal y no Run: "Fases de Alta" arma su filtro en OnOpenPage a partir de lo
                    // que le pasa SetEmpleado, y con Run la página se abre sin que ese estado haya
                    // llegado. Es el mismo error que dejó el botón "Fases alta" sin hacer nada.
                    Fases.SetEmpleado(Rec."No. Empleado");
                    Fases.RunModal();
                end;
            }
        }
    }
}
