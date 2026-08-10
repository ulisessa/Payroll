namespace UAS.Payroll;

using Microsoft.Projects.Project.Job;

table 60000 "Estado Empleado"
{
    Caption = 'Estado Empleado';
    DataClassification = CustomerContent;
    LookupPageId = "Estados Empleado";
    DrillDownPageId = "Estados Empleado";

    fields
    {
        field(7; "No. Mov."; Integer)
        {
            Caption = 'No. Mov.';
            AutoIncrement = true;
            DataClassification = CustomerContent;
        }
        field(1; "No. Empleado"; Code[20])
        {
            Caption = 'Cód. Entidad';
            NotBlank = true;
            DataClassification = CustomerContent;
            // Employee no. when "Tipo Entidad" = Empleado; vessel code when = Buque.
            // No TableRelation here because it points to two different tables depending on "Tipo Entidad".
        }
        field(2; "Fecha Inicio"; Date)
        {
            Caption = 'Fecha Inicio';
            NotBlank = true;
            DataClassification = CustomerContent;

            trigger OnValidate()
            begin
                AutoCalcFechaFinVacaciones();
            end;
        }
        field(3; "Cód. Estado"; Code[20])
        {
            Caption = 'Cód. Estado';
            NotBlank = true;
            DataClassification = CustomerContent;
            TableRelation = "Cód. Estado Empleado".Código;

            trigger OnValidate()
            begin
                AutoCalcFechaFinVacaciones();
            end;
        }
        field(4; "Fecha Fin"; Date)
        {
            Caption = 'Fecha Fin';
            DataClassification = CustomerContent;
            // Fin del estado, inclusive. En blanco = abierto (sigue vigente).
            //
            // El historial es contiguo por construcción: mientras exista un estado posterior de la
            // misma entidad, este campo se mantiene solo en "Fecha Inicio del siguiente − 1", así
            // nunca queda un día sin estado. Editarlo a mano con un estado posterior cargado corre
            // el inicio de ese siguiente (ver EmpujarSiguienteEstado), que es la forma de acortar o
            // alargar un estado sin abrir un hueco.

            trigger OnValidate()
            begin
                ValidarOrdenFechas();
            end;
        }
        field(5; "Descripción Estado"; Text[100])
        {
            Caption = 'Descripción Estado';
            FieldClass = FlowField;
            CalcFormula = Lookup("Cód. Estado Empleado".Descripción WHERE(Código = FIELD("Cód. Estado")));
            Editable = false;
        }
        field(6; Observaciones; Text[250])
        {
            Caption = 'Observaciones';
            DataClassification = CustomerContent;
        }
        field(8; "No. Proyecto"; Code[20])
        {
            Caption = 'No. Proyecto';
            DataClassification = CustomerContent;
            TableRelation = Job."No.";
            Editable = false;
            // Non-blank when this state was auto-generated from a Personal Proyecto assignment;
            // blank for manually entered states. Part of K1 so there is one state per assignment.
        }
        field(9; "Tipo Entidad"; Enum "Tipo Entidad Estado")
        {
            Caption = 'Tipo Entidad';
            DataClassification = CustomerContent;
            // Empleado (default) → "Cód. Entidad" holds the employee no.; Buque → the vessel code.
            // Lets one history serve both employees and vessels.
        }
    }

    keys
    {
        key(PK; "No. Mov.")
        {
            Clustered = true;
        }
        key(K1; "Tipo Entidad", "No. Empleado", "No. Proyecto", "Fecha Inicio")
        {
            Unique = true;
        }
        key(K2; "Tipo Entidad", "No. Empleado", "Fecha Inicio")
        {
        }
    }

    trigger OnInsert()
    var
        EstadoMgt: Codeunit "Gestión Estado Empleado";
    begin
        TestField("No. Empleado");
        TestField("Fecha Inicio");
        TestField("Cód. Estado");
        ValidarOrdenFechas();
        ValidarNoHayLiquidacionesBloqueantes("Fecha Inicio", FechaFinEfectiva());
        // Materializes the follow-up state (e.g. Vacaciones → return) regardless of entry path.
        EstadoMgt.AplicarAutoTransicion(Rec);
        // On an active → inactive transition, assign/link the inactivity project.
        EstadoMgt.ResolverProyectoInactividad(Rec);
        // Va último a propósito. AplicarAutoTransicion puede insertar el estado de retorno, y ese
        // insert corre con éste todavía sin escribir en la base: no nos ve como su anterior, así que
        // cierra al que estaba antes que nosotros con SU fecha. Sincronizar acá deja las dos puntas
        // bien: el anterior cerrado contra nuestro inicio, y el nuestro contra el retorno.
        SincronizarContiguidad();
    end;

    trigger OnModify()
    var
        FechaMin: Date;
        FechaMax: Date;
        FinAnterior: Date;
    begin
        ValidarOrdenFechas();
        FechaMin := xRec."Fecha Inicio";
        if "Fecha Inicio" < FechaMin then FechaMin := "Fecha Inicio";

        // El tramo que cambia de manos abarca el fin viejo y el nuevo: acortar un estado le pasa esos
        // días al siguiente, y también tienen que estar libres de liquidaciones. Mirar solo el fin
        // nuevo dejaría pasar justamente el caso de acortar.
        FechaMax := FechaFinEfectiva();
        FinAnterior := xRec."Fecha Fin";
        if FinAnterior = 0D then
            FinAnterior := FechaFinDerivada();
        if FinAnterior > FechaMax then
            FechaMax := FinAnterior;
        ValidarNoHayLiquidacionesBloqueantes(FechaMin, FechaMax);

        // Acortar o alargar un estado a mano arrastra el inicio del siguiente, para no dejar días
        // sin estado ni pisar el estado que sigue.
        if ("Fecha Fin" <> xRec."Fecha Fin") and ("Fecha Fin" <> 0D) then
            EmpujarSiguienteEstado();
        SincronizarContiguidad();
    end;

    trigger OnDelete()
    begin
        ValidarNoHayLiquidacionesBloqueantes("Fecha Inicio", FechaFinEfectiva());
        // El anterior absorbe el tramo que deja libre este estado, si no el borrado abriría un hueco.
        ReabrirAnteriorAlBorrar();
    end;

    /// <summary>
    /// Fin efectivo del estado: la Fecha Fin cargada; si está en blanco, el día anterior al inicio del
    /// estado siguiente de la misma entidad, o 31/12/9999 si es el último.
    /// </summary>
    /// <remarks>
    /// La derivación se conserva como respaldo para filas anteriores a la migración de Fecha Fin y
    /// para el instante entre el insert y la sincronización de contigüidad. Todo el motor lee el fin
    /// por acá, así que ninguno de esos dos casos cambia un cálculo.
    /// </remarks>
    procedure FechaFinEfectiva(): Date
    begin
        if "Fecha Fin" <> 0D then
            exit("Fecha Fin");
        exit(FechaFinDerivada());
    end;

    local procedure FechaFinDerivada(): Date
    var
        Siguiente: Record "Estado Empleado";
    begin
        if BuscarSiguiente(Siguiente) then
            exit(Siguiente."Fecha Inicio" - 1);
        exit(DMY2Date(31, 12, 9999));
    end;

    // Cierra el estado anterior contra el inicio de éste, y toma el propio fin del estado siguiente.
    // Es lo que sostiene la contigüidad del historial en todos los caminos de alta: grilla, diálogo
    // SetEstado, carga en lote, cascada de buque y transición automática de vacaciones.
    local procedure SincronizarContiguidad()
    var
        Anterior: Record "Estado Empleado";
        Siguiente: Record "Estado Empleado";
    begin
        if BuscarAnterior(Anterior) then
            // Dos estados que arrancan el mismo día (posible con distinto No. Proyecto) no se pueden
            // encadenar sin generar un intervalo invertido: se deja el anterior como está.
            if Anterior."Fecha Inicio" < "Fecha Inicio" then
                if Anterior."Fecha Fin" <> "Fecha Inicio" - 1 then begin
                    Anterior."Fecha Fin" := "Fecha Inicio" - 1;
                    Anterior.Modify();
                end;

        if BuscarSiguiente(Siguiente) then
            "Fecha Fin" := Siguiente."Fecha Inicio" - 1;
    end;

    local procedure EmpujarSiguienteEstado()
    var
        Siguiente: Record "Estado Empleado";
        Subsiguiente: Record "Estado Empleado";
        NuevoInicio: Date;
    begin
        if not BuscarSiguiente(Siguiente) then
            exit;
        NuevoInicio := "Fecha Fin" + 1;
        if Siguiente."Fecha Inicio" = NuevoInicio then
            exit;

        // No se puede empujar más allá del estado que viene después del siguiente: ahí habría que
        // decidir cuál se pisa, y esa decisión es del usuario, no de un trigger.
        if BuscarSiguienteDe(Siguiente, Subsiguiente) then
            if NuevoInicio >= Subsiguiente."Fecha Inicio" then
                Error(ErrEmpujeInvalido, "Fecha Fin", Siguiente."Cód. Estado", Subsiguiente."Fecha Inicio");

        Siguiente."Fecha Inicio" := NuevoInicio;
        Siguiente.Modify();
    end;

    local procedure ReabrirAnteriorAlBorrar()
    var
        Anterior: Record "Estado Empleado";
        Siguiente: Record "Estado Empleado";
    begin
        if not BuscarAnterior(Anterior) then
            exit;
        if BuscarSiguiente(Siguiente) then
            Anterior."Fecha Fin" := Siguiente."Fecha Inicio" - 1
        else
            // Éste era el último: el anterior pasa a ser el vigente y queda abierto.
            Anterior."Fecha Fin" := 0D;
        Anterior.Modify();
    end;

    local procedure BuscarAnterior(var Anterior: Record "Estado Empleado"): Boolean
    begin
        Anterior.SetCurrentKey("Tipo Entidad", "No. Empleado", "Fecha Inicio");
        Anterior.SetRange("Tipo Entidad", "Tipo Entidad");
        Anterior.SetRange("No. Empleado", "No. Empleado");
        Anterior.SetFilter("Fecha Inicio", '<=%1', "Fecha Inicio");
        Anterior.SetFilter("No. Mov.", '<>%1', "No. Mov.");
        exit(Anterior.FindLast());
    end;

    local procedure BuscarSiguiente(var Siguiente: Record "Estado Empleado"): Boolean
    begin
        Siguiente.SetCurrentKey("Tipo Entidad", "No. Empleado", "Fecha Inicio");
        Siguiente.SetRange("Tipo Entidad", "Tipo Entidad");
        Siguiente.SetRange("No. Empleado", "No. Empleado");
        Siguiente.SetFilter("Fecha Inicio", '>%1', "Fecha Inicio");
        Siguiente.SetFilter("No. Mov.", '<>%1', "No. Mov.");
        exit(Siguiente.FindFirst());
    end;

    local procedure BuscarSiguienteDe(Desde: Record "Estado Empleado"; var Siguiente: Record "Estado Empleado"): Boolean
    begin
        Siguiente.Reset();
        Siguiente.SetCurrentKey("Tipo Entidad", "No. Empleado", "Fecha Inicio");
        Siguiente.SetRange("Tipo Entidad", Desde."Tipo Entidad");
        Siguiente.SetRange("No. Empleado", Desde."No. Empleado");
        Siguiente.SetFilter("Fecha Inicio", '>%1', Desde."Fecha Inicio");
        Siguiente.SetFilter("No. Mov.", '<>%1', Desde."No. Mov.");
        exit(Siguiente.FindFirst());
    end;

    local procedure ValidarOrdenFechas()
    begin
        if ("Fecha Fin" <> 0D) and ("Fecha Inicio" <> 0D) and ("Fecha Fin" < "Fecha Inicio") then
            Error(ErrFinAntesDeInicio, "Fecha Fin", "Fecha Inicio");
    end;

    // Propuesta de fin para un estado de Vacaciones: los días que le corresponden por LCT. Queda
    // editable — si el empleado vuelve antes, se corrige y el estado siguiente se corre solo.
    local procedure AutoCalcFechaFinVacaciones()
    var
        CodEst: Record "Cód. Estado Empleado";
        EstadoMgt: Codeunit "Gestión Estado Empleado";
        DiasDerecho: Integer;
    begin
        if "Tipo Entidad" <> "Tipo Entidad"::Empleado then
            exit;
        if ("No. Empleado" = '') or ("Fecha Inicio" = 0D) or ("Cód. Estado" = '') then
            exit;
        if not CodEst.Get("Cód. Estado") then
            exit;
        if CodEst."Tipo Estado" <> CodEst."Tipo Estado"::Vacaciones then
            exit;
        DiasDerecho := EstadoMgt.CalcDiasVacaciones("No. Empleado", "Fecha Inicio");
        if DiasDerecho > 0 then
            "Fecha Fin" := "Fecha Inicio" + DiasDerecho - 1;
    end;

    local procedure ValidarNoHayLiquidacionesBloqueantes(FechaDesde: Date; FechaHasta: Date)
    var
        Liq: Record "Liquidación";
        Periodo: Record "Período Liquidación";
    begin
        // Vessel states never block employee liquidations.
        if "Tipo Entidad" <> "Tipo Entidad"::Empleado then
            exit;

        Liq.SetRange("No. Empleado", "No. Empleado");
        Liq.SetFilter(Estado, '<>%1', Liq.Estado::Borrador);
        if not Liq.FindSet() then exit;
        repeat
            if Periodo.Get(Liq."Cód. Período") then
                if (CoberturaHasta(Liq, Periodo) >= FechaDesde) and
                   (Periodo."Fecha Desde" <= FechaHasta)
                then
                    Error(ErrLiquidacionesBloqueantes, Liq."Cód. Período", Liq."No.", Format(Liq.Estado));
        until Liq.Next() = 0;
    end;

    // Upper bound of what a liquidation actually settled. A Cierre de Marea settles at the arrival date
    // (Fecha Liquidación), not the full period end — so it doesn't block state changes made after arrival.
    local procedure CoberturaHasta(Liq: Record "Liquidación"; Periodo: Record "Período Liquidación"): Date
    var
        TipoLiqRec: Record "Tipo Liquidación";
    begin
        if TipoLiqRec.EsArribo(Liq."Cód. Tipo Liq.") and (Liq."Fecha Liquidación" <> 0D) then
            exit(Liq."Fecha Liquidación");
        exit(Periodo."Fecha Hasta");
    end;

    var
        ErrLiquidacionesBloqueantes: Label 'Existe una liquidación no revertida para el período %1 (Liq. %2, estado: %3). Revertí la liquidación antes de modificar el historial de estados.';
        ErrFinAntesDeInicio: Label 'La Fecha Fin (%1) no puede ser anterior a la Fecha Inicio (%2).';
        ErrEmpujeInvalido: Label 'Con Fecha Fin %1 el estado siguiente (%2) tendría que empezar después del estado que ya existe al %3. Ajustá primero ese estado.';
}
