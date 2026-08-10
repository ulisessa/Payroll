namespace UAS.Payroll;

using Microsoft.Foundation.UOM;
using Microsoft.HumanResources.Employee;
using Microsoft.Projects.Project.Job;

table 60034 "Novedad Liquidación"
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
                    // Mismo criterio que la liquidación (Tab60011): convenio y categoría salen de la
                    // ficha. Quedan editables para poder cargar una novedad sobre otra escala.
                    if "Cód. Convenio" = '' then
                        "Cód. Convenio" := Emp."Cód. Convenio";
                    if "Cód. Categoría" = '' then
                        "Cód. Categoría" := Emp."Cód. Categoría";
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

    // Igual que en Incidencia Liquidación: si después se edita el Importe a mano, esa edición manda
    // hasta que se vuelva a validar Cantidad o Valor Unitario.
    local procedure RecalcularImporte()
    begin
        if (Cantidad <> 0) and ("Valor Unitario" <> 0) then
            Importe := Round(Cantidad * "Valor Unitario", 0.01);
    end;

    // Texto para la hoja de carga: hace visible de un vistazo si la novedad es de un empleado o si
    // barre una categoría entera. Sin esto, una novedad masiva se ve igual que una individual.
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
