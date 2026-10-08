namespace UAS.Payroll;

using Microsoft.Projects.Project.Job;

table 110014 "Lote Franco Buffer Liq."
{
    // Buffer temporal del desglose FIFO de un pago de francos: qué lotes se consumieron, cuántos días
    // se tomó de cada uno, a qué precio y con qué coeficiente.
    //
    // No persiste nada. El desglose se reconstruye llamando a "Gestión Francos", que recorre los lotes
    // en el mismo orden y con la misma exclusión de la liquidación en curso que usó el cálculo, así que
    // lo que se ve acá es lo que se pagó. Tener una tabla real sería peor: habría que mantenerla
    // sincronizada con recálculos, anulaciones y borrados, y quedaría mintiendo en cuanto alguno de
    // esos pasos fallara.
    //
    // Es el detalle que le faltaba al 1063: hasta ahora el importe salía del motor sin que se pudiera
    // ver de dónde, y una diferencia contra el recibo no tenía por dónde empezar a mirarse.

    Caption = 'Lotes de franco consumidos';
    TableType = Temporary;
    Access = Public;

    fields
    {
        field(1; "No. Línea"; Integer)
        {
            Caption = 'No. línea';
            ToolTip = 'Orden en que el FIFO consumió los lotes: el 1 es el más antiguo.';
        }
        field(2; "Fecha Lote"; Date)
        {
            Caption = 'Fecha del lote';
            ToolTip = 'Fecha de la liquidación que devengó estos francos.';
        }
        field(3; "No. Liquidación Origen"; Code[20])
        {
            Caption = 'Liquidación de origen';
            ToolTip = 'Documento donde se devengó el lote. Permite rastrear de qué marea salió.';
        }
        field(4; "No. Proyecto"; Code[20])
        {
            Caption = 'Proyecto (marea)';
            TableRelation = Job;
            ToolTip = 'Marea en la que se devengó el lote. De acá sale la pesquería, y con ella el coeficiente.';
        }
        field(5; "Cód. Convenio"; Code[20])
        {
            Caption = 'Convenio';
            ToolTip = 'Convenio del lote. Los francos NO son fungibles: cada lote se valúa con el convenio y la categoría que tenía el empleado cuando lo devengó.';
        }
        field(6; "Cód. Categoría"; Code[20])
        {
            Caption = 'Categoría';
            ToolTip = 'Categoría del lote, que es la que fija el valor del franco. No es necesariamente la categoría actual del empleado.';
        }
        field(7; "Descripción Categoría"; Text[100])
        {
            Caption = 'Descripción categoría';
        }
        field(8; "Días del Lote"; Decimal)
        {
            Caption = 'Días del lote';
            DecimalPlaces = 0 : 2;
            ToolTip = 'Días que devengó el lote en total, antes de descontar lo ya consumido.';
        }
        field(9; "Días Disponibles"; Decimal)
        {
            Caption = 'Días disponibles';
            DecimalPlaces = 0 : 2;
            ToolTip = 'Lo que quedaba del lote al llegar este pago, después de los consumos anteriores.';
        }
        field(10; "Días Tomados"; Decimal)
        {
            Caption = 'Días tomados';
            DecimalPlaces = 0 : 2;
            ToolTip = 'Días que este pago consumió de este lote.';
        }
        field(11; "Valor Franco"; Decimal)
        {
            Caption = 'Valor del franco';
            AutoFormatType = 2;
            ToolTip = 'Valor por día del lote: parámetro VALOR_FRANCO del convenio y la categoría del lote, vigente a la fecha de pago.';
        }
        field(12; Coeficiente; Decimal)
        {
            Caption = 'Proporción';
            DecimalPlaces = 0 : 4;
            ToolTip = 'Qué proporción del valor pleno de la categoría representa el valor aplicado. 1 = se paga entero; 0,30 = la marinería 729/15 en tangonero. No multiplica nada: el valor ya viene resuelto por la terna.';
        }
        field(15; "Tipo Buque"; Code[10])
        {
            Caption = 'Pesquería';
            ToolTip = 'Pesquería del buque donde se devengó el lote: CAL calamar (potero), LAN langostino (tangonero). Junto con el convenio y la categoría define el valor del franco.';
        }
        field(13; Importe; Decimal)
        {
            Caption = 'Importe';
            AutoFormatType = 1;
            ToolTip = 'Días tomados × valor del franco × coeficiente.';
        }
        field(14; "Cód. Concepto Lote"; Code[20])
        {
            Caption = 'Concepto del lote';
            ToolTip = 'Concepto de devengo que generó el lote.';
        }
    }

    keys
    {
        key(PK; "No. Línea") { Clustered = true; }
    }
}
