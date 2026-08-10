namespace UAS.Payroll;

using Microsoft.Foundation.UOM;

report 50044 "Insertar Incidencia Masiva"
{
    ApplicationArea = All;
    Caption = 'Insertar Incidencia Masiva';
    UsageCategory = Tasks;
    ProcessingOnly = true;

    dataset
    {
        dataitem(Liq; "Liquidación")
        {
            RequestFilterFields = "No.", "Cód. Período", "Cód. Tipo Liq.", "No. Empleado", "Cód. Convenio", Estado;

            trigger OnAfterGetRecord()
            begin
                Progress.Update(1, Liq."Nombre Empleado");
                Progress.Update(2, Procesados);
                Progress.Update(3, Contador);
                if GestionIncid.InsertarIncidencia(
                    Liq, CodConcepto, Cantidad, UnidadCantidad, ValorUnitario, Importe, Observaciones, Sobrescribir)
                then
                    Contador += 1;
                Procesados += 1;
            end;

            trigger OnPreDataItem()
            begin
                if CodConcepto = '' then
                    Error(ErrFaltaConcepto);
                if (Cantidad <> 0) and (ValorUnitario <> 0) then
                    Importe := Round(Cantidad * ValorUnitario, 0.01);
                if Importe = 0 then
                    Error(ErrFaltaImporte);
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
                    Caption = 'Incidencia a insertar';

                    field(CodConceptoField; CodConcepto)
                    {
                        ApplicationArea = All;
                        Caption = 'Cód. Concepto';
                        TableRelation = "Concepto Liquidación".Código;
                        ToolTip = 'Concepto para el cual se cargará la incidencia en cada liquidación seleccionada.';
                    }
                    field(CantidadField; Cantidad)
                    {
                        ApplicationArea = All;
                        Caption = 'Cantidad';
                        DecimalPlaces = 0 : 4;
                        ToolTip = 'Opcional. Si se completa junto con Valor Unitario, el Importe se calcula solo (Cantidad × Valor Unitario).';
                    }
                    field(UnidadCantidadField; UnidadCantidad)
                    {
                        ApplicationArea = All;
                        Caption = 'Unidad Cantidad';
                        TableRelation = "Unit of Measure".Code;
                        ToolTip = 'Unidad de la Cantidad (ej. DIA, HORA). Opcional.';
                    }
                    field(ValorUnitarioField; ValorUnitario)
                    {
                        ApplicationArea = All;
                        Caption = 'Valor Unitario';
                        DecimalPlaces = 0 : 4;
                        ToolTip = 'Opcional. Si se completa junto con Cantidad, el Importe se calcula solo (Cantidad × Valor Unitario).';
                    }
                    field(ImporteField; Importe)
                    {
                        ApplicationArea = All;
                        Caption = 'Importe';
                        ToolTip = 'Importe a cargar en cada liquidación seleccionada. Se puede escribir directo, o dejar que se calcule desde Cantidad × Valor Unitario.';
                    }
                    field(ObservacionesField; Observaciones)
                    {
                        ApplicationArea = All;
                        Caption = 'Observaciones';
                        ToolTip = 'Texto opcional que se copia igual en cada incidencia creada.';
                    }
                    field(SobrescribirField; Sobrescribir)
                    {
                        ApplicationArea = All;
                        Caption = 'Sobrescribir si ya existe';
                        ToolTip = 'Si está activo, reemplaza la incidencia existente para ese concepto en las liquidaciones que ya la tengan. Si no, esas liquidaciones se omiten (se cuentan aparte al finalizar).';
                    }
                }
            }
        }
    }

    trigger OnPostReport()
    begin
        Message(MsgResultado, Contador, Procesados - Contador);
    end;

    var
        GestionIncid: Codeunit "Gestión Incidencia Masiva";
        Progress: Dialog;
        CodConcepto: Code[20];
        Cantidad: Decimal;
        UnidadCantidad: Code[10];
        ValorUnitario: Decimal;
        Importe: Decimal;
        Observaciones: Text[250];
        Sobrescribir: Boolean;
        Contador: Integer;
        Procesados: Integer;
        DlgProgreso: Label 'Insertando incidencias...\\Empleado: #1########\\Procesados: #2###\\Insertadas: #3###';
        ErrFaltaConcepto: Label 'Debe seleccionar un Cód. Concepto.';
        ErrFaltaImporte: Label 'El Importe debe ser distinto de cero (directamente, o vía Cantidad × Valor Unitario).';
        MsgResultado: Label 'Se insertó la incidencia en %1 liquidación(es). %2 omitida(s) (no estaba en Borrador, o ya tenía incidencia para ese concepto sin "Sobrescribir").';
}
