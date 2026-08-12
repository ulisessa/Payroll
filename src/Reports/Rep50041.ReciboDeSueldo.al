namespace UAS.Payroll;

using Microsoft.Foundation.Company;
using Microsoft.HumanResources.Employee;

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
            column(LiqTipoLiq; TipoLiqDesc) { }
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
                DataItemTableView = SORTING("No. Liquidación", "Nombre Variable") WHERE("Mostrar en Recibo" = CONST(true));

                column(ResNombreVar; ResumenVarLiq."Nombre Variable") { }
                column(ResEtiqueta; ResumenVarLiq.Etiqueta) { }
                column(ResValor; ResumenVarLiq.Valor) { }
                column(ResValorTexto; ResumenVarLiq."Valor Texto") { }
                // Ya resuelto para el RDL: si la variable tiene valor de texto se imprime ése, y si
                // no el número formateado. Una obra social tiene que salir "126205 - OSECAC" y no el
                // 1 con el que la fórmula la distingue.
                column(ResValorMostrar; ResumenVarLiq.ValorParaMostrar()) { }
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
                column(LinBaseCalculo; LinLiq."Base Cálculo") { }
                column(LinImporteHaberRem; LinImporteHaberRem) { }
                column(LinImporteHaberNoRem; LinImporteHaberNoRem) { }
                column(LinGrupo; LinGrupo) { }
                column(LinGrupoOrden; LinGrupoOrden) { }
                column(LinGrupoCosto; Format(LinLiq."Grupo Costo Laboral")) { }
                column(LinGrupoCostoNum; LinLiq."Grupo Costo Laboral".AsInteger()) { }
                column(LinImporteCostoEmpleador; LinImporteContrib) { }
                column(LinImporteCostoTrabajador; LinImporteDescuento) { }
                column(LinEsPrimeraLinea; LinEsPrimeraLinea) { }
                column(LinNetoGrafico; LinNetoGrafico) { }

                trigger OnAfterGetRecord()
                begin
                    // Sin negaciones por tipo: el importe ya viene con su signo, así que un haber que
                    // corrige hacia abajo se imprime negativo en la columna de haberes.
                    case LinLiq."Tipo Concepto" of
                        LinLiq."Tipo Concepto"::"Haber Remunerativo",
                        LinLiq."Tipo Concepto"::"Haber No Remunerativo":
                            LinImporteHaber := LinLiq.Importe;
                        else
                            LinImporteHaber := 0;
                    end;

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

                    LinEsPrimeraLinea := PrimeraLineaLiq and (LinLiq."Grupo Costo Laboral".AsInteger() = 0);
                    if LinEsPrimeraLinea then begin
                        LinNetoGrafico := LiqNetoCosto;
                        PrimeraLineaLiq := false;
                    end else
                        LinNetoGrafico := 0;

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

            column(CostoSindEmpl; vCostoSindEmpl) { }
            column(CostoSindTrab; vCostoSindTrab) { }
            column(CostoSSEmpl; vCostoSSEmpl) { }
            column(CostoSSTrab; vCostoSSTrab) { }
            column(CostoOSEmpl; vCostoOSEmpl) { }
            column(CostoOSTrab; vCostoOSTrab) { }
            column(CostoINSSJPEmpl; vCostoINSSJPEmpl) { }
            column(CostoINSSJPTrab; vCostoINSSJPTrab) { }
            column(CostoARTEmpl; vCostoARTEmpl) { }
            column(CostoARTTrab; vCostoARTTrab) { }
            column(CostoSCVOEmpl; vCostoSCVOEmpl) { }
            column(CostoSCVOTrab; vCostoSCVOTrab) { }

            trigger OnAfterGetRecord()
            var
                Periodo: Record "Período Liquidación";
                Convenio: Record "Convenio Colectivo";
                Categoria: Record "Categoría CCT";
                TipoLiqRec: Record "Tipo Liquidación";
                Emp: Record Employee;
                CostoLin: Record "Línea Liquidación";
                MesNames: array[12] of Text;
                GrupoIdx: Integer;
            begin
                CalcCostoLaboral(Liq."No.");
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

                PrimeraLineaLiq := true;
                LiqNetoCosto := Liq."Neto a Pagar";

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

                TipoLiqDesc := Liq."Cód. Tipo Liq.";
                if TipoLiqRec.Get(Liq."Cód. Tipo Liq.") then
                    TipoLiqDesc := TipoLiqRec.Descripción;

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
        TipoLiqDesc: Text[50];
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
        LinEsPrimeraLinea: Boolean;
        LinNetoGrafico: Decimal;
        PrimeraLineaLiq: Boolean;
        LiqNetoCosto: Decimal;
        PeriodoMes: Integer;
        PeriodoAnio: Integer;
        vCostoSindEmpl: Decimal;
        vCostoSindTrab: Decimal;
        vCostoSSEmpl: Decimal;
        vCostoSSTrab: Decimal;
        vCostoOSEmpl: Decimal;
        vCostoOSTrab: Decimal;
        vCostoINSSJPEmpl: Decimal;
        vCostoINSSJPTrab: Decimal;
        vCostoARTEmpl: Decimal;
        vCostoARTTrab: Decimal;
        vCostoSCVOEmpl: Decimal;
        vCostoSCVOTrab: Decimal;
        EmpAntiguedad: Integer;

    local procedure CalcCostoLaboral(LiqNo: Code[20])
    var
        Lin: Record "Línea Liquidación";
        Idx: Integer;
    begin
        vCostoSindEmpl := 0; vCostoSindTrab := 0;
        vCostoSSEmpl := 0; vCostoSSTrab := 0;
        vCostoOSEmpl := 0; vCostoOSTrab := 0;
        vCostoINSSJPEmpl := 0; vCostoINSSJPTrab := 0;
        vCostoARTEmpl := 0; vCostoARTTrab := 0;
        vCostoSCVOEmpl := 0; vCostoSCVOTrab := 0;

        Lin.SetRange("No. Liquidación", LiqNo);
        Lin.SetFilter("Grupo Costo Laboral", '<>%1', "Grupo Costo Laboral Liq."::" ");
        Lin.SetFilter(Importe, '<>0');
        if not Lin.FindSet() then exit;
        repeat
            Idx := Lin."Grupo Costo Laboral".AsInteger();
            if Lin."Tipo Concepto" = Lin."Tipo Concepto"::"Contribución Patronal" then
                case Idx of
                    1: vCostoSindEmpl += Lin.Importe;
                    2: vCostoSSEmpl += Lin.Importe;
                    3: vCostoOSEmpl += Lin.Importe;
                    4: vCostoINSSJPEmpl += Lin.Importe;
                    5: vCostoARTEmpl += Lin.Importe;
                    6: vCostoSCVOEmpl += Lin.Importe;
                end
            else
                case Idx of
                    1: vCostoSindTrab += Lin.Importe;
                    2: vCostoSSTrab += Lin.Importe;
                    3: vCostoOSTrab += Lin.Importe;
                    4: vCostoINSSJPTrab += Lin.Importe;
                    5: vCostoARTTrab += Lin.Importe;
                    6: vCostoSCVOTrab += Lin.Importe;
                end;
        until Lin.Next() = 0;
    end;
}
