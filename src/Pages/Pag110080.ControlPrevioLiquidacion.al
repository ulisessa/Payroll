namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;
using Microsoft.Projects.Project.Job;

page 110080 "Control Previo Liquidación"
{
    ApplicationArea = All;
    Caption = 'Preparación de liquidaciones';
    PageType = List;
    UsageCategory = Tasks;
    SourceTable = "Control Previo Liq. Buffer";
    SourceTableTemporary = true;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;
    // Sólo la grilla es de lectura: los filtros son variables editables.

    layout
    {
        area(Content)
        {
            group(Filtros)
            {
                Caption = 'Revisar antes de crear o calcular';
                field(CodPeriodo; CodPeriodo)
                {
                    ApplicationArea = All;
                    Caption = 'Período';
                    TableRelation = "Período Liquidación".Código;
                    ToolTip = 'Elegí el período y pulsá Verificar. Abrir esta pantalla no ejecuta la revisión.';
                    trigger OnValidate()
                    begin
                        InvalidarRevision();
                    end;
                }
                field(TipoLiq; TipoLiq)
                {
                    ApplicationArea = All;
                    Caption = 'Tipo de liquidación';
                    TableRelation = "Tipo Liquidación".Código;
                    ToolTip = 'Vacío revisa el alcance de la corrida completa del período.';
                    trigger OnValidate()
                    begin
                        InvalidarRevision();
                    end;
                }
                field(FiltroEmpleado; FiltroEmpleado)
                {
                    ApplicationArea = All;
                    Caption = 'Empleado';
                    ToolTip = 'Opcional. Admite un empleado o una expresión de filtro de Business Central.';
                    trigger OnValidate()
                    begin
                        InvalidarRevision();
                    end;

                    trigger OnLookup(var Text: Text): Boolean
                    var
                        Empleado: Record Employee;
                        Lista: Page "Employee List";
                    begin
                        Lista.LookupMode(true);
                        if Lista.RunModal() <> Action::LookupOK then
                            exit(false);
                        Lista.GetRecord(Empleado);
                        Text := Empleado."No.";
                        exit(true);
                    end;
                }
                field(FiltroProyecto; FiltroProyecto)
                {
                    ApplicationArea = All;
                    Caption = 'Proyecto';
                    ToolTip = 'Opcional. Admite un proyecto o una expresión de filtro de Business Central.';
                    trigger OnValidate()
                    begin
                        InvalidarRevision();
                    end;

                    trigger OnLookup(var Text: Text): Boolean
                    var
                        Proyecto: Record Job;
                        Lista: Page "Job List";
                    begin
                        Lista.LookupMode(true);
                        if Lista.RunModal() <> Action::LookupOK then
                            exit(false);
                        Lista.GetRecord(Proyecto);
                        Text := Proyecto."No.";
                        exit(true);
                    end;
                }
                field(SimularCalculo; SimularCalculo)
                {
                    ApplicationArea = All;
                    Caption = 'Simular cálculo';
                    ToolTip = 'Además de revisar los datos, calcula cada liquidación del alcance en una prueba que se deshace al terminar, e informa los precios que una fórmula usó sin valor y los errores del cálculo. Tarda lo que una corrida completa del alcance.';
                    trigger OnValidate()
                    begin
                        InvalidarRevision();
                    end;
                }
                field(VistaAvisos; VistaAvisos)
                {
                    ApplicationArea = All;
                    Caption = 'Mostrar';
                    ToolTip = 'Errores comprobados muestra sólo fallos acreditados con el contexto disponible. Las revisiones y el diagnóstico completo conservan lo pendiente de confirmar. Cambiar esta vista no vuelve a consultar ni calcular.';
                    trigger OnValidate()
                    begin
                        AplicarVista();
                    end;
                }
            }
            group(Resultado)
            {
                Caption = 'Resultado de la revisión';
                Editable = false;
                field(EstadoRevision; EstadoRevision)
                {
                    ApplicationArea = All;
                    Caption = 'Estado';
                    MultiLine = true;
                    ToolTip = 'La revisión es una captura de la configuración. Después de corregir datos, pulsá Verificar para actualizarla.';
                }
                field(FechaRevision; FechaRevision) { ApplicationArea = All; Caption = 'Revisado el'; }
                field(CantGrupos; CantGrupos)
                {
                    ApplicationArea = All;
                    Caption = 'Grupos visibles';
                    ToolTip = 'Cuenta sólo la vista y los filtros actuales de la lista. Cada grupo conserva empleado, proyecto, tipo, fechas, dato y motivo; no equivale a faltantes distintos.';
                }
                field(CantOcurrencias; CantOcurrencias)
                {
                    ApplicationArea = All;
                    Caption = 'Ocurrencias visibles';
                    ToolTip = 'Suma de repeticiones de los grupos visibles. Una repetición no representa otra persona ni otro faltante.';
                }
                field(CantErrores; CantErrores) { ApplicationArea = All; Caption = 'Errores comprobados visibles'; StyleExpr = EstiloContadorErrores; }
                field(CantAdvertencias; CantAdvertencias) { ApplicationArea = All; Caption = 'Revisiones visibles'; StyleExpr = EstiloContadorRevisiones; }
                field(CantInformacion; CantInformacion) { ApplicationArea = All; Caption = 'Información visible'; }
            }
            repeater(Filas)
            {
                Editable = false;
                field(Severidad; Rec.Severidad) { ApplicationArea = All; StyleExpr = EstiloFila; }
                field(Área; Rec.Área) { ApplicationArea = All; }
                field(Mensaje; Rec.Mensaje) { ApplicationArea = All; }
                field(Repeticiones; Rec.Repeticiones)
                {
                    ApplicationArea = All;
                    ToolTip = 'Cantidad de ocurrencias de este aviso en el mismo contexto; los conceptos que lo originan se muestran en Conceptos relacionados.';
                }
                field("Nombre Variable"; Rec."Nombre Variable") { ApplicationArea = All; }
                field("No. Empleado"; Rec."No. Empleado") { ApplicationArea = All; }
                field("No. Proyecto"; Rec."No. Proyecto") { ApplicationArea = All; }
                field("Cód. Tipo Liq."; Rec."Cód. Tipo Liq.") { ApplicationArea = All; }
                field("Cód. Convenio"; Rec."Cód. Convenio") { ApplicationArea = All; }
                field("Cód. Categoría"; Rec."Cód. Categoría") { ApplicationArea = All; }
                field("Fecha Desde"; Rec."Fecha Desde") { ApplicationArea = All; }
                field("Fecha Hasta"; Rec."Fecha Hasta") { ApplicationArea = All; }
                field("Vigencia Desde"; Rec."Vigencia Desde") { ApplicationArea = All; }
                field("Cód. Concepto"; Rec."Cód. Concepto")
                {
                    ApplicationArea = All;
                    ToolTip = 'Concepto representativo para abrir la configuración. La lista completa está en Conceptos relacionados.';
                }
                field("Conceptos relacionados"; Rec."Conceptos relacionados")
                {
                    ApplicationArea = All;
                    ToolTip = 'Conceptos que originaron el aviso agrupado. No se agrupan personas ni proyectos diferentes.';
                }
                field("Cód. Parámetro"; Rec."Cód. Parámetro") { ApplicationArea = All; Visible = false; }
                field("Clave Parámetro"; Rec."Clave Parámetro") { ApplicationArea = All; Visible = false; }
                field("Cód. Tipo Atributo"; Rec."Cód. Tipo Atributo") { ApplicationArea = All; Visible = false; }
                field("Nombre Fuente"; Rec."Nombre Fuente") { ApplicationArea = All; Visible = false; }
                field(Detalle; Rec.Detalle) { ApplicationArea = All; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Verificar)
            {
                ApplicationArea = All;
                Caption = 'Verificar';
                Image = Check;
                ToolTip = 'Revisa la configuración del alcance elegido sin crear ni calcular liquidaciones.';
                trigger OnAction()
                begin
                    Revisar();
                end;
            }
            action(AbrirDato)
            {
                ApplicationArea = All;
                Caption = 'Abrir dato';
                Image = EditLines;
                Enabled = Revisado;
                ToolTip = 'Abre la configuración relacionada con la fila. No carga valores automáticamente.';
                trigger OnAction()
                begin
                    AbrirDatoDeFila();
                end;
            }
            action(Imprimir)
            {
                ApplicationArea = All;
                Caption = 'Imprimir revisión';
                Image = Print;
                Enabled = Revisado;
                ToolTip = 'Imprime la revisión mostrada, con su fecha y alcance, sin volver a consultar la nómina.';
                trigger OnAction()
                var
                    Informe: Report "Preparación de Liquidaciones";
                begin
                    Informe.SetVista(VistaAvisos);
                    Informe.SetBuffer(Rec, CodPeriodo, TipoLiq, FiltroEmpleado, FiltroProyecto, FechaRevision);
                    Informe.UseRequestPage(false);
                    Informe.RunModal();
                end;
            }
        }
        area(Navigation)
        {
            action(AbrirEmpleado)
            {
                ApplicationArea = All;
                Caption = 'Empleado';
                Image = Employee;
                trigger OnAction()
                begin
                    VerEmpleado();
                end;
            }
            action(AbrirProyecto)
            {
                ApplicationArea = All;
                Caption = 'Proyecto';
                Image = Job;
                trigger OnAction()
                begin
                    VerProyecto();
                end;
            }
        }
        area(Promoted)
        {
            group(Revision)
            {
                Caption = 'Revisión';
                actionref(VerificarProm; Verificar) { }
                actionref(AbrirDatoProm; AbrirDato) { }
                actionref(ImprimirProm; Imprimir) { }
            }
        }
    }

    trigger OnOpenPage()
    begin
        if not Revisado then
            EstadoRevision := MsgPendiente;
    end;

    trigger OnAfterGetRecord()
    begin
        case Rec.Severidad of
            Rec.Severidad::Error: EstiloFila := 'Unfavorable';
            Rec.Severidad::Advertencia: EstiloFila := 'Attention';
            else EstiloFila := 'Standard';
        end;
    end;

    trigger OnAfterGetCurrRecord()
    begin
        if Revisado then
            if ActualizarContadoresVisibles(false) then
                CurrPage.Update(false);
    end;

    procedure SetPeriodo(Periodo: Code[10])
    begin
        if CodPeriodo <> Periodo then
            InvalidarRevision();
        CodPeriodo := Periodo;
    end;

    procedure SetTipo(Tipo: Code[20])
    begin
        if TipoLiq <> Tipo then
            InvalidarRevision();
        TipoLiq := Tipo;
    end;

    procedure SetVista(Vista: Integer)
    begin
        case Vista of
            0: VistaAvisos := VistaAvisos::"Errores comprobados";
            1: VistaAvisos := VistaAvisos::"Errores y revisiones";
            2: VistaAvisos := VistaAvisos::"Diagnóstico completo";
            else
                Error(ErrVista);
        end;
        AplicarVista();
    end;

    local procedure InvalidarRevision()
    begin
        Rec.Reset();
        Rec.DeleteAll();
        Revisado := false;
        Clear(FechaRevision);
        Clear(CantErrores);
        Clear(CantAdvertencias);
        Clear(CantInformacion);
        Clear(CantGrupos);
        Clear(CantOcurrencias);
        Clear(VistaContada);
        EstiloContadorErrores := 'Standard';
        EstiloContadorRevisiones := 'Standard';
        EstadoRevision := MsgPendiente;
    end;

    local procedure Revisar()
    var
        Control: Codeunit "Control Previo Liq.";
    begin
        if CodPeriodo = '' then
            Error(ErrSinPeriodo);
        InvalidarRevision();
        Control.SetSimularCalculo(SimularCalculo);
        Control.Analizar(CodPeriodo, TipoLiq, FiltroEmpleado, FiltroProyecto, Rec);
        FechaRevision := CurrentDateTime();
        Revisado := true;
        AplicarVista();
    end;

    local procedure AplicarVista()
    var
        Control: Codeunit "Control Previo Liq.";
    begin
        if not Revisado then
            exit;
        // El filtro conserva la captura completa; ampliar la vista no vuelve a analizarla.
        Control.FiltrarVista(Rec, VistaAvisos);
        ActualizarContadoresVisibles(true);
        CurrPage.Update(false);
    end;

    local procedure ActualizarContadoresVisibles(Forzar: Boolean): Boolean
    var
        Filas: Record "Control Previo Liq. Buffer" temporary;
        VistaActual: Text;
    begin
        VistaActual := Format(VistaAvisos) + '|' + Rec.GetView(false);
        if not Forzar and (VistaActual = VistaContada) then
            exit(false);
        VistaContada := VistaActual;
        Clear(CantErrores);
        Clear(CantAdvertencias);
        Clear(CantInformacion);
        Clear(CantGrupos);
        Clear(CantOcurrencias);
        Filas.Copy(Rec, true);
        // Copy conserva también los filtros del usuario y de la vista del grupo 2.
        if Filas.FindSet() then
            repeat
                CantGrupos += 1;
                CantOcurrencias += Filas.Repeticiones;
                case Filas.Severidad of
                    Filas.Severidad::Error: CantErrores += 1;
                    Filas.Severidad::Advertencia: CantAdvertencias += 1;
                    else CantInformacion += 1;
                end;
            until Filas.Next() = 0;
        EstiloContadorErrores := 'Standard';
        EstiloContadorRevisiones := 'Standard';
        if CantErrores > 0 then
            EstiloContadorErrores := 'Unfavorable';
        if CantAdvertencias > 0 then
            EstiloContadorRevisiones := 'Attention';
        if (CantGrupos = 0) and (VistaAvisos = VistaAvisos::"Errores comprobados") then
            EstadoRevision := MsgSinErrores
        else
            EstadoRevision := StrSubstNo(MsgRevisado, Format(VistaAvisos), CantGrupos, CantOcurrencias);
        exit(true);
    end;

    local procedure AbrirDatoDeFila()
    var
        ParamVig: Record "Parámetro Vigente";
        ValorOrigen: Record "Parámetro Vigente";
        Asignacion: Record "Atributo Entidad Liq.";
        Fuente: Record "Fuente Datos Liquidación";
        Concepto: Record "Concepto Liquidación";
        Claves: Codeunit "Claves Parámetro Liq.";
        Parametros: Page "Parámetros Vigentes";
        Atributos: Page "Atributos de Entidad";
        Entidad: Code[20];
        TieneValorOrigen: Boolean;
    begin
        if Rec."No. Línea" = 0 then
            exit;
        if Rec."Nombre Fuente" <> '' then
            if Fuente.Get(Rec."Nombre Fuente") then begin
                Page.Run(Page::"Fuente Datos Card", Fuente);
                exit;
            end;
        if Rec."Cód. Tipo Atributo" <> '' then begin
            Entidad := Rec."Cód. Entidad";
            if (Entidad = '') and (Rec."Tipo Entidad" = Rec."Tipo Entidad"::Empleado) then
                Entidad := Rec."No. Empleado";
            if (Entidad = '') and (Rec."Tipo Entidad" = Rec."Tipo Entidad"::Proyecto) then
                Entidad := Rec."No. Proyecto";
            if Entidad <> '' then begin
                Atributos.SetEntidad(Rec."Tipo Entidad", Entidad);
                Atributos.MostrarHistorial();
                Asignacion.SetRange("Cód. Tipo Atributo", Rec."Cód. Tipo Atributo");
                Atributos.SetTableView(Asignacion);
                Atributos.Run();
                exit;
            end;
        end;
        if Rec."Cód. Parámetro" <> '' then begin
            if (Rec."Clave Parámetro" <> '') and (Rec."Vigencia Desde" <> 0D) then
                if ParamVig.Get(Rec."Cód. Parámetro", Rec."Clave Parámetro", Rec."Vigencia Desde") then begin
                    Page.Run(Page::"Ficha Valor Parámetro", ParamVig);
                    exit;
                end;
            ParamVig.SetRange("Cód. Parámetro Base", Rec."Cód. Parámetro");
            if Rec."Clave Parámetro" <> '' then begin
                ParamVig.SetRange("Cód. Parámetro", Rec."Clave Parámetro");
                ValorOrigen.CopyFilters(ParamVig);
                TieneValorOrigen := ValorOrigen.FindLast();
            end;
            // El empleado observado no implica que el precio faltante sea personal. La clave
            // efectiva o una fila del mismo alcance deciden el origen, sin inventar excepciones.
            if TieneValorOrigen then
                Parametros.SetOrigen(ValorOrigen."No. Empleado", ValorOrigen."Cód. Convenio", ValorOrigen."Cód. Categoría")
            else if (Rec."No. Empleado" <> '') and
                    (Rec."Clave Parámetro" = Claves.Armar(Rec."Cód. Parámetro", Rec."No. Empleado", '')) then
                Parametros.SetOrigen(Rec."No. Empleado", '', '')
            else if (Rec."Cód. Convenio" <> '') and
                    (Rec."Clave Parámetro" = Claves.Armar(Rec."Cód. Parámetro", Rec."Cód. Convenio", Rec."Cód. Categoría")) then
                Parametros.SetOrigen('', Rec."Cód. Convenio", Rec."Cód. Categoría")
            else if (Rec."Cód. Convenio" <> '') and
                    (Rec."Clave Parámetro" = Claves.Armar(Rec."Cód. Parámetro", Rec."Cód. Convenio", '')) then
                Parametros.SetOrigen('', Rec."Cód. Convenio", '')
            else
                Parametros.SetOrigen('', '', '');
            Parametros.SetTableView(ParamVig);
            Parametros.Run();
            exit;
        end;
        if Rec."Cód. Concepto" <> '' then begin
            Concepto.SetRange(Código, Rec."Cód. Concepto");
            if Rec."Fecha Hasta" <> 0D then
                Concepto.SetFilter("Vigencia Desde", '<=%1', Rec."Fecha Hasta");
            if Concepto.FindLast() then begin
                Page.Run(Page::"Concepto Liq. Card", Concepto);
                exit;
            end;
        end;
        if Rec."No. Empleado" <> '' then begin
            VerEmpleado();
            exit;
        end;
        if Rec."No. Proyecto" <> '' then begin
            VerProyecto();
            exit;
        end;
        Message(MsgSinFicha);
    end;

    local procedure VerEmpleado()
    var
        Emp: Record Employee;
    begin
        if Rec."No. Empleado" <> '' then
            if Emp.Get(Rec."No. Empleado") then
                Page.Run(Page::"Employee Card", Emp);
    end;

    local procedure VerProyecto()
    var
        Proyecto: Record Job;
    begin
        if Rec."No. Proyecto" <> '' then
            if Proyecto.Get(Rec."No. Proyecto") then
                Page.Run(Page::"Job Card", Proyecto);
    end;

    var
        CodPeriodo: Code[10];
        TipoLiq: Code[20];
        FiltroEmpleado: Text;
        FiltroProyecto: Text;
        SimularCalculo: Boolean;
        VistaAvisos: Option "Errores comprobados","Errores y revisiones","Diagnóstico completo";
        Revisado: Boolean;
        FechaRevision: DateTime;
        CantErrores: Integer;
        CantAdvertencias: Integer;
        CantInformacion: Integer;
        CantGrupos: Integer;
        CantOcurrencias: Integer;
        EstadoRevision: Text;
        EstiloFila: Text;
        EstiloContadorErrores: Text;
        EstiloContadorRevisiones: Text;
        VistaContada: Text;
        ErrSinPeriodo: Label 'Elegí un período antes de verificar.';
        ErrVista: Label 'La vista de avisos no es válida.';
        MsgPendiente: Label 'Pendiente de revisión. Pulsá Verificar para revisar el alcance elegido.';
        MsgRevisado: Label 'Vista: %1. %2 grupos visibles, %3 ocurrencias. Los conteos respetan los filtros de la lista y no equivalen a faltantes distintos. No se crearon ni calcularon liquidaciones. Después de corregir datos, volvé a verificar.', Comment = '%1=vista, %2=grupos visibles, %3=ocurrencias visibles';
        MsgSinErrores: Label 'No se detectaron errores comprobados con el contexto disponible. Consultá Errores y revisiones para ver lo pendiente de confirmar. Los filtros de la lista siguen aplicados; este resultado no certifica los importes de las liquidaciones.';
        MsgSinFicha: Label 'La fila no identifica una configuración que pueda abrirse directamente. Consultá su detalle.';
}
