namespace UAS.Payroll;

table 110047 "Stg Valor Dim NAV"
{
    Caption = 'Staging Valor de Dimensión NAV';
    DataClassification = CustomerContent;
    LookupPageId = "Sinc. Valores Dim. NAV";
    DrillDownPageId = "Sinc. Valores Dim. NAV";
    // Los valores de dimensión que usan los proyectos de NAV. Es la primera entidad que se procesa,
    // y existe por una razón concreta: una marea nueva es, por definición, un valor de dimensión que
    // BC todavía no tiene. Sin esto, cada marea nueva hace fallar el Job.Validate de su proyecto y
    // la fila queda en Error todos los meses.
    //
    // El nombre importa y por eso se trae de NAV en vez de inventarse: allá "V03" es "Villarino III"
    // y "868" es "Buque Sunrise 868 (Alunamar)". Crear el valor con el código como nombre dejaría la
    // dimensión llena de códigos que nadie puede interpretar seis meses después.

    fields
    {
        field(1; "Cod Dimension"; Code[20])
        {
            Caption = 'Código Dimensión';
            DataClassification = CustomerContent;
        }
        field(2; Codigo; Code[20])
        {
            Caption = 'Código';
            DataClassification = CustomerContent;
        }
        field(10; Nombre; Text[100])
        {
            Caption = 'Nombre';
            DataClassification = CustomerContent;
        }
        field(11; Bloqueado; Boolean)
        {
            Caption = 'Bloqueado en origen';
            DataClassification = CustomerContent;
            // Se trae para no dar de alta en BC un código que en NAV ya está fuera de uso.
        }
        field(90; "Estado Sinc"; Enum "Estado Sinc NAV")
        {
            Caption = 'Estado';
            DataClassification = CustomerContent;
        }
        field(91; Observacion; Text[250])
        {
            Caption = 'Observación';
            DataClassification = CustomerContent;
            // Con Estado = Error es el motivo del fallo; con Estado = Procesado es un aviso: se
            // aplicó, pero algo quedó sin resolver y conviene mirarlo.
        }
        field(92; Intentos; Integer)
        {
            Caption = 'Intentos';
            DataClassification = CustomerContent;
        }
        field(93; "Marca Origen"; Text[20])
        {
            Caption = 'Rowversion Origen';
            DataClassification = CustomerContent;
        }
        field(94; "Traido El"; DateTime)
        {
            Caption = 'Traído El';
            DataClassification = CustomerContent;
        }
        field(95; "Procesado El"; DateTime)
        {
            Caption = 'Procesado El';
            DataClassification = CustomerContent;
        }
    }

    keys
    {
        key(PK; "Cod Dimension", Codigo) { Clustered = true; }
        key(K2; "Estado Sinc", "Cod Dimension", Codigo) { }
    }
}
