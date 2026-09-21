namespace UAS.Payroll;

using Microsoft.Foundation.UOM;
using Microsoft.HumanResources.Employee;
using Microsoft.Projects.Project.Job;

table 110038 "Novedad Liquidación"
{
    Caption = 'Novedad Liquidación';
    DataClassification = CustomerContent;
    LookupPageId = "Novedades Liquidación";
    DrillDownPageId = "Novedades Liquidación";
    // Carga de novedades ANTES de que exista la liquidación. La contrapartida, Incidencia
    // Liquidación (Tab60020), está keyed por No. Liquidación y por eso obliga a crear primero la
    // liquidación en Borrador; acá se carga contra el período y el motor la materializa como
    // incidencia al calcular (Cod50014 → Gestión Novedades Liq.), igual que las cuotas de préstamo.
    //
    // Los campos selectores en blanco significan "cualquiera", así que una misma novedad sirve para
    // un empleado puntual o para toda una categoría de convenio:
    //   Cód. Tipo Liq. / Cód. Convenio / Cód. Categoría / No. Empleado / No. Proyecto
    // La Fecha se valida dentro del período y define a qué liquidación entra cuando el empleado
    // tiene más de una en el mismo período (mensual y cierre de marea conviven).
    //
    // Convenio y categoría son la excepción: filtran solo cuando NO hay empleado. Con un empleado
    // nombrado quedan como el encuadre con el que se cargó la novedad —dato, no condición— porque
    // el empleado ya identifica la liquidación y compararlos de más solo podía excluir.

    fields
    {
        field(1; "No. Movimiento"; Integer)
        {
            Caption = 'No. Movimiento';
            DataClassification = CustomerContent;
            AutoIncrement = true;
            Editable = false;
        }
        field(2; "Cód. Período"; Code[10])
        {
            Caption = 'Cód. Período';
            NotBlank = true;
            DataClassification = CustomerContent;
            TableRelation = "Período Liquidación".Código;

            trigger OnValidate()
            var
                Periodo: Record "Período Liquidación";
            begin
                if "Cód. Período" = '' then
                    exit;
                Periodo.Get("Cód. Período");
                if Periodo.Estado = Periodo.Estado::Cerrado then
                    Error(ErrPeriodoCerrado, "Cód. Período");
                // La fecha por defecto es el fin de período: es la que usa el motor como referencia
                // en una liquidación mensual, así que es la que no cambia ningún resultado.
                if (Fecha = 0D) or not Periodo.ContieneFecha(Fecha) then
                    Fecha := Periodo."Fecha Hasta";
            end;
        }
        field(3; Fecha; Date)
        {
            Caption = 'Fecha';
            DataClassification = CustomerContent;

            trigger OnValidate()
            var
                Periodo: Record "Período Liquidación";
            begin
                if (Fecha = 0D) or ("Cód. Período" = '') then
                    exit;
                if Periodo.Get("Cód. Período") then
                    if not Periodo.ContieneFecha(Fecha) then
                        Error(ErrFechaFueraPeriodo, Fecha, "Cód. Período", Periodo."Fecha Desde", Periodo."Fecha Hasta");
            end;
        }
        field(4; "Cód. Tipo Liq."; Code[20])
        {
            Caption = 'Cód. Tipo Liq.';
            DataClassification = CustomerContent;
            TableRelation = "Tipo Liquidación".Código;
        }
        field(5; "Cód. Convenio"; Code[20])
        {
            Caption = 'Cód. Convenio';
            DataClassification = CustomerContent;
            TableRelation = "Convenio Colectivo".Código;

            trigger OnValidate()
            begin
                if "Cód. Convenio" <> xRec."Cód. Convenio" then
                    "Cód. Categoría" := '';
            end;
        }
        field(6; "Cód. Categoría"; Code[20])
        {
            Caption = 'Cód. Categoría';
            DataClassification = CustomerContent;
            TableRelation = "Categoría CCT".Código WHERE("Cód. Convenio" = FIELD("Cód. Convenio"));
        }
        field(7; "No. Empleado"; Code[20])
        {
            Caption = 'No. Empleado';
            DataClassification = CustomerContent;
            TableRelation = Employee."No.";

            trigger OnValidate()
            var
                Emp: Record Employee;
            begin
                if "No. Empleado" = '' then begin
                    "Nombre Empleado" := '';
                    exit;
                end;
                if Emp.Get("No. Empleado") then begin
                    "Nombre Empleado" := CopyStr(Emp."First Name" + ' ' + Emp."Last Name", 1, MaxStrLen("Nombre Empleado"));
                    ProponerParDelEmpleado(Emp);
                end;
            end;
        }
        field(8; "Nombre Empleado"; Text[100])
        {
            Caption = 'Nombre Empleado';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(9; "No. Proyecto"; Code[20])
        {
            Caption = 'No. Proyecto (Marea)';
            DataClassification = CustomerContent;
            TableRelation = Job."No.";
            // En blanco = cualquier proyecto. Cargado, la novedad entra únicamente en liquidaciones
            // de esa marea, sin depender de que la fecha caiga dentro del viaje.

            trigger OnValidate()
            begin
                ProponerFechaDeProyecto();
            end;
        }
        field(10; "Cód. Concepto"; Code[20])
        {
            Caption = 'Cód. Concepto';
            NotBlank = true;
            DataClassification = CustomerContent;
            TableRelation = "Concepto Liquidación".Código;
        }
        field(12; Cantidad; Decimal)
        {
            Caption = 'Cantidad';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 4;

            trigger OnValidate()
            begin
                RecalcularImporte();
            end;
        }
        field(13; "Unidad Cantidad"; Code[10])
        {
            Caption = 'Unidad Cantidad';
            DataClassification = CustomerContent;
            TableRelation = "Unit of Measure".Code;
        }
        field(14; "Valor Unitario"; Decimal)
        {
            Caption = 'Valor Unitario';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 4;

            trigger OnValidate()
            begin
                RecalcularImporte();
            end;
        }
        field(15; Importe; Decimal)
        {
            Caption = 'Importe';
            DataClassification = CustomerContent;
            DecimalPlaces = 2 : 2;
        }
        field(16; Observaciones; Text[250])
        {
            Caption = 'Observaciones';
            DataClassification = CustomerContent;
        }
        field(20; Estado; Enum "Estado Novedad Liq.")
        {
            Caption = 'Estado';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(21; "No. Liquidación"; Code[20])
        {
            Caption = 'No. Liquidación';
            DataClassification = CustomerContent;
            Editable = false;
            TableRelation = "Liquidación"."No.";
        }
        field(22; "Motivo No Aplicada"; Text[250])
        {
            Caption = 'Motivo No Aplicada';
            DataClassification = CustomerContent;
            Editable = false;
            // Por qué el motor la salteó. Sin esto una novedad ignorada es invisible: no hay dónde
            // mostrar un mensaje cuando el cálculo corre por lote.
        }
        field(30; Recurrente; Boolean)
        {
            Caption = 'Recurrente';
            DataClassification = CustomerContent;
        }
        field(31; "Períodos Restantes"; Integer)
        {
            Caption = 'Períodos Restantes';
            DataClassification = CustomerContent;
            MinValue = 0;
            // 0 con Recurrente = se repite indefinidamente hasta que se desmarque.
            // >0 = se repite esa cantidad de períodos más y se apaga sola.

            trigger OnValidate()
            begin
                if "Períodos Restantes" > 0 then
                    Recurrente := true;
            end;
        }
        field(32; "Novedad Origen"; Integer)
        {
            Caption = 'Novedad Origen';
            DataClassification = CustomerContent;
            Editable = false;
            TableRelation = "Novedad Liquidación"."No. Movimiento";
            // Raíz de la cadena de recurrencia, propagada a cada copia. Es lo que permite generar el
            // período siguiente dos veces sin duplicar novedades.
        }
    }

    keys
    {
        key(PK; "No. Movimiento") { Clustered = true; }
        key(K2; "Cód. Período", Estado) { }
        key(K3; "Cód. Período", "No. Empleado", "Cód. Concepto") { }
        key(K4; "No. Liquidación") { }
        key(K5; "Novedad Origen", "Cód. Período") { }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "Cód. Período", "No. Empleado", "Cód. Concepto", Importe) { }
    }

    trigger OnInsert()
    begin
        ValidarEditable();
        if "Cód. Período" = '' then
            Error(ErrFaltaPeriodo);
    end;

    trigger OnModify()
    begin
        ValidarEditable();
    end;

    trigger OnDelete()
    begin
        ValidarEditable();
    end;

    // Una novedad ya aplicada vive dentro de una liquidación: editarla sin reabrir dejaría la
    // incidencia calculada y la novedad diciendo cosas distintas. Mismo criterio que Tab60020.
    local procedure ValidarEditable()
    var
        Liq: Record "Liquidación";
        Periodo: Record "Período Liquidación";
    begin
        if Periodo.Get("Cód. Período") then
            if Periodo.Estado = Periodo.Estado::Cerrado then
                Error(ErrPeriodoCerrado, "Cód. Período");
        if "No. Liquidación" = '' then
            exit;
        if Liq.Get("No. Liquidación") then
            if Liq.Estado <> Liq.Estado::Borrador then
                Error(ErrLiqNoBorrador, "No. Liquidación");
    end;

    /// <summary>
    /// Propone el encuadre del empleado con el MISMO criterio que la liquidación: los atributos
    /// vigentes a la fecha de la novedad, no los campos de la ficha.
    /// </summary>
    /// <remarks>
    /// Convenio y categoría no valorizan nada acá: son FILTROS. El motor compara el par de la novedad
    /// contra el de la liquidación y, si difieren, la novedad no entra — sin error, sin motivo
    /// anotado y mostrándose igual en la hoja (ver NovedadAplica en "Gestión Novedades Liq.").
    ///
    /// Llenarlos de la ficha, como se hacía antes, era programar ese choque: la liquidación resolvió
    /// su par contra los ATRIBUTOS desde que el encuadre pasó a tener historial, y ficha y atributo
    /// pueden diferir por dos motivos concretos —el atributo tiene vigencias y la ficha no, y la
    /// migración permitió tomar el par del PROYECTO en vez de la ficha—.
    ///
    /// La ficha queda como red: un empleado al que todavía no se le cargaron los atributos conserva
    /// el comportamiento anterior en vez de quedarse sin par.
    ///
    /// Solo propone con los DOS campos vacíos. Si hay alguno cargado, quien lo cargó está dirigiendo
    /// el alcance de la novedad a mano y completar el otro por su cuenta armaría un par mezclado.
    /// </remarks>
    local procedure ProponerParDelEmpleado(Emp: Record Employee)
    var
        Periodo: Record "Período Liquidación";
        ParCCT: Codeunit "Convenio Categoría Liq.";
        Convenio: Code[20];
        Categoria: Code[20];
        FechaRef: Date;
    begin
        if ("Cód. Convenio" <> '') or ("Cód. Categoría" <> '') then
            exit;

        // La misma aproximación que usa la liquidación al crearse: la fecha propia si ya está, si no
        // el fin del período. Al validar el período la Fecha ya quedó propuesta, así que en el orden
        // de carga normal acá llega cargada.
        FechaRef := Fecha;
        if Periodo.Get("Cód. Período") then
            if FechaRef = 0D then
                FechaRef := Periodo."Fecha Hasta";
        if FechaRef = 0D then
            FechaRef := WorkDate();

        if not ParCCT.ParDeEntidad("No. Empleado", FechaRef, Periodo."Fecha Desde", Periodo."Fecha Hasta", Convenio, Categoria) then begin
            Convenio := Emp."Cód. Convenio";
            Categoria := Emp."Cód. Categoría";
        end;

        // Asignación directa y no Validate: el OnValidate de "Cód. Convenio" limpia la categoría, así
        // que validarlos en orden borraría la que se acaba de resolver.
        "Cód. Convenio" := Convenio;
        "Cód. Categoría" := Categoria;
    end;

    // Igual que en Incidencia Liquidación: si después se edita el Importe a mano, esa edición manda
    // hasta que se vuelva a validar Cantidad o Valor Unitario.
    local procedure RecalcularImporte()
    begin
        if (Cantidad <> 0) and ("Valor Unitario" <> 0) then
            Importe := Round(Cantidad * "Valor Unitario", 0.01);
    end;

    // Texto para la hoja de carga: hace visible de un vistazo si la novedad es de un empleado o si
    // barre una categoría entera. Sin esto, una novedad masiva se ve igual que una individual.
    /// <summary>
    /// Al elegir la marea, propone como Fecha el último día en que esa marea cae dentro del período.
    /// </summary>
    /// <remarks>
    /// La fecha no es decorativa: decide en qué liquidación entra la novedad cuando el empleado tiene
    /// más de una en el período, y tiene que caer dentro del rango que esa liquidación cubre. El
    /// último día es el que siempre sirve — hay liquidación cubriendo hasta ahí — mientras que una
    /// fecha anterior puede quedar afuera del cierre de marea.
    ///
    /// Se toma el menor entre el arribo y el fin del período, que es justo el caso de una marea a
    /// caballo de dos meses: la que empieza el 25/07 y arriba el 08/08 propone 31/07 en el período de
    /// julio —el corte de fin de mes, que es lo que liquida el Devengado— y 08/08 en el de agosto.
    /// Con la marea todavía sin fecha de arribo cargada, el fin del período es la única respuesta
    /// posible y también la correcta.
    ///
    /// Es una PROPUESTA: el campo queda editable para la novedad que corresponde a un día concreto
    /// del viaje.
    /// </remarks>
    local procedure ProponerFechaDeProyecto()
    var
        Job: Record Job;
        Periodo: Record "Período Liquidación";
        Propuesta: Date;
    begin
        if "No. Proyecto" = '' then
            exit;
        if not Periodo.Get("Cód. Período") then
            exit;
        if not Job.Get("No. Proyecto") then
            exit;

        Propuesta := Periodo."Fecha Hasta";
        if (Job."Ending Date" <> 0D) and (Job."Ending Date" < Propuesta) then
            Propuesta := Job."Ending Date";

        // Una marea que terminó antes de que arrancara el período no tiene día válido acá: se deja la
        // fecha como esté en vez de proponer una anterior al período, que el propio OnValidate de
        // Fecha rechazaría.
        if Propuesta < Periodo."Fecha Desde" then
            exit;

        Fecha := Propuesta;
    end;

    procedure DescribirAlcance(): Text
    var
        Partes: TextBuilder;
    begin
        if "No. Empleado" <> '' then
            Partes.Append("No. Empleado" + ' ' + "Nombre Empleado")
        else
            if "Cód. Convenio" <> '' then begin
                Partes.Append(StrSubstNo(AlcanceConvenioTxt, "Cód. Convenio"));
                if "Cód. Categoría" <> '' then
                    Partes.Append(' / ' + "Cód. Categoría");
            end else
                Partes.Append(AlcanceTodosTxt);

        if "No. Proyecto" <> '' then
            Partes.Append(StrSubstNo(AlcanceProyectoTxt, "No. Proyecto"));
        if "Cód. Tipo Liq." <> '' then
            Partes.Append(StrSubstNo(AlcanceTipoTxt, "Cód. Tipo Liq."));
        exit(Partes.ToText());
    end;

    var
        ErrPeriodoCerrado: Label 'El período %1 está cerrado.';
        ErrFechaFueraPeriodo: Label 'La fecha %1 está fuera del período %2 (%3 .. %4).';
        ErrLiqNoBorrador: Label 'La novedad ya se aplicó en la liquidación %1, que no está en Borrador. Reabrí la liquidación para modificarla.';
        ErrFaltaPeriodo: Label 'Indicá el Cód. Período de la novedad.';
        AlcanceConvenioTxt: Label 'Todo el convenio %1';
        AlcanceTodosTxt: Label 'Todos los empleados';
        AlcanceProyectoTxt: Label ' — marea %1';
        AlcanceTipoTxt: Label ' — solo %1';
}
