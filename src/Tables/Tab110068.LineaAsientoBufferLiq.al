namespace UAS.Payroll;

/// <summary>
/// Una línea de la previa del asiento de sueldos: una cuenta con su proyecto, o un aviso.
/// </summary>
/// <remarks>
/// LAS LÍNEAS Y LOS AVISOS VAN EN LA MISMA GRILLA. Un asiento que balancea pero dejó un concepto
/// afuera se ve prolijo; poner el aviso debajo de las cuentas, en la misma lista y con el mismo
/// orden, obliga a verlo al recorrerla. Es el mismo criterio que la hoja Avisos de SICOSS.
/// </remarks>
table 110068 "Línea Asiento Buffer Liq."
{
    Caption = 'Línea de la previa del asiento';
    DataClassification = SystemMetadata;
    TableType = Temporary;

    fields
    {
        field(1; "No. Línea"; Integer)
        {
            Caption = 'No. Línea';
        }
        field(2; Clase; Option)
        {
            Caption = 'Clase';
            OptionMembers = Cuenta,Redondeo,Aviso,Origen;
            OptionCaption = 'Cuenta,Redondeo,Aviso,Origen';
            // Origen es el detalle de una línea de la previa: de qué línea de liquidación (o de qué
            // partida de provisión, o de qué lote de francos) salió cada importe. Se arma aparte,
            // en otra instancia, al pedir el origen de una cuenta o de un aviso.
        }
        field(3; Cuenta; Code[20])
        {
            Caption = 'Cuenta';
        }
        field(4; "Nombre Cuenta"; Text[100])
        {
            Caption = 'Nombre de la cuenta';
        }
        field(5; "No. Proyecto"; Code[20])
        {
            Caption = 'Proyecto';
        }
        field(6; Debe; Decimal)
        {
            Caption = 'Debe';
            AutoFormatType = 1;
        }
        field(7; Haber; Decimal)
        {
            Caption = 'Haber';
            AutoFormatType = 1;
        }
        field(8; Conceptos; Text[250])
        {
            Caption = 'Conceptos';
            // Los conceptos que aportaron a la línea, hasta donde entran. Una provisión aparece como
            // "PROV:" y el concepto.
        }
        field(9; Cantidad; Integer)
        {
            Caption = 'Cantidad';
            // En una cuenta, cuántas liquidaciones le aportaron; en un aviso, cuántas veces apareció.
        }
        field(10; Mensaje; Text[250])
        {
            Caption = 'Mensaje';
        }
        field(11; Importe; Decimal)
        {
            Caption = 'Importe (Debe +)';
            AutoFormatType = 1;
        }
        field(12; "Clave Origen"; Text[250])
        {
            Caption = 'Clave de origen';
            // La clave con que la previa acumuló la línea (cuenta|proyecto, o la del aviso). Es lo
            // que sigue el drilldown para encontrar sus orígenes.
        }
        field(20; "No. Liquidación"; Code[20])
        {
            Caption = 'No. Liquidación';
        }
        field(21; "No. Línea Liq."; Integer)
        {
            Caption = 'No. Línea de liquidación';
            // Cero cuando el origen no es una línea: una partida de provisión que agrupa la
            // liquidación, o un lote de francos cuya liquidación de origen ya no está.
        }
        field(22; "Cód. Concepto"; Code[20])
        {
            Caption = 'Concepto';
        }
        field(23; "Descripción Concepto"; Text[100])
        {
            Caption = 'Descripción del concepto';
        }
        field(24; "No. Empleado"; Code[20])
        {
            Caption = 'No. Empleado';
            DataClassification = EndUserIdentifiableInformation;
        }
        field(25; "Cód. Tipo Liq."; Code[20])
        {
            Caption = 'Tipo de liquidación';
        }
        field(26; Origen; Text[30])
        {
            Caption = 'Origen';
        }
    }

    keys
    {
        key(PK; "No. Línea") { Clustered = true; }
        key(PorCuenta; Clase, Cuenta, "No. Proyecto") { }
    }
}
