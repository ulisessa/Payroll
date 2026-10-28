namespace UAS.Payroll;

using Microsoft.Foundation.Calendar;

// Mismo acceso desde la lista de calendarios, para llegar a las fechas sin abrir la ficha.
pageextension 110034 "Cal. Base Lista Filtro Ext." extends "Base Calendar List"
{
    actions
    {
        addlast(Navigation)
        {
            action(FechasConFiltroLista)
            {
                ApplicationArea = All;
                Caption = 'Fechas (con filtro)';
                Image = Filter;
                ToolTip = 'Abre las fechas cargadas en el calendario seleccionado, en una lista con filtros.';
                RunObject = page "Base Calendar Changes";
                RunPageLink = "Base Calendar Code" = field(Code);
            }
        }
    }
}
