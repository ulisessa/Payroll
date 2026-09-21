namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;

// Saldo de francos abierto por tripulante y categoría. Siempre temporal: no se persiste nada.
//
// El saldo de un tripulante NO es un número: los francos no son fungibles. Cada lote queda sellado
// con el convenio y la categoría con los que se ganó, y se paga al valor de ESA categoría aunque hoy
// el tripulante esté encuadrado en otra. Un marinero que ascendió a contramaestre puede tener
// quince francos, y esos quince valer dos precios distintos según en qué categoría los devengó.
//
// Por eso la fila es (empleado, convenio, categoría) y no (empleado): mostrar un total por persona
// escondería justamente lo que hay que controlar.
table 110011 "Francos Buffer Liq."
{
    Caption = 'Francos por Tripulante y Categoría';
    DataClassification = CustomerContent;
    TableType = Temporary;

    fields
    {
        field(1; "No. Empleado"; Code[20])
        {
            Caption = 'No. Empleado';
            DataClassification = EndUserIdentifiableInformation;
            TableRelation = Employee."No.";
        }
        field(2; "Cód. Convenio"; Code[20])
        {
            Caption = 'Convenio';
            DataClassification = CustomerContent;
            // El del LOTE, no el del encuadre actual del tripulante.
        }
        field(3; "Cód. Categoría"; Code[20])
        {
            Caption = 'Categoría';
            DataClassification = CustomerContent;
        }
        field(4; "Nombre Empleado"; Text[100])
        {
            Caption = 'Empleado';
            DataClassification = EndUserIdentifiableInformation;
        }
        field(5; "Descripción Categoría"; Text[100])
        {
            Caption = 'Descripción Categoría';
            DataClassification = CustomerContent;
        }
        field(6; Devengados; Decimal)
        {
            Caption = 'Devengados';
            DecimalPlaces = 0 : 2;
            DataClassification = CustomerContent;
        }
        field(7; Consumidos; Decimal)
        {
            Caption = 'Consumidos';
            DecimalPlaces = 0 : 2;
            DataClassification = CustomerContent;
            // Atribuidos por FIFO: el consumo no dice de qué categoría salió, se deduce recorriendo
            // los lotes del más viejo al más nuevo, que es como los paga el motor.
        }
        field(8; Saldo; Decimal)
        {
            Caption = 'Saldo';
            DecimalPlaces = 0 : 2;
            DataClassification = CustomerContent;
        }
        field(9; "Valor Franco"; Decimal)
        {
            Caption = 'Valor del Franco';
            DecimalPlaces = 2 : 2;
            DataClassification = CustomerContent;
            // VALOR_FRANCO_<CONVENIO>_<CATEGORÍA> a la fecha de corte. En cero significa que el
            // parámetro no existe para esa categoría — y entonces esos francos se pagarían a cero.
        }
        field(10; "Importe Saldo"; Decimal)
        {
            Caption = 'Importe del Saldo';
            DecimalPlaces = 2 : 2;
            DataClassification = CustomerContent;
        }
        field(11; "Lote Más Antiguo"; Date)
        {
            Caption = 'Lote Más Antiguo';
            DataClassification = CustomerContent;
        }
        field(12; "Lote Más Reciente"; Date)
        {
            Caption = 'Lote Más Reciente';
            DataClassification = CustomerContent;
        }
        field(13; Lotes; Integer)
        {
            Caption = 'Lotes';
            DataClassification = CustomerContent;
        }
    }

    keys
    {
        key(PK; "No. Empleado", "Cód. Convenio", "Cód. Categoría") { Clustered = true; }
        // Para ordenar por lo que más pesa haciendo clic en la columna.
        key(Saldo; Saldo) { }
        key(Importe; "Importe Saldo") { }
        key(Categoria; "Cód. Convenio", "Cód. Categoría", "No. Empleado") { }
    }
}
