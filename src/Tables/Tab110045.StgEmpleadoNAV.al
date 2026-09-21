namespace UAS.Payroll;

table 110045 "Stg Empleado NAV"
{
    Caption = 'Staging Empleado NAV';
    DataClassification = CustomerContent;
    LookupPageId = "Sinc. Empleados NAV";
    DrillDownPageId = "Sinc. Empleados NAV";
    // Espejo del Employee de NAV. Trae la identidad y los datos personales; NO trae convenio ni
    // categoría, que son decisión de liquidación y se cargan en BC. Por eso el alta deja al empleado
    // marcado con "Pendiente Completar Liq." y lo que NAV tenga cargado como convenio/categoría
    // queda acá al lado, como referencia para quien completa, sin aplicarse a la ficha.
    //
    // Un alta que entra por SQL directo no genera la fila de Alta en Estado Empleado, y sin esa fila
    // la antigüedad da cero y los francos no devengan. Esa es la razón principal de que el empleado
    // se cree por AL y no por MERGE.

    fields
    {
        field(1; "No Empleado"; Code[20])
        {
            Caption = 'No. Empleado';
            DataClassification = CustomerContent;
        }
        field(10; Apellido; Text[50])
        {
            Caption = 'Apellido';
            DataClassification = CustomerContent;
        }
        field(11; Nombre; Text[50])
        {
            Caption = 'Nombre';
            DataClassification = CustomerContent;
        }
        field(12; "Segundo Nombre"; Text[50])
        {
            Caption = 'Segundo Nombre';
            DataClassification = CustomerContent;
        }
        field(13; Iniciales; Text[10])
        {
            Caption = 'Iniciales';
            DataClassification = CustomerContent;
        }
        field(14; "Puesto Titulo"; Text[50])
        {
            Caption = 'Puesto';
            DataClassification = CustomerContent;
        }
        field(15; "Fecha Ingreso"; Date)
        {
            Caption = 'Fecha de Ingreso';
            DataClassification = CustomerContent;
            // Es la fecha con la que se abre el estado de Alta en el historial. Sin ella el empleado
            // se crea igual, pero queda sin fase de alta y se anota la observación: la antigüedad no
            // se puede calcular y alguien tiene que cargarla a mano.
        }
        field(16; "No Seguridad Social"; Code[30])
        {
            Caption = 'Nº Seguridad Social (CUIL)';
            DataClassification = CustomerContent;
        }
        field(17; "CIF NIF"; Text[20])
        {
            Caption = 'CIF/NIF (CUIL)';
            DataClassification = CustomerContent;
            // La importación de SIRADIG busca el CUIL en los dos campos, así que se sincronizan los
            // dos tal como vengan de NAV en vez de elegir uno.
        }
        field(18; "Fecha Nacimiento"; Date)
        {
            Caption = 'Fecha de Nacimiento';
            DataClassification = CustomerContent;
        }
        field(19; Direccion; Text[100])
        {
            Caption = 'Dirección';
            DataClassification = CustomerContent;
        }
        field(20; "Direccion 2"; Text[50])
        {
            Caption = 'Dirección 2';
            DataClassification = CustomerContent;
        }
        field(21; Ciudad; Text[30])
        {
            Caption = 'Ciudad';
            DataClassification = CustomerContent;
        }
        field(22; "Cod Postal"; Code[20])
        {
            Caption = 'Cód. Postal';
            DataClassification = CustomerContent;
        }
        field(23; Telefono; Text[30])
        {
            Caption = 'Teléfono';
            DataClassification = CustomerContent;
        }
        field(24; Email; Text[80])
        {
            Caption = 'Correo Electrónico';
            DataClassification = CustomerContent;
        }
        field(30; "Convenio Origen"; Text[30])
        {
            Caption = 'Convenio en NAV (referencia)';
            DataClassification = CustomerContent;
            // NO se aplica a la ficha: la codificación de NAV no es la de "Convenio Colectivo".
            // Está para que quien completa el empleado en BC vea qué decía el origen.
        }
        field(31; "Categoria Origen"; Code[10])
        {
            Caption = 'Categoría en NAV (referencia)';
            DataClassification = CustomerContent;
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
        key(PK; "No Empleado") { Clustered = true; }
        key(K2; "Estado Sinc", "No Empleado") { }
    }
}
