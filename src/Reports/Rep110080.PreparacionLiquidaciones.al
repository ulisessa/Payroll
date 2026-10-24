namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;
using Microsoft.Projects.Project.Job;

report 110080 "Preparación de Liquidaciones"
{
    ApplicationArea = All;
    Caption = 'Preparación de liquidaciones';
    UsageCategory = ReportsAndAnalysis;
    DefaultRenderingLayout = RDLCLayout;

    dataset
    {
        dataitem(Filas; "Control Previo Liq. Buffer")
        {
            UseTemporary = true;
            DataItemTableView = sorting("No. Línea");
            column(Titulo; TituloLbl) { }
            column(Alcance; Alcance) { }
            column(Resumen; Resumen) { }
            column(FechaRevision; FechaRevision) { }
            column(NoLinea; Filas."No. Línea") { }
            column(Severidad; Format(Filas.Severidad)) { }
            column("Area"; Filas.Área) { }
            column(Variable; Filas."Nombre Variable") { }
            column(Parametro; Filas."Cód. Parámetro") { }
            column(Concepto; Filas."Cód. Concepto") { }
            column(Repeticiones; Filas.Repeticiones) { }
            column(ConceptosRelacionados; Filas."Conceptos relacionados") { }
            column(Empleado; Filas."No. Empleado") { }
            column(Proyecto; Filas."No. Proyecto") { }
            column(Convenio; Filas."Cód. Convenio") { }
            column(Categoria; Filas."Cód. Categoría") { }
            column(TipoLiquidacion; Filas."Cód. Tipo Liq.") { }
            column(FechaDesde; Filas."Fecha Desde") { }
            column(FechaHasta; Filas."Fecha Hasta") { }
            column(VigenciaDesde; Filas."Vigencia Desde") { }
            column(Mensaje; Filas.Mensaje) { }
            column(Detalle; Filas.Detalle) { }
            column(ContextoFila; ContextoDeFila()) { }
        }
    }

    requestpage
    {
        layout
        {
            area(Content)
            {
                group(Filtros)
                {
                    Caption = 'Alcance de la revisión';
                    Editable = not UsarBuffer;
                    field(CodPeriodo; CodPeriodo)
                    {
                        ApplicationArea = All;
                        Caption = 'Período';
                        TableRelation = "Período Liquidación".Código;
                    }
                    field(TipoLiq; TipoLiq)
                    {
                        ApplicationArea = All;
                        Caption = 'Tipo de liquidación';
                        TableRelation = "Tipo Liquidación".Código;
                    }
                    field(FiltroEmpleado; FiltroEmpleado)
                    {
                        ApplicationArea = All;
                        Caption = 'Empleado';
                        ToolTip = 'Opcional. Admite un empleado o una expresión de filtro de Business Central.';
                    }
                    field(FiltroProyecto; FiltroProyecto)
                    {
                        ApplicationArea = All;
                        Caption = 'Proyecto';
                        ToolTip = 'Opcional. Admite un proyecto o una expresión de filtro de Business Central.';
                    }
                    field(VistaAvisos; VistaAvisos)
                    {
                        ApplicationArea = All;
                        Caption = 'Mostrar';
                        ToolTip = 'Errores comprobados muestra sólo fallos acreditados con el contexto disponible. Las demás vistas conservan las revisiones y el diagnóstico no comprobado.';
                    }
                }
            }
        }
    }

    rendering
    {
        layout(RDLCLayout)
        {
            Type = RDLC;
            LayoutFile = './src/Reports/Rep110080.PreparacionLiquidaciones.rdl';
            Caption = 'Preparación de liquidaciones';
        }
    }

    trigger OnPreReport()
    var
        Control: Codeunit "Control Previo Liq.";
        Copia: Record "Control Previo Liq. Buffer" temporary;
        Errores: Integer;
        Advertencias: Integer;
        Informacion: Integer;
        Grupos: Integer;
        Ocurrencias: Integer;
    begin
        if CodPeriodo = '' then
            Error(ErrSinPeriodo);
        if not UsarBuffer then begin
            Clear(FiltrosLista);
            Control.Analizar(CodPeriodo, TipoLiq, FiltroEmpleado, FiltroProyecto, Filas);
            FechaRevision := CurrentDateTime();
        end;
        Control.FiltrarVista(Filas, VistaAvisos);
        Copia.Copy(Filas, true);
        if Copia.FindSet() then
            repeat
                Grupos += 1;
                Ocurrencias += Copia.Repeticiones;
                case Copia.Severidad of
                    Copia.Severidad::Error: Errores += 1;
                    Copia.Severidad::Advertencia: Advertencias += 1;
                    else Informacion += 1;
                end;
            until Copia.Next() = 0;
        Alcance := StrSubstNo(AlcanceLbl, CodPeriodo, FiltroVisible(TipoLiq), FiltroVisible(FiltroEmpleado), FiltroVisible(FiltroProyecto), Format(VistaAvisos), FiltroVisible(FiltrosLista));
        Resumen := StrSubstNo(ResumenLbl, Grupos, Ocurrencias, Errores, Advertencias, Informacion);
        // Una fila exclusivamente de presentación permite imprimir también un resultado vacío.
        // SetBuffer copia las filas: esta inserción nunca modifica la captura de la página.
        if Filas.IsEmpty() then begin
            // Sólo se limpia la copia privada del informe. El filtro de severidad no debe
            // ocultar esta fila de resumen ni revelar las revisiones que quedaron fuera.
            Filas.Reset();
            Filas.DeleteAll();
            Filas.Init();
            Filas."No. Línea" := 1;
            Filas.Severidad := Filas.Severidad::Información;
            Filas.Área := 'Resumen';
            if VistaAvisos = VistaAvisos::"Errores comprobados" then begin
                Filas.Mensaje := MsgSinErrores;
                Filas.Detalle := MsgRevisiones;
                Resumen := MsgSinErrores + ' ' + MsgRevisiones;
            end else begin
                Filas.Mensaje := MsgSinObservaciones;
                Filas.Detalle := MsgRevisiones;
            end;
            Filas.Insert();
        end;
    end;

    procedure SetPeriodo(Periodo: Code[10])
    begin
        if CodPeriodo <> Periodo then
            UsarBuffer := false;
        CodPeriodo := Periodo;
    end;

    procedure SetTipo(Tipo: Code[20])
    begin
        if TipoLiq <> Tipo then
            UsarBuffer := false;
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
    end;

    procedure SetBuffer(var Origen: Record "Control Previo Liq. Buffer" temporary; Periodo: Code[10]; Tipo: Code[20]; Empleado: Text; Proyecto: Text; RevisadoEl: DateTime)
    var
        Copia: Record "Control Previo Liq. Buffer" temporary;
    begin
        Filas.Reset();
        Filas.DeleteAll();
        Copia.Copy(Origen, true);
        // Copiar exclusivamente las filas visibles, incluidos los filtros del usuario y
        // la vista del grupo 2. El informe no comparte ni vuelve a analizar la captura.
        if Copia.FindSet() then
            repeat
                Filas := Copia;
                Filas.Insert();
            until Copia.Next() = 0;
        CodPeriodo := Periodo;
        TipoLiq := Tipo;
        FiltroEmpleado := Empleado;
        FiltroProyecto := Proyecto;
        FiltrosLista := Origen.GetFilters();
        FechaRevision := RevisadoEl;
        UsarBuffer := true;
    end;

    local procedure FiltroVisible(Filtro: Text): Text
    begin
        if Filtro = '' then
            exit(TodosLbl);
        exit(Filtro);
    end;

    local procedure ContextoDeFila(): Text
    var
        Contexto: Text;
    begin
        if Filas."No. Empleado" <> '' then
            Contexto := StrSubstNo('Empleado %1', Filas."No. Empleado");
        if Filas."No. Proyecto" <> '' then
            AgregarContexto(Contexto, StrSubstNo('Proyecto %1', Filas."No. Proyecto"));
        if Filas."Cód. Tipo Liq." <> '' then
            AgregarContexto(Contexto, Filas."Cód. Tipo Liq.");
        if Filas."Cód. Convenio" <> '' then
            AgregarContexto(Contexto, Filas."Cód. Convenio" + '/' + Filas."Cód. Categoría");
        if Filas."Fecha Desde" <> 0D then
            AgregarContexto(Contexto, Format(Filas."Fecha Desde") + ' – ' + Format(Filas."Fecha Hasta"));
        if Filas."Vigencia Desde" <> 0D then
            AgregarContexto(Contexto, StrSubstNo('Vigencia %1', Filas."Vigencia Desde"));
        exit(Contexto);
    end;

    local procedure AgregarContexto(var Contexto: Text; Valor: Text)
    begin
        if Contexto <> '' then
            Contexto += ' | ';
        Contexto += Valor;
    end;

    var
        CodPeriodo: Code[10];
        TipoLiq: Code[20];
        FiltroEmpleado: Text;
        FiltroProyecto: Text;
        VistaAvisos: Option "Errores comprobados","Errores y revisiones","Diagnóstico completo";
        FiltrosLista: Text;
        FechaRevision: DateTime;
        UsarBuffer: Boolean;
        Alcance: Text;
        Resumen: Text;
        TituloLbl: Label 'Preparación de liquidaciones';
        TodosLbl: Label 'Todos';
        AlcanceLbl: Label 'Período: %1 | Tipo: %2 | Empleado: %3 | Proyecto: %4 | Vista: %5 | Filtros de la lista: %6', Comment = '%1=período, %2=tipo, %3=filtro empleado, %4=filtro proyecto, %5=vista de avisos, %6=filtros de lista';
        ResumenLbl: Label '%1 grupos visibles | %2 ocurrencias. Grupos: %3 con error comprobado, %4 revisiones, %5 de información. Los conteos no equivalen a faltantes distintos. No crea ni calcula liquidaciones.', Comment = '%1=grupos visibles, %2=ocurrencias visibles, %3=grupos con error, %4=grupos con advertencia, %5=grupos de información';
        ErrSinPeriodo: Label 'Elegí un período antes de imprimir la revisión.';
        ErrVista: Label 'La vista de avisos no es válida.';
        MsgSinObservaciones: Label 'La revisión no devolvió avisos para la vista y los filtros seleccionados.';
        MsgSinErrores: Label 'No se detectaron errores comprobados con el contexto disponible.';
        MsgRevisiones: Label 'Consultá Errores y revisiones para ver lo pendiente de confirmar. Este resultado no certifica los importes de las liquidaciones.';
}
