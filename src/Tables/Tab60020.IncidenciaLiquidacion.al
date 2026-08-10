namespace UAS.Payroll;

using Microsoft.Foundation.UOM;

table 60020 "Incidencia Liquidación"
{
    Caption = 'Incidencia Liquidación';
    DataClassification = CustomerContent;
    // Stores manual amounts for concepts that require per-liquidation data entry
    // (adjustments, retroactives, gratifications, etc.).
    //
    // In FuenteDatos, reference via token {LIQ_NO} to filter by current liquidation:
    //   Filtro 1: "No. Liquidación" = {LIQ_NO}
    //   Filtro 2: "Cód. Concepto"  = <literal concept code>
    //   Función: LOOKUP, Campo: Importe
    //   → Nombre Variable: INCID_<concept code>

    fields
    {
        field(1; "No. Liquidación"; Code[20])
        {
            Caption = 'No. Liquidación';
            NotBlank = true;
            DataClassification = CustomerContent;
            TableRelation = "Liquidación"."No.";
        }
        field(2; "Cód. Concepto"; Code[20])
        {
            Caption = 'Cód. Concepto';
            NotBlank = true;
            DataClassification = CustomerContent;
            TableRelation = "Concepto Liquidación".Código;
        }
        field(3; Importe; Decimal)
        {
            Caption = 'Importe';
            DataClassification = CustomerContent;
            DecimalPlaces = 2 : 2;
        }
        field(6; Cantidad; Decimal)
        {
            Caption = 'Cantidad';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 4;
            trigger OnValidate()
            begin
                RecalcularImporte();
            end;
        }
        field(7; "Unidad Cantidad"; Code[10])
        {
            Caption = 'Unidad Cantidad';
            DataClassification = CustomerContent;
            TableRelation = "Unit of Measure".Code;
        }
        field(8; "Valor Unitario"; Decimal)
        {
            Caption = 'Valor Unitario';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 4;
            trigger OnValidate()
            begin
                RecalcularImporte();
            end;
        }
        field(4; Observaciones; Text[250])
        {
            Caption = 'Observaciones';
            DataClassification = CustomerContent;
        }
        field(5; "Cód. Cuota Préstamo"; Code[30])
        {
            Caption = 'Cuota Préstamo';
            DataClassification = CustomerContent;
            Editable = false;
            // Auto-populated by the loan module: "No.Prestamo|NoCuota".
            // Identifies loan-generated incidencias so they can be cleared on reversal.
        }
        field(9; "Desde Novedad"; Boolean)
        {
            Caption = 'Desde Novedad';
            DataClassification = CustomerContent;
            Editable = false;
            // Marca las incidencias materializadas desde Novedad Liquidación, igual que hace
            // "Cód. Cuota Préstamo" con las cuotas. Es lo que permite borrarlas y regenerarlas en
            // cada recálculo sin tocar las que cargó una persona a mano.
        }
    }

    keys
    {
        key(PK; "No. Liquidación", "Cód. Concepto") { Clustered = true; }
    }

    trigger OnInsert()
    begin
        ValidarEstadoBorrador();
    end;

    trigger OnModify()
    begin
        ValidarEstadoBorrador();
        // Tocar a mano una incidencia que había generado una novedad la convierte en manual: a
        // partir de acá el recálculo la respeta en vez de borrarla y rehacerla desde la novedad,
        // que es lo que haría perder el ajuste. Ningún proceso automático modifica estas filas
        // (novedades solo inserta, y el módulo de préstamos corre antes de que existan).
        if "Desde Novedad" then
            "Desde Novedad" := false;
    end;

    trigger OnDelete()
    begin
        ValidarEstadoBorrador();
    end;

    // Autocompleta Importe = Cantidad × Valor Unitario cuando ambos están cargados. Si el
    // usuario después edita Importe a mano, esa edición queda (no se vuelve a pisar hasta que
    // se valide Cantidad o Valor Unitario de nuevo).
    local procedure RecalcularImporte()
    begin
        if (Cantidad <> 0) and ("Valor Unitario" <> 0) then
            Importe := Round(Cantidad * "Valor Unitario", 0.01);
    end;

    local procedure ValidarEstadoBorrador()
    var
        Liq: Record "Liquidación";
    begin
        if Liq.Get("No. Liquidación") then
            if Liq.Estado <> Liq.Estado::Borrador then
                Error(ErrNoEsBorrador);
    end;

    var
        ErrNoEsBorrador: Label 'Solo se pueden modificar incidencias en liquidaciones en estado Borrador.';
}
