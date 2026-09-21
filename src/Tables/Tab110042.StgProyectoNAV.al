namespace UAS.Payroll;

table 110042 "Stg Proyecto NAV"
{
    Caption = 'Staging Proyecto NAV';
    DataClassification = CustomerContent;
    LookupPageId = "Sinc. Proyectos NAV";
    DrillDownPageId = "Sinc. Proyectos NAV";
    // Espejo de la fila de Job que vino de NAV, ANTES de aplicarse. El script T-SQL escribe acá y
    // nada más que acá: el alta contra Job la hace AL, porque un proyecto no es una fila suelta
    // —arrastra las Default Dimensions de Buque y Marea— y porque cargar la fecha de arribo dispara
    // el cierre de asignaciones en "Proyecto Pesca Ext.".OnModify, que un INSERT por SQL saltearía.
    //
    // Sólo están los campos que la liquidación usa o que identifican la marea. Agregar uno es
    // agregarlo acá, en el MERGE del script y en Aplicar Fila Sinc NAV; los tres lugares y ninguno
    // más. Los FlowFields de Job (kilos descargados, totales DCL) no se traen: no existen en SQL.

    fields
    {
        field(1; "No Proyecto"; Code[20])
        {
            Caption = 'No. Proyecto';
            DataClassification = CustomerContent;
        }
        field(10; Descripcion; Text[100])
        {
            Caption = 'Descripción';
            DataClassification = CustomerContent;
        }
        field(11; "Descripcion 2"; Text[50])
        {
            Caption = 'Descripción 2';
            DataClassification = CustomerContent;
        }
        field(12; "Fecha Inicio"; Date)
        {
            Caption = 'Fecha Inicio';
            DataClassification = CustomerContent;
        }
        field(13; "Fecha Fin"; Date)
        {
            Caption = 'Fecha Fin (arribo)';
            DataClassification = CustomerContent;
            // Cargarla es cerrar la marea. Al aplicarse sobre un Job que la tenía vacía, el OnModify
            // de la extensión cierra las asignaciones de personal del proyecto.
        }
        field(14; Buque; Code[20])
        {
            Caption = 'Buque (Dim. Global 1)';
            DataClassification = CustomerContent;
        }
        field(15; Marea; Code[20])
        {
            Caption = 'Marea (Dim. Global 2)';
            DataClassification = CustomerContent;
        }
        field(16; Estado; Integer)
        {
            Caption = 'Estado en NAV (referencia)';
            DataClassification = CustomerContent;
            // Ordinal crudo de Job.Status en NAV. Se trae para poder mirarlo, pero NO se aplica: en
            // BC el estado del proyecto gobierna el WIP y la registración, y no significa lo mismo
            // que en NAV. Lo que de verdad cierra la marea es "Fecha Fin", y ése sí se aplica.
        }
        field(20; "Tipo Proyecto"; Integer)
        {
            Caption = 'Tipo (ordinal origen)';
            DataClassification = CustomerContent;
            // "Job Ext." campo 50806. Es el que el motor filtra para separar productivo de
            // improductivo (ver Proceso Liq. por Lotes.AplicarFiltroJobs).
        }
        field(21; Patron; Text[50])
        {
            Caption = 'Patrón';
            DataClassification = CustomerContent;
        }
        field(22; "Hora Zarpada"; Time)
        {
            Caption = 'Hora de Zarpada';
            DataClassification = CustomerContent;
        }
        field(23; "Hora Ingreso Puerto"; Time)
        {
            Caption = 'Hora Ingreso a Puerto';
            DataClassification = CustomerContent;
        }
        field(24; "Fecha Llegada Prevista"; Date)
        {
            Caption = 'Fecha Llegada Prevista';
            DataClassification = CustomerContent;
        }
        field(25; "Puerto Zarpada"; Code[10])
        {
            Caption = 'Puerto de Zarpada';
            DataClassification = CustomerContent;
        }
        field(26; "Puerto Descarga"; Code[10])
        {
            Caption = 'Puerto de Descarga';
            DataClassification = CustomerContent;
        }
        field(27; "Anio Marea"; Integer)
        {
            Caption = 'Año de Marea';
            DataClassification = CustomerContent;
        }
        field(28; Actividad; Code[20])
        {
            Caption = 'Actividad (Dim. 3)';
            DataClassification = CustomerContent;
            // LAN = langostino, CAL = calamar. Viene de la dimensión global 2 de NAV, que allá es
            // la actividad; acá va a la dimensión 3, que es donde vive en BC. Las dos puntas usan
            // el número 2 para cosas distintas, y por eso el campo se llama por lo que ES y no por
            // de dónde sale: copiarlo a "Marea" dejaba todos los proyectos con marea LAN o CAL.
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
        key(PK; "No Proyecto") { Clustered = true; }
        key(K2; "Estado Sinc", "No Proyecto") { }
    }
}
