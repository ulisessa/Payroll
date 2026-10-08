namespace UAS.Payroll;

/// <summary>
/// Los tramos de días que una liquidación cubre. Un día pertenece a UNA sola liquidación.
/// </summary>
/// <remarks>
/// "Cobertura Desde/Hasta" de la cabecera es UN intervalo, y eso alcanza mientras los días de un
/// tipo sean contiguos: el cierre de marea cubre el viaje, las vacaciones cubren los días de AU9.
/// No alcanza para la Regular, que cubre "todo lo demás": si las vacaciones caen en el medio del
/// mes, lo que le queda son DOS tramos —del 1 al 4 y del 26 al 31— y con un desde/hasta sólo se
/// puede decir "del 1 al 31", que vuelve a pisar los días que ya pagó la otra.
///
/// De ahí esta tabla. La cabecera sigue teniendo su desde/hasta —es el envolvente, y lo que se
/// muestra— pero quien manda para contar días son los tramos.
///
/// SI UNA LIQUIDACIÓN NO TIENE TRAMOS se comporta como siempre: su ventana es el desde/hasta de la
/// cabecera. Así la maquinaria entra sin cambiarle el resultado a nada hasta que la configuración
/// del tipo diga otra cosa.
/// </remarks>
table 110061 "Tramo Cobertura Liq."
{
    Caption = 'Tramos de cobertura';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "No. Liquidación"; Code[20])
        {
            Caption = 'No. Liquidación';
            NotBlank = true;
            DataClassification = CustomerContent;
            TableRelation = "Liquidación"."No.";
        }
        field(2; "No. Línea"; Integer)
        {
            Caption = 'No. Línea';
            DataClassification = CustomerContent;
        }
        field(3; Desde; Date)
        {
            Caption = 'Desde';
            DataClassification = CustomerContent;
        }
        field(4; Hasta; Date)
        {
            Caption = 'Hasta';
            DataClassification = CustomerContent;
        }
        field(5; Días; Integer)
        {
            Caption = 'Días';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(6; Origen; Text[50])
        {
            Caption = 'Origen';
            DataClassification = CustomerContent;
            // De dónde salió el tramo: el estado que lo justifica, la marea, o "resto del período".
            // No lo lee nadie: está para que al mirar por qué una liquidación pagó veinte días y no
            // treinta, la respuesta esté ahí y no haya que reconstruirla.
        }
    }

    keys
    {
        key(PK; "No. Liquidación", "No. Línea") { Clustered = true; }
        key(Fechas; "No. Liquidación", Desde) { }
    }

    trigger OnInsert()
    begin
        Días := Hasta - Desde + 1;
    end;

    trigger OnModify()
    begin
        Días := Hasta - Desde + 1;
    end;
}
