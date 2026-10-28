namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;

pageextension 50354 "Empleado Relativo Liq. Ext." extends "Employee Relatives"
{
    layout
    {
        addafter("Birth Date")
        {
            field("Tipo Documento"; Rec."Tipo Documento")
            {
                ApplicationArea = All;
                ToolTip = 'Tipo de documento del familiar. Lo completa la importación SIRADIG con el código informado por AFIP.';
            }
            field("Nro. Documento"; Rec."Nro. Documento")
            {
                ApplicationArea = All;
                ToolTip = 'Número de documento del familiar. La importación SIRADIG lo usa para reconocer una carga ya existente y actualizarla en vez de duplicarla.';
            }
            // Campos de tableextension 50673 ("Final Version Customization Extension - Tables Only"),
            // no nuestros. Estos dos son la vigencia del VÍNCULO y no tienen nada que ver con la
            // deducción: están cargados para todo familiar. Lo que decide la deducción de Ganancias
            // es el par "Fecha alta/baja impuesto" de más abajo. Ver Cod50016.
            field("Fecha inicial"; Rec."Fecha inicial")
            {
                ApplicationArea = All;
                ToolTip = 'Fecha de inicio del vínculo familiar. No habilita la deducción de Ganancias: para eso está Fecha alta impuesto.';
            }
            field("Fecha final"; Rec."Fecha final")
            {
                ApplicationArea = All;
                ToolTip = 'Fecha de fin del vínculo familiar. Vacío = vigente. No corta la deducción de Ganancias: para eso está Fecha baja impuesto.';
            }
            field("Cód. Tipo Ded."; Rec."Cód. Tipo Ded.")
            {
                ApplicationArea = All;
                ToolTip = 'Parámetro de deducción de Ganancias 4ta que aplica a este familiar (ej. DED_CONYUGE, DED_HIJO_MENOR). Su Parámetro Vigente aporta el importe anual. Vacío = no genera deducción impositiva.';
            }
            field("Fecha alta impuesto"; Rec."Fecha alta impuesto")
            {
                ApplicationArea = All;
                ToolTip = 'Fecha en que el familiar se declaró como carga A EFECTOS DE GANANCIAS (el F.572 del empleado). Es lo único que habilita la deducción: vacío = nunca se declaró y NO se deduce, por más que el familiar esté cargado y tenga Cód. Tipo Ded.';
            }
            field("Fecha baja impuesto"; Rec."Fecha baja impuesto")
            {
                ApplicationArea = All;
                ToolTip = 'Fecha en que el familiar dejó de ser carga a efectos de Ganancias. Vacío = sigue deduciendo. Es la forma correcta de cortar una deducción sin borrar el familiar de la ficha.';
            }
            field("% Deducción"; Rec."% Deducción")
            {
                ApplicationArea = All;
                ToolTip = 'Porcentaje de la deducción que aplica a este familiar. 100 = deducción completa, 50 = mitad (ej: hijo compartido). ATENCIÓN: cero NO anula la deducción — el motor lo lee como "sin cargar" y aplica el 100%. Para excluir a un familiar, dejá vacío el Cód. Tipo Ded. o cargale la Fecha baja impuesto.';
            }
            // EL TERCER PAR DE FECHAS, y el que faltaba a la vista. Son de la tableextension 50673,
            // no nuestras. En Meta4 son FEC_ALTA_FAM_CARGO y FEC_BAJA_FAM_CARGO, y son las que
            // deciden el adicional de obra social — no las de impuesto ni las del vínculo.
            //
            // Por qué los tres pares siguen separados: un hijo puede dejar de estar a cargo
            // —cumplió la edad— sin dejar de ser hijo. Ahí la baja a cargo se completa y la Fecha
            // final queda vacía. Aplanarlos es exactamente lo que hacía que todo familiar cargado
            // dedujera Ganancias; ver la nota al pie de esta página.
            field("Fecha alta familiar a cargo"; Rec."Fecha alta familiar a cargo")
            {
                ApplicationArea = All;
                ToolTip = 'Desde cuándo el familiar está a cargo del trabajador. Es el par que decide el adicional de obra social, distinto del vínculo (Fecha inicial) y de la deducción de Ganancias (Fecha alta impuesto).';
            }
            field("Fecha baja familiar a cargo"; Rec."Fecha baja familiar a cargo")
            {
                ApplicationArea = All;
                ToolTip = 'Desde cuándo el familiar dejó de estar a cargo. Vacío = sigue a cargo y cuenta para el adicional de obra social. Completarla no termina el vínculo familiar ni corta la deducción de Ganancias: son pares distintos.';
            }
        }
    }

    // Acá vivía "Migrar fechas de familiares", que copiaba las fechas de impuesto a Fecha inicial /
    // Fecha final. Se quitó el 22/9/2026: aplanar los tres pares de fechas en uno es justamente lo
    // que hacía que todo familiar cargado dedujera Ganancias. Ver Cod50082, que quedó vacía.
}
