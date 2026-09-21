namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;

/// <summary>
/// Hoja de carga del saldo de francos con el que arranca cada tripulante en el sistema.
/// </summary>
/// <remarks>
/// Los francos que la gente ya tenía ganados antes de la puesta en marcha no están en ninguna
/// liquidación, y el ledger sólo sabe de lo que el motor liquidó. Esta tabla es la carga inicial: se
/// llena a mano o se pega desde Excel, se revisa, y recién entonces se aplica generando los lotes.
///
/// Es una tabla y no un proceso directo a propósito. Cargar saldos escribe en el ledger de francos,
/// que es plata: tener la carga en firme antes de aplicarla permite revisarla de a dos, corregirla
/// sin deshacer nada, y —cuando ya se aplicó— saber exactamente qué se generó y poder revertirlo.
///
/// La fila es (empleado, convenio, categoría, fecha) porque los francos NO son fungibles: cada lote
/// se paga al valor de la categoría en que se ganó. Un tripulante que ascendió necesita dos filas, y
/// la fecha decide el orden FIFO en que se van a consumir.
/// </remarks>
table 110012 "Saldo Inicial Francos Liq."
{
    Caption = 'Saldo Inicial de Francos';
    DataClassification = CustomerContent;
    LookupPageId = "Saldo Inicial de Francos";
    DrillDownPageId = "Saldo Inicial de Francos";

    fields
    {
        field(1; "No. Empleado"; Code[20])
        {
            Caption = 'No. Empleado';
            NotBlank = true;
            DataClassification = EndUserIdentifiableInformation;
            TableRelation = Employee."No.";

            trigger OnValidate()
            var
                Emp: Record Employee;
            begin
                if Emp.Get("No. Empleado") then
                    "Nombre Empleado" := CopyStr(Emp.FullName(), 1, MaxStrLen("Nombre Empleado"));
            end;
        }
        field(2; "Cód. Convenio"; Code[20])
        {
            Caption = 'Convenio';
            NotBlank = true;
            DataClassification = CustomerContent;
            TableRelation = "Convenio Colectivo".Código;
        }
        field(3; "Cód. Categoría"; Code[20])
        {
            Caption = 'Categoría';
            NotBlank = true;
            DataClassification = CustomerContent;
            TableRelation = "Categoría CCT".Código where("Cód. Convenio" = field("Cód. Convenio"));
        }
        field(4; "Fecha Devengo"; Date)
        {
            Caption = 'Fecha de Devengo';
            NotBlank = true;
            DataClassification = CustomerContent;
            // Decide el lugar del lote en la cola FIFO. Dos lotes del mismo tripulante con distinta
            // fecha se consumen del más viejo al más nuevo, así que esta fecha no es decorativa:
            // determina a qué precio se le paga el próximo franco que se tome.
        }
        field(5; Días; Decimal)
        {
            Caption = 'Días';
            DecimalPlaces = 0 : 2;
            DataClassification = CustomerContent;
        }
        field(6; "Nombre Empleado"; Text[100])
        {
            Caption = 'Empleado';
            DataClassification = EndUserIdentifiableInformation;
            Editable = false;
        }
        field(7; Observaciones; Text[250])
        {
            Caption = 'Observaciones';
            DataClassification = CustomerContent;
        }
        field(10; Aplicado; Boolean)
        {
            Caption = 'Aplicado';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(11; "No. Liquidación Generada"; Code[20])
        {
            Caption = 'Liquidación Generada';
            DataClassification = CustomerContent;
            Editable = false;
            TableRelation = "Liquidación"."No.";
        }
        field(12; "No. Línea Generada"; Integer)
        {
            Caption = 'No. Línea Generada';
            DataClassification = CustomerContent;
            Editable = false;
            // Junto con la liquidación, identifica el lote exacto que salió de esta fila. Es lo que
            // hace reversible la carga: sin esto habría que adivinar cuál de los lotes del
            // tripulante generó el proceso y cuál ya estaba.
        }
        field(13; "Valor Franco Estimado"; Decimal)
        {
            Caption = 'Valor del Franco';
            DecimalPlaces = 2 : 2;
            DataClassification = CustomerContent;
            Editable = false;
            // Sólo informativo, para poder revisar la carga antes de aplicarla: el importe real se
            // resuelve recién al consumir el franco, con el VALOR_FRANCO vigente ese día.
        }
    }

    keys
    {
        key(PK; "No. Empleado", "Cód. Convenio", "Cód. Categoría", "Fecha Devengo") { Clustered = true; }
        key(Aplicado; Aplicado, "No. Empleado") { }
        key(Generada; "No. Liquidación Generada") { }
    }

    trigger OnDelete()
    begin
        // Borrar la fila no borra el lote: son dos cosas distintas y la segunda es plata. Hay que
        // revertir primero, que además deja el ledger como estaba.
        if Aplicado then
            Error(ErrAplicado, "No. Empleado");
    end;

    trigger OnModify()
    begin
        if Aplicado then
            Error(ErrAplicado, "No. Empleado");
    end;

    var
        ErrAplicado: Label 'La carga de %1 ya se aplicó y generó un lote de francos. Revertila primero si necesitás corregirla.', Comment = '%1=No. empleado';
}
