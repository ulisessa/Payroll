namespace UAS.Payroll;

using Microsoft.Foundation.Calendar;

// La ficha del calendario base muestra sus días en una sub-página temporal (una fila por fecha, armada
// al abrir) y ese tipo de sub-página no tiene panel de filtros: no se puede buscar una fecha ni un
// rango. La lista estándar "Cambios Calendario Base" sí lo tiene, y trae exactamente lo que importa
// en los calendarios de feriados —las fechas cargadas, con su descripción y si no se labora—, así que
// se la abre desde acá, ya acotada al calendario de la ficha.
pageextension 110033 "Cal. Base Filtrable Ext." extends "Base Calendar Card"
{
    actions
    {
        addlast(Navigation)
        {
            action(FechasConFiltro)
            {
                ApplicationArea = All;
                Caption = 'Fechas (con filtro)';
                Image = Filter;
                ToolTip = 'Abre las fechas cargadas en este calendario en una lista con filtros, para buscar por fecha, descripción o si no se labora. Se puede editar igual que en la ficha.';
                RunObject = page "Base Calendar Changes";
                RunPageLink = "Base Calendar Code" = field(Code);
            }
        }
    }
}
