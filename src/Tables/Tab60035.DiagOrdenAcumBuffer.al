namespace UAS.Payroll;

table 60035 "Diag. Orden Acum. Buffer"
{
    // Scratch buffer del control de orden de cálculo de acumuladores (se usa solo desde una página
    // SourceTableTemporary, igual que "Diag. Fuente Datos Buffer").
    Caption = 'Diag. Orden Acumulador Buffer';
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Cód. Acumulador"; Code[20])
        {
            Caption = 'Cód. Acumulador';
            DataClassification = SystemMetadata;
        }
        field(2; Descripción; Text[100])
        {
            Caption = 'Descripción';
            DataClassification = SystemMetadata;
        }
        field(10; "Orden Máx. Aporte"; Integer)
        {
            Caption = 'Orden Últ. Aporte';
            DataClassification = SystemMetadata;
            // Orden Cálculo del concepto que alimenta este acumulador más tarde en la corrida.
        }
        field(11; "Concepto Máx. Aporte"; Code[20])
        {
            Caption = 'Concepto Últ. Aporte';
            DataClassification = SystemMetadata;
        }
        field(20; "Orden Mín. Lectura"; Integer)
        {
            Caption = 'Orden 1ª Lectura';
            DataClassification = SystemMetadata;
            // Orden Cálculo del primer concepto cuya fórmula o condición nombra al acumulador.
        }
        field(21; "Concepto Mín. Lectura"; Code[20])
        {
            Caption = 'Concepto 1ª Lectura';
            DataClassification = SystemMetadata;
        }
        field(30; "Aportes en Conflicto"; Integer)
        {
            Caption = 'Aportes en Conflicto';
            DataClassification = SystemMetadata;
            // Cuántos conceptos aportan en un Orden Cálculo que la primera lectura ya no alcanza a ver.
        }
        field(31; "Códigos en Conflicto"; Text[250])
        {
            Caption = 'Conceptos a Reordenar';
            DataClassification = SystemMetadata;
        }
        field(40; Conflicto; Boolean)
        {
            Caption = 'Conflicto';
            DataClassification = SystemMetadata;
        }
        field(41; "Orden Sugerido"; Integer)
        {
            Caption = 'Orden Sugerido Lectura';
            DataClassification = SystemMetadata;
            // Primer Orden Cálculo en el que una lectura ve el acumulador completo. Es una de las dos
            // salidas posibles: mover las lecturas acá, o adelantar los aportes por debajo de la
            // lectura actual. Cuál conviene depende de qué más dependa de esos conceptos.
        }
        field(50; "Cant. Aportes"; Integer)
        {
            Caption = 'Cant. Aportes';
            DataClassification = SystemMetadata;
        }
        field(51; "Cant. Lecturas"; Integer)
        {
            Caption = 'Cant. Lecturas';
            DataClassification = SystemMetadata;
        }
    }

    keys
    {
        key(PK; "Cód. Acumulador") { Clustered = true; }
        key(K2; Conflicto, "Cód. Acumulador") { }
    }
}
