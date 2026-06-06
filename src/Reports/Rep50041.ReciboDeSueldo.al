namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;
using Microsoft.Foundation.Company;

report 50041 "Recibo de Sueldo"
{
    ApplicationArea = All;
    Caption = 'Recibo de Sueldo';
    UsageCategory = ReportsAndAnalysis;
    DefaultRenderingLayout = RDLCLayoutDecretoV2;
    EnableExternalImages = true;

    dataset
    {
        dataitem(Liq; "Liquidación")
        {
            RequestFilterFields = "No.", "Cód. Período", "No. Empleado", Estado;

            column(LiqNo; Liq."No.") { }
            column(LiqCodPeriodo; Liq."Cód. Período") { }
            column(LiqEmployeeNo; Liq."No. Empleado") { }
            column(LiqEmployeeName; Liq."Nombre Empleado") { }
            column(LiqCodConvenio; Liq."Cód. Convenio") { }
            column(LiqConvenioDesc; ConvenioDesc) { }
            column(LiqCodCategoria; Liq."Cód. Categoría") { }
            column(LiqCategoriaDesc; CategoriaDesc) { }
            column(LiqTipoLiq; Format(Liq."Tipo Liquidación")) { }
            column(LiqNoProyecto; Liq."No. Proyecto") { }
            column(LiqFechaLiq; Format(Liq."Fecha Liquidación", 0, '<Day,2>/<Month,2>/<Year4>')) { }
            column(LiqTotalHaberes; Liq."Total Haberes") { }
            column(LiqTotalDescuentos; Liq."Total Descuentos") { }
            column(LiqTotalContrib; Liq."Total Contribuciones") { }
            column(LiqNeto; Liq."Neto a Pagar") { }
            column(PeriodoDesc; PeriodoDesc) { }
            column(PeriodoFechaDesde; Format(PeriodoFechaDesde, 0, '<Day,2>/<Month,2>/<Year4>')) { }
            column(PeriodoFechaHasta; Format(PeriodoFechaHasta, 0, '<Day,2>/<Month,2>/<Year4>')) { }
            column(CompanyName; CompanyInfo.Name) { }
            column(CompanyAddress; CompanyInfo.Address + ', ' + CompanyInfo.City) { }
            column(CompanyCUIT; CompanyInfo."VAT Registration No.") { }
            column(CompanyLogoPath; CompanyInfo."Logo Path") { }
            column(EmpDomicilio; EmpDomicilio) { }
            column(EmpCUIL; EmpCUIL) { }
            column(EmpFechaIngreso; Format(EmpFechaIngreso, 0, '<Day,2>/<Month,2>/<Year4>')) { }
            column(PeriodoMesNum; PeriodoMes) { }
            column(PeriodoAnioNum; PeriodoAnio) { }
            column(EmpAntiguedad; EmpAntiguedad) { }

            dataitem(ResumenVarLiq; "Resumen Variable Liq.")
            {
                DataItemLink = "No. Liquidación" = FIELD("No.");
                DataItemTableView = SORTING("No. Liquidación", "Nombre Variable");

                column(ResNombreVar; ResumenVarLiq."Nombre Variable") { }
                column(ResEtiqueta; ResumenVarLiq.Etiqueta) { }
                column(ResValor; ResumenVarLiq.Valor) { }
            }

            dataitem(DetGanancias; "Detalle Ganancias Liq.")
            {
                DataItemLink = "No. Liquidación" = FIELD("No.");
                DataItemTableView = SORTING("No. Liquidación", "No. Línea");

                column(DetGanLiqNo; DetGanancias."No. Liquidación") { }
                column(DetGanLineNo; DetGanancias."No. Línea") { }
                column(DetGanEsFamiliar; DetGanancias.Tipo = DetGanancias.Tipo::Familiar) { }
                column(DetGanEsPaso; DetGanancias.Tipo = DetGanancias.Tipo::Paso) { }
                column(DetGanOrden; DetGanancias.Orden) { }
                column(DetGanCodigo; DetGanancias.Código) { }
                column(DetGanDescripcion; DetGanancias.Descripción) { }
                column(DetGanCantidad; DetGanancias.Cantidad) { }
                column(DetGanImpUnit; DetGanancias."Importe Unit. Anual") { }
                column(DetGanImpTotal; DetGanancias."Importe Total") { }
            }

            dataitem(LinLiq; "Línea Liquidación")
            {
                DataItemLink = "No. Liquidación" = FIELD("No.");
                DataItemTableView = SORTING("No. Liquidación", "Orden Cálculo", "No. Línea") WHERE(Importe = FILTER(<> 0), "Imprime en Recibo" = CONST(true));

                column(LinOrden; LinLiq."Orden Cálculo") { }
                column(LinCodConcepto; LinLiq."Cód. Concepto") { }
                column(LinNombre; LinLiq."Nombre Impresión") { }
                column(LinTipoConcepto; LinLiq."Tipo Concepto".AsInteger()) { }
                column(LinTipoConceptoTxt; Format(LinLiq."Tipo Concepto")) { }
                column(LinImporte; LinLiq.Importe) { }
                column(LinEsHaber; LinLiq."Tipo Concepto" in
                    [LinLiq."Tipo Concepto"::"Haber Remunerativo",
                     LinLiq."Tipo Concepto"::"Haber No Remunerativo"])
                { }
                column(LinEsDescuento; LinLiq."Tipo Concepto" in
                    [LinLiq."Tipo Concepto"::"Descuento Empleado",
                     LinLiq."Tipo Concepto"::Retención,
                     LinLiq."Tipo Concepto"::"Seguridad Social"])
                { }
                column(LinEsContrib; LinLiq."Tipo Concepto" =
                    LinLiq."Tipo Concepto"::"Contribución Patronal")
                { }
                column(LinImporteHaber; LinImporteHaber) { }
                column(LinImporteDescuento; LinImporteDescuento) { }
                column(LinImporteContrib; LinImporteContrib) { }
                column(LinCantidad; LinLiq.Cantidad) { }
                column(LinUnidadCantidad; LinLiq."Unidad Cantidad") { }
                column(LinImporteHaberRem; LinImporteHaberRem) { }
                column(LinImporteHaberNoRem; LinImporteHaberNoRem) { }
                column(LinGrupo; LinGrupo) { }
                column(LinGrupoOrden; LinGrupoOrden) { }

                trigger OnAfterGetRecord()
                begin
                    if LinLiq."Tipo Concepto" in
                        [LinLiq."Tipo Concepto"::"Haber Remunerativo",
                         LinLiq."Tipo Concepto"::"Haber No Remunerativo"]
                    then
                        LinImporteHaber := LinLiq.Importe
                    else
                        LinImporteHaber := 0;

                    if LinLiq."Tipo Concepto" in
                        [LinLiq."Tipo Concepto"::"Descuento Empleado",
                         LinLiq."Tipo Concepto"::Retención,
                         LinLiq."Tipo Concepto"::"Seguridad Social"]
                    then
                        LinImporteDescuento := LinLiq.Importe
                    else
                        LinImporteDescuento := 0;

                    if LinLiq."Tipo Concepto" = LinLiq."Tipo Concepto"::"Contribución Patronal" then
                        LinImporteContrib := LinLiq.Importe
                    else
                        LinImporteContrib := 0;

                    if LinLiq."Tipo Concepto" = LinLiq."Tipo Concepto"::"Haber Remunerativo" then
                        LinImporteHaberRem := LinLiq.Importe
                    else
                        LinImporteHaberRem := 0;

                    if LinLiq."Tipo Concepto" = LinLiq."Tipo Concepto"::"Haber No Remunerativo" then
                        LinImporteHaberNoRem := LinLiq.Importe
                    else
                        LinImporteHaberNoRem := 0;

                    case LinLiq."Tipo Concepto" of
                        LinLiq."Tipo Concepto"::"Contribución Patronal":
                            begin
                                LinGrupo := 'Contribuciones Patronales';
                                LinGrupoOrden := 1;
                            end;
                        LinLiq."Tipo Concepto"::"Haber Remunerativo":
                            begin
                                LinGrupo := 'Remunerativo';
                                LinGrupoOrden := 2;
                            end;
                        LinLiq."Tipo Concepto"::"Haber No Remunerativo":
                            begin
                                LinGrupo := 'No Remunerativo';
                                LinGrupoOrden := 3;
                            end;
                        else begin
                            LinGrupo := 'Descuentos';
                            LinGrupoOrden := 4;
                        end;
                    end;
                end;
            }

            trigger OnAfterGetRecord()
            var
                Periodo: Record "Período Liquidación";
                Convenio: Record "Convenio Colectivo";
                Categoria: Record "Categoría CCT";
                Emp: Record Employee;
                MesNames: array[12] of Text;
            begin
                MesNames[1] := 'Enero';
                MesNames[2] := 'Febrero';
                MesNames[3] := 'Marzo';
                MesNames[4] := 'Abril';
                MesNames[5] := 'Mayo';
                MesNames[6] := 'Junio';
                MesNames[7] := 'Julio';
                MesNames[8] := 'Agosto';
                MesNames[9] := 'Septiembre';
                MesNames[10] := 'Octubre';
                MesNames[11] := 'Noviembre';
                MesNames[12] := 'Diciembre';

                if Periodo.Get(Liq."Cód. Período") then begin
                    PeriodoDesc := MesNames[Periodo.Mes] + ' ' + Format(Periodo.Año);
                    PeriodoFechaDesde := Periodo."Fecha Desde";
                    PeriodoFechaHasta := Periodo."Fecha Hasta";
                    PeriodoMes := Periodo.Mes;
                    PeriodoAnio := Periodo.Año;
                end;

                ConvenioDesc := '';
                if Convenio.Get(Liq."Cód. Convenio") then
                    ConvenioDesc := Convenio.Descripción;

                CategoriaDesc := '';
                if Categoria.Get(Liq."Cód. Convenio", Liq."Cód. Categoría") then
                    CategoriaDesc := Categoria.Descripción;

                EmpDomicilio := '';
                EmpCUIL := '';
                EmpFechaIngreso := 0D;
                EmpAntiguedad := 0;
                if Emp.Get(Liq."No. Empleado") then begin
                    EmpDomicilio := Emp.Address + ', ' + Emp.City;
                    EmpCUIL := Emp."Social Security No.";
                    EmpFechaIngreso := Emp."Employment Date";
                    if EmpFechaIngreso <> 0D then
                        EmpAntiguedad := (Liq."Fecha Liquidación" - EmpFechaIngreso) div 365;
                end;
            end;
        }
    }

    requestpage
    {
        layout
        {
            area(Content)
            {
                group(Options)
                {
                    Caption = 'Opciones';
                    field(SoloAprobadas; SoloAprobadas)
                    {
                        ApplicationArea = All;
                        Caption = 'Solo liquidaciones aprobadas/contabilizadas';
                    }
                }
            }
        }
    }

    rendering
    {
        layout(RDLCLayout)
        {
            Type = RDLC;
            LayoutFile = './src/Reports/Rep50041.ReciboDeSueldo.rdl';
            Caption = 'Recibo de Sueldo';
        }
        layout(RDLCLayoutDecretoV2)
        {
            Type = RDLC;
            LayoutFile = './src/Reports/Rep50041.ReciboDeSueldoV2.rdl';
            Caption = 'Recibo de Sueldo (Decreto)';
        }
    }

    trigger OnPreReport()
    begin
        CompanyInfo.Get();
        if SoloAprobadas then
            Liq.SetFilter(Estado, '%1|%2',
                Liq.Estado::Aprobada,
                Liq.Estado::Contabilizada);
    end;

    var
        CompanyInfo: Record "Company Information";
        PeriodoDesc: Text;
        PeriodoFechaDesde: Date;
        PeriodoFechaHasta: Date;
        ConvenioDesc: Text[100];
        CategoriaDesc: Text[100];
        EmpDomicilio: Text[100];
        EmpCUIL: Text[30];
        EmpFechaIngreso: Date;
        SoloAprobadas: Boolean;
        LinImporteHaber: Decimal;
        LinImporteDescuento: Decimal;
        LinImporteContrib: Decimal;
        LinImporteHaberRem: Decimal;
        LinImporteHaberNoRem: Decimal;
        LinGrupo: Text[50];
        LinGrupoOrden: Integer;
        PeriodoMes: Integer;
        PeriodoAnio: Integer;
        EmpAntiguedad: Integer;
}
