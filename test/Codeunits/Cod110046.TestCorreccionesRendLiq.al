namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;
using Microsoft.Projects.Project.Job;

codeunit 110046 "Test Correcciones Rend. Liq."
{
    Subtype = Test;
    TestPermissions = Disabled;

    [Test]
    procedure ComparadorContadorCriterioRecibo()
    var
        Filas: Record "Comp. Meta4 Buffer" temporary;
        Comparador: Page "Comparar BC contra Meta4";
        Total: Integer;
        Diferentes: Integer;
        Bruto: Integer;
        Neto: Integer;
    begin
        PrepararFilasComparador(Filas);
        Comparador.ContarFilas(Filas, Total, Diferentes, Bruto, Neto);
        Assert(Total = 6, 'Deben contarse las seis filas, incluida la ausencia con importes cero.');
        Assert(Diferentes = 3, 'Sólo bruto, descuentos o neto deben contar como diferencia del recibo.');
        Assert(Bruto = 1, 'La diferencia de bruto inferior al centavo no debe redondearse para contar.');
        Assert(Neto = 1, 'Debe reconocerse la fila cuya única diferencia es el neto.');
    end;

    [Test]
    procedure ComparadorContadorVistaYCursor()
    var
        Filas: Record "Comp. Meta4 Buffer" temporary;
        Comparador: Page "Comparar BC contra Meta4";
        Posicion: Text;
        Vista: Text;
        Total: Integer;
        Diferentes: Integer;
        Bruto: Integer;
        Neto: Integer;
    begin
        PrepararFilasComparador(Filas);
        Filas.SetRange(Mes, 4);
        Filas.SetFilter(Diferencia, '<>%1', 0);
        Filas.SetCurrentKey(Diferencia);
        Filas.Ascending(false);
        Assert(Filas.FindFirst(), 'La vista de diferencias en bruto debe tener una fila.');
        Posicion := Filas.GetPosition();
        Vista := Filas.GetView();
        Comparador.ContarFilas(Filas, Total, Diferentes, Bruto, Neto);
        Assert((Total = 1) and (Diferentes = 1) and (Bruto = 1) and (Neto = 0), 'El conteo debe respetar mes y filtro de la vista de bruto.');
        Assert(Filas.GetPosition() = Posicion, 'Contar no debe mover el cursor de la página.');
        Assert(Filas.GetView() = Vista, 'Contar no debe cambiar filtros ni orden de la vista.');
    end;

    [Test]
    procedure ComparadorContadorGruposFiltros()
    var
        Filas: Record "Comp. Meta4 Buffer" temporary;
        Comparador: Page "Comparar BC contra Meta4";
        VistaGrupo: Text;
        Total: Integer;
        Diferentes: Integer;
        Bruto: Integer;
        Neto: Integer;
    begin
        PrepararFilasComparador(Filas);
        Filas.SetRange(Mes, 4);
        Filas.FilterGroup(2);
        Filas.SetFilter("No. Empleado", 'TCONT02|TCONT03|TCONT05');
        Filas.FilterGroup(4);
        Filas.SetRange("Hay Dif. Recibo", true);
        VistaGrupo := Filas.GetView();
        Comparador.ContarFilas(Filas, Total, Diferentes, Bruto, Neto);
        Assert((Total = 2) and (Diferentes = 2) and (Bruto = 1) and (Neto = 1), 'Se deben intersectar los filtros de usuario, vista y enlace.');
        Assert(Filas.FilterGroup() = 4, 'Contar no debe alterar el grupo activo del llamador.');
        Assert(Filas.GetView() = VistaGrupo, 'Contar no debe modificar filtros de otro grupo.');
        Filas.FilterGroup(0);
        Assert(Filas.GetFilter(Mes) <> '', 'Se debe conservar el filtro del usuario.');
    end;

    [Test]
    procedure ComparadorContadorVistaVacia()
    var
        Filas: Record "Comp. Meta4 Buffer" temporary;
        Comparador: Page "Comparar BC contra Meta4";
        Total: Integer;
        Diferentes: Integer;
        Bruto: Integer;
        Neto: Integer;
    begin
        PrepararFilasComparador(Filas);
        Comparador.ContarFilas(Filas, Total, Diferentes, Bruto, Neto);
        Filas.SetRange(Mes, 5);
        Comparador.ContarFilas(Filas, Total, Diferentes, Bruto, Neto);
        Assert((Total = 0) and (Diferentes = 0) and (Bruto = 0) and (Neto = 0), 'Una vista vacía debe limpiar todos los contadores anteriores.');
        Filas.SetRange(Mes);
        Filas.SetRange("Liq. en BC", 0);
        Comparador.ContarFilas(Filas, Total, Diferentes, Bruto, Neto);
        Assert((Total = 1) and (Diferentes = 0), 'Una ausencia en cero es visible, pero no es una diferencia de importes.');
    end;

    [Test]
    procedure ComparadorContadorSoloMarcadas()
    var
        Filas: Record "Comp. Meta4 Buffer" temporary;
        Comparador: Page "Comparar BC contra Meta4";
        Total: Integer;
        Diferentes: Integer;
        Bruto: Integer;
        Neto: Integer;
    begin
        PrepararFilasComparador(Filas);
        Filas.Get('TCONT02', 2026, 4);
        Filas.Mark(true);
        Filas.Get('TCONT05', 2026, 4);
        Filas.Mark(true);
        Filas.MarkedOnly(true);
        Comparador.ContarFilas(Filas, Total, Diferentes, Bruto, Neto);
        Assert((Total = 2) and (Diferentes = 1) and (Bruto = 1) and (Neto = 0), 'El conteo debe respetar el conjunto marcado, sin incluir filas ocultas.');
        Assert(Filas.MarkedOnly(), 'Contar no debe desactivar las marcas del llamador.');
        Filas.MarkedOnly(false);
        Comparador.ContarFilas(Filas, Total, Diferentes, Bruto, Neto);
        Assert((Total = 6) and (Diferentes = 3), 'Al salir del conjunto marcado debe volver a contarse toda la vista.');
    end;

    [Test]
    procedure ComparadorContadorNetoSinOtros()
    var
        Fila: Record "Comp. Meta4 Buffer" temporary;
        Comparador: Page "Comparar BC contra Meta4";
    begin
        Assert(CompanyName() = 'TEST_ORDEN_20261017', 'Las pruebas del comparador sólo se ejecutan en la empresa aislada.');
        Fila."Importe Meta4" := 100;
        Fila."Importe BC" := 100;
        Fila."Descuentos Meta4" := 10;
        Fila."Descuentos BC" := 10;
        Fila."Neto Meta4" := 90;
        Fila."Neto BC" := 89;
        Fila."Contrib. BC" := 20;
        Comparador.ActualizarDiferencias(Fila);
        Assert(Fila."Hay Dif. Recibo", 'El indicador debe usar el neto actual, no el valor anterior de Dif. Neto.');
        Fila."Neto BC" := 90;
        Comparador.ActualizarDiferencias(Fila);
        Assert(not Fila."Hay Dif. Recibo", 'Al cerrar el neto no debe persistir el indicador ni entrar la contribución.');
        Assert((Fila."Importe BC" = 100) and (Fila."Neto BC" = 90) and (Fila."Contrib. BC" = 20), 'Completar el buffer no debe modificar los importes de origen.');
    end;

    local procedure PrepararFilasComparador(var Filas: Record "Comp. Meta4 Buffer" temporary)
    var
        Comparador: Page "Comparar BC contra Meta4";
        Numero: Integer;
    begin
        Assert(CompanyName() = 'TEST_ORDEN_20261017', 'Las pruebas del comparador sólo se ejecutan en la empresa aislada.');
        for Numero := 1 to 6 do begin
            Filas.Init();
            Filas."No. Empleado" := 'TCONT0' + Format(Numero);
            Filas.Año := 2026;
            Filas.Mes := 4;
            Filas."Liq. en BC" := 1;
            Filas."Liq. en Meta4" := 1;
            case Numero of
                2:
                    Filas."Importe BC" := 0.004;
                3:
                    Filas."Neto BC" := -10;
                4:
                    Filas."Descuentos BC" := 10;
                5:
                    Filas."Contrib. BC" := 10;
                6:
                    Filas."Liq. en BC" := 0;
            end;
            Comparador.ActualizarDiferencias(Filas);
            Filas.Insert(false);
        end;
    end;

    /// <summary>Sonda de lectura de documentos existentes; invocar este método, nunca el runner.</summary>
    /// <remarks>
    /// No es un [Test] ni prepara fixtures. Sólo llama Init/LoadParametros/ResolveFuente y lectores
    /// de francos. La repetición controla estabilidad y traza, no es un oráculo independiente.
    /// Matriz sólo materializa un buffer temporary y debe terminar por saldo insuficiente.
    /// </remarks>
    procedure ValidarLectoresPublicados()
    var
        Liquidacion: Record "Liquidación";
        Fuente: Record "Fuente Datos Liquidación";
        Contexto: Codeunit "Contexto Liquidación";
        Cuenta: Codeunit "Cuenta Corriente Francos";
        Documentos: List of [Code[20]];
        Empleados: List of [Code[20]];
        Fuentes: List of [Code[30]];
        Parametros: Dictionary of [Text, Decimal];
        Documento: Code[20];
        NombreFuente: Code[30];
        ExcluirDocumento: Code[20];
        Inspeccionados: Integer;
        ParesSUM: Integer;
        ParesTotal: Integer;
        Trazas: Integer;
        SumasNoCero: Integer;
        Matrices: Integer;
        Variante: Integer;
        SolicitudMatriz: Decimal;
    begin
        Assert(CompanyName() = 'ArbuTest', 'La sonda debe invocarse en la empresa operativa prevista, sin cambiar de empresa.');
        Fuentes.Add('ENF_BASE');
        Fuentes.Add('ENF_BASE_6');
        Fuentes.Add('ENF_BASE_12');
        foreach NombreFuente in Fuentes do
            ValidarConfiguracionSonda(NombreFuente);

        // Selección acotada: como máximo seis empleados distintos y mil cabeceras inspeccionadas.
        Liquidacion.SetCurrentKey("Cód. Período", "No. Empleado");
        Liquidacion.SetRange("Cód. Período", '202601');
        Liquidacion.SetRange(Estado, Liquidacion.Estado::Calculada);
        Liquidacion.SetFilter("No. Empleado", '<>%1', '');
        Liquidacion.SetFilter("Fecha Liquidación", '<>%1', 0D);
        if Liquidacion.FindSet() then
            repeat
                Inspeccionados += 1;
                if not Empleados.Contains(Liquidacion."No. Empleado") then begin
                    Empleados.Add(Liquidacion."No. Empleado");
                    if Cuenta.Activa(Liquidacion."No. Empleado") then
                        Documentos.Add(Liquidacion."No.");
                end;
                if (Documentos.Count() = 6) or (Inspeccionados = 1000) then
                    break;
            until Liquidacion.Next() = 0;
        Assert(Documentos.Count() >= 3, 'No hay suficientes documentos existentes con cuenta de francos activa para la sonda.');

        foreach Documento in Documentos do begin
            Liquidacion.Get(Documento);
            Clear(Contexto);
            Clear(Parametros);
            // La fecha guardada es la referencia usada al calcular; no se recalcula cobertura ni encuadre.
            Contexto.Init(Liquidacion."No. Empleado", Liquidacion."No. Proyecto", Liquidacion."Cód. Período",
                Liquidacion."Fecha Liquidación", Liquidacion."Cód. Convenio", Liquidacion."Cód. Categoría",
                Liquidacion."No.", Liquidacion."Cód. Tipo Liq.", Liquidacion."Cobertura Desde");
            // Las ventanas ENF requieren la selección de parámetros. No llamar BuildContext/MarkEnUso.
            Contexto.LoadParametros(Parametros);
            foreach NombreFuente in Fuentes do begin
                Fuente.Get(NombreFuente);
                ValidarSUMRepetida(Contexto, Fuente, SumasNoCero);
                ParesSUM += 1;
                Trazas += 2;
            end;
            for Variante := 1 to 4 do begin
                ExcluirDocumento := '';
                if Variante > 2 then
                    ExcluirDocumento := Documento;
                ValidarTotalRepetido(Liquidacion, ExcluirDocumento, Variante in [1, 3]);
                ParesTotal += 1;
            end;
            SolicitudMatriz := LimiteSuperiorMatriz(Liquidacion) + 1;
            ValidarMatrizSinSaldo(Liquidacion, Documento, SolicitudMatriz);
            ValidarMatrizSinSaldo(Liquidacion, '', SolicitudMatriz);
            Matrices += 2;
        end;
        Message('Documentos=%1; pares SUM=%2; pares Total=%3; trazas=%4; Matriz=%5; SUM no cero=%6.',
            Documentos.Count(), ParesSUM, ParesTotal, Trazas, Matrices, SumasNoCero);
    end;

    local procedure ValidarConfiguracionSonda(Nombre: Code[30])
    var
        Fuente: Record "Fuente Datos Liquidación";
        Filtro: Record "Filtro Fuente Datos Liq.";
        Linea: Record "Línea Liquidación";
        Ventana: Text;
    begin
        Assert(Fuente.Get(Nombre), 'Falta una fuente requerida por la sonda.');
        Assert(Fuente.Activo and (Fuente."Id. Tabla" = Database::"Línea Liquidación") and
            (Fuente."No. Campo Valor" = Linea.FieldNo(Importe)) and
            (Fuente."Tipo Dato" = Fuente."Tipo Dato"::Decimal) and
            (Fuente."Función Agregado" = Fuente."Función Agregado"::SUM) and
            (Fuente."No. Campo Clave" = 0), 'La configuración de una fuente salió del alcance de la sonda.');
        Filtro.SetRange("Nombre Variable", Nombre);
        Assert(Filtro.Count() = 4, 'Los filtros de una fuente salieron del alcance de la sonda.');
        ValidarFiltroSonda(Nombre, Linea.FieldNo("No. Empleado"), '{EMP_NO}');
        ValidarFiltroSonda(Nombre, Linea.FieldNo("Cód. Concepto"), 'BASE_PROMEDIO|AJ_HIST_AUS');
        ValidarFiltroSonda(Nombre, Linea.FieldNo(Estado), '<>0');
        case Nombre of
            'ENF_BASE':
                Ventana := '{PROM_LIC_DESDE:DIV_PROM_LIC}..{PROM_LIC_HASTA:DIV_PROM_LIC}';
            'ENF_BASE_6':
                Ventana := '{ENF_PROM6_DESDE}..{ENF_PROM_HASTA}';
            'ENF_BASE_12':
                Ventana := '{ENF_PROM12_DESDE}..{ENF_PROM_HASTA}';
        end;
        ValidarFiltroSonda(Nombre, Linea.FieldNo("Fecha Liquidación"), Ventana);
    end;

    local procedure ValidarFiltroSonda(Nombre: Code[30]; Campo: Integer; Esperado: Text)
    var
        Filtro: Record "Filtro Fuente Datos Liq.";
    begin
        Filtro.SetRange("Nombre Variable", Nombre);
        Filtro.SetRange("No. Campo", Campo);
        Assert(Filtro.Count() = 1, 'La sonda requiere un único filtro para cada campo previsto.');
        Filtro.FindFirst();
        Assert(Filtro."Filtro Valor" = Esperado, 'Un filtro cambió respecto del alcance revisado de la sonda.');
    end;

    local procedure ValidarSUMRepetida(var Contexto: Codeunit "Contexto Liquidación"; Fuente: Record "Fuente Datos Liquidación"; var NoCero: Integer)
    var
        Primera: Decimal;
        Segunda: Decimal;
        Antes: Text;
        TrazaPrimera: Text;
        TrazaSegunda: Text;
        EntradaFDS: Text;
        Entrada: Text;
        CoincidenciasFDS: Integer;
    begin
        Antes := Contexto.GetParamLog();
        Primera := Contexto.ResolveFuente(Fuente);
        TrazaPrimera := TrazaAgregadaSonda(Antes, Contexto.GetParamLog());
        Antes := Contexto.GetParamLog();
        Segunda := Contexto.ResolveFuente(Fuente);
        TrazaSegunda := TrazaAgregadaSonda(Antes, Contexto.GetParamLog());
        Assert(Primera = Segunda, 'La lectura SUM cambió entre repeticiones; comprobar también actividad concurrente.');
        Assert(TrazaPrimera = TrazaSegunda, 'La traza SUM cambió entre repeticiones.');
        EntradaFDS := 'FDS:' + Format(Fuente."Id. Tabla") + '/' + Fuente."Nombre Variable";
        foreach Entrada in TrazaPrimera.Split('|') do
            if Entrada = EntradaFDS then
                CoincidenciasFDS += 1;
        Assert(CoincidenciasFDS = 1, 'Cada resolución SUM debe agregar una única referencia FDS de la fuente.');
        if Primera <> 0 then
            NoCero += 1;
    end;

    local procedure TrazaAgregadaSonda(Antes: Text; Despues: Text): Text
    begin
        if Antes = '' then
            exit(Despues);
        Assert(CopyStr(Despues, 1, StrLen(Antes) + 1) = Antes + '|', 'La resolución reemplazó una traza preexistente.');
        exit(CopyStr(Despues, StrLen(Antes) + 2));
    end;

    local procedure ValidarTotalRepetido(Liquidacion: Record "Liquidación"; ExcluirDocumento: Code[20]; Inclusivo: Boolean)
    var
        Cuenta: Codeunit "Cuenta Corriente Francos";
        Primera: Decimal;
        Segunda: Decimal;
    begin
        Primera := Cuenta.Total(Liquidacion."No. Empleado", "Rol Franco Liq."::Devengo,
            ExcluirDocumento, Liquidacion."Fecha Liquidación", Inclusivo);
        Segunda := Cuenta.Total(Liquidacion."No. Empleado", "Rol Franco Liq."::Devengo,
            ExcluirDocumento, Liquidacion."Fecha Liquidación", Inclusivo);
        Assert(Primera = Segunda, 'El total de francos cambió entre repeticiones; comprobar también actividad concurrente.');
    end;

    local procedure LimiteSuperiorMatriz(Liquidacion: Record "Liquidación") Limite: Decimal
    var
        Movimiento: Record "Movimiento Franco Liq.";
        Linea: Record "Línea Liquidación";
        Cuenta: Codeunit "Cuenta Corriente Francos";
        Saldo: Decimal;
    begin
        // Sobrecuenta deliberadamente: cualquier saldo y línea positiva, sin descontar duplicados.
        // Pedir más que este límite fuerza la lectura de líneas incluso si hay lotes disponibles.
        Movimiento.SetRange("No. Empleado", Liquidacion."No. Empleado");
        Movimiento.SetRange(Tipo, Movimiento.Tipo::Devengo);
        Movimiento.SetRange("Fecha Devengamiento", 0D, Liquidacion."Fecha Liquidación");
        if Movimiento.FindSet() then
            repeat
                Saldo := Cuenta.SaldoLote(Movimiento."No. Lote", Liquidacion."Fecha Liquidación");
                if Saldo > 0 then
                    Limite += Saldo;
            until Movimiento.Next() = 0;
        Linea.SetLoadFields(Cantidad);
        Linea.SetRange("No. Empleado", Liquidacion."No. Empleado");
        Linea.SetRange(Estado, Linea.Estado::Calculada);
        Linea.SetFilter("Fecha Liquidación", '<=%1', Liquidacion."Fecha Liquidación");
        if Linea.FindSet() then
            repeat
                if Linea.Cantidad > 0 then
                    Limite += Linea.Cantidad;
            until Linea.Next() = 0;
    end;

    local procedure ValidarMatrizSinSaldo(Liquidacion: Record "Liquidación"; Documento: Code[20]; Solicitud: Decimal)
    var
        ErrorMatriz: Text;
    begin
        ClearLastError();
        if LeerMatrizHastaAgotar(Liquidacion."No. Empleado", Liquidacion."Fecha Liquidación", Documento, Solicitud) then
            Error('La sonda no alcanzó el saldo insuficiente previsto; comprobar actividad concurrente.');
        ErrorMatriz := GetLastErrorText();
        // No mostrar cantidades ni identificadores. Cualquier otro error invalida la sonda.
        Assert(ErrorMatriz.StartsWith('La matriz pide ') and ErrorMatriz.Contains(' días de franco y faltan '),
            'La lectura Matriz falló con un error inesperado; la sonda se detuvo.');
        ClearLastError();
    end;

    [TryFunction]
    local procedure LeerMatrizHastaAgotar(Empleado: Code[20]; Fecha: Date; Documento: Code[20]; Solicitud: Decimal)
    var
        Cuenta: Codeunit "Cuenta Corriente Francos";
        Filas: Record "Lote Franco Buffer Liq." temporary;
    begin
        Cuenta.Matriz(Empleado, Fecha, Documento, Solicitud, true, Filas);
    end;

    [Test]
    procedure NetoPropioSuperaGarantizado()
    var
        Motor: Codeunit "Motor Liquidación";
    begin
        Assert(Motor.NetoGarantizadoSatisfecho(100, 120, 0), 'El neto propio superior al piso debe aceptarse.');
        Assert(not Motor.NetoGarantizadoSatisfecho(100, 120, 20), 'Un exceso con complemento debe seguir ajustándose.');
        Assert(not Motor.NetoGarantizadoSatisfecho(100, 80, 0), 'Un neto inferior al piso necesita complemento.');
        Assert(not Motor.NetoGarantizadoSatisfecho(100, 80, 10), 'No debe aceptarse una iteración que todavía paga de menos.');
    end;

    [Test]
    procedure ToleranciaDeUnPesoYVeinteIteraciones()
    var
        Motor: Codeunit "Motor Liquidación";
    begin
        Assert(Motor.MaxIteracionesGrossingUp() = 20, 'El límite debe ser veinte iteraciones.');
        Assert(Motor.NetoGarantizadoSatisfecho(100, 100, 10), 'Igualdad exacta.');
        Assert(Motor.NetoGarantizadoSatisfecho(100, 99, 10), 'Un peso por debajo se acepta.');
        Assert(Motor.NetoGarantizadoSatisfecho(100, 101, 10), 'Un peso por encima se acepta.');
        Assert(not Motor.NetoGarantizadoSatisfecho(100, 98.9999, 10), 'Más de un peso por debajo requiere ajuste.');
        Assert(not Motor.NetoGarantizadoSatisfecho(100, 101.0001, 10), 'Más de un peso por encima con complemento requiere ajuste.');
        Assert(Motor.NetoGarantizadoSatisfecho(15706500, 15706499.9736, 1), 'El caso LIQ-00009346 está dentro de la tolerancia.');
    end;
    [Test]
    procedure FiltroConApostrofesYOperadores()
    var
        Francos: Codeunit "Gestión Francos";
        Lin: Record "Línea Liquidación" temporary;
        Codigos: List of [Code[20]];
        Codigo: Code[20];
        Numero: Integer;
        Seleccionados: Text;
    begin
        Codigos.Add('FR''01');
        Codigos.Add('A|B');
        Codigos.Add('A&B');
        Codigos.Add('F*');
        Codigos.Add('F?');
        Codigos.Add('A..Z');
        Codigos.Add('@FR');
        Codigos.Add('A(B)');
        Codigos.Add('A=B');
        Codigos.Add('A<B');
        Codigos.Add('A>B');
        Codigos.Add('<FR');
        Codigos.Add('>FR');
        Codigos.Add('A%1');
        foreach Codigo in Codigos do begin
            Numero += 1;
            InsertarLinea(Lin, Numero, Codigo);
        end;
        InsertarLinea(Lin, 100, 'A');
        InsertarLinea(Lin, 101, 'B');
        InsertarLinea(Lin, 102, 'FR02');
        InsertarLinea(Lin, 103, 'FR');
        InsertarLinea(Lin, 104, 'F1');
        InsertarLinea(Lin, 105, 'F12');
        InsertarLinea(Lin, 106, 'AZ');
        InsertarLinea(Lin, 107, 'FR01');
        InsertarLinea(Lin, 108, 'AAB');
        Francos.FiltrarCodigos(Lin, Codigos);
        if Lin.FindSet() then
            repeat
                if Seleccionados <> '' then
                    Seleccionados += '; ';
                Seleccionados += '[' + Lin."Cód. Concepto" + ']';
            until Lin.Next() = 0;
        Assert(Lin.Count() = Codigos.Count(), StrSubstNo(
            'El filtro debe seleccionar exactamente los códigos literales. Esperados=%1; encontrados=%2; filtro=%3; seleccionados=%4.',
            Codigos.Count(), Lin.Count(), Lin.GetFilter("Cód. Concepto"), Seleccionados));
        if Lin.FindSet() then
            repeat
                Assert(Codigos.Contains(Lin."Cód. Concepto"), 'El filtro incluyó un código ajeno.');
            until Lin.Next() = 0;
    end;

    [Test]
    procedure FiltroVacioNoIncluyeBlancosNiMarcasAnteriores()
    var
        Francos: Codeunit "Gestión Francos";
        Lin: Record "Línea Liquidación" temporary;
        Codigos: List of [Code[20]];
    begin
        InsertarLinea(Lin, 1, '');
        InsertarLinea(Lin, 2, '1062');
        InsertarLinea(Lin, 3, 'F*');
        Assert(Lin.FindFirst(), 'La fixture debe tener filas antes de aplicar la lista vacía.');
        Lin.Mark(true);
        Lin.MarkedOnly(true);
        Francos.FiltrarCodigos(Lin, Codigos);
        Assert(Lin.IsEmpty(), 'Una lista vacía debe seleccionar cero filas, incluso existiendo concepto blanco o marcas previas.');
        Lin.SetFilter("No. Línea", '>0');
        Assert(Lin.IsEmpty(), 'Agregar otro filtro no debe ensanchar una selección vacía.');

        Codigos.Add('F*');
        Francos.FiltrarCodigos(Lin, Codigos);
        Assert(Lin.Count() = 1, 'La misma variable debe poder pasar de vacío a selección literal especial.');
        Assert(Lin.FindFirst(), 'Debe encontrarse el código literal especial.');
        Assert(Lin."Cód. Concepto" = 'F*', 'No debe sobrevivir la marca previa del concepto blanco.');
        Clear(Codigos);
        Codigos.Add('1062');
        Francos.FiltrarCodigos(Lin, Codigos);
        Assert(Lin.Count() = 1, 'La ruta numérica debe reemplazar la selección marcada anterior.');
        Assert(Lin.FindFirst(), 'Debe encontrarse el código numérico.');
        Assert(Lin."Cód. Concepto" = '1062', 'La selección numérica no debe conservar el concepto especial anterior.');
        Clear(Codigos);
        Francos.FiltrarCodigos(Lin, Codigos);
        Assert(Lin.IsEmpty(), 'Volver a vacío debe retirar también el OR numérico anterior.');
    end;

    [Test]
    procedure FiltroDuplicadosYMezclaNoEnsanchanSeleccion()
    var
        Francos: Codeunit "Gestión Francos";
        Lin: Record "Línea Liquidación" temporary;
        Codigos: List of [Code[20]];
    begin
        InsertarLinea(Lin, 1, '1062');
        InsertarLinea(Lin, 2, 'F*');
        InsertarLinea(Lin, 3, 'FR02');
        InsertarLinea(Lin, 4, '@FR');
        InsertarLinea(Lin, 5, 'FR');
        Codigos.Add('1062');
        Codigos.Add('1062');
        Francos.FiltrarCodigos(Lin, Codigos);
        Assert(Lin.Count() = 1, 'Repetir un código numérico no duplica ni ensancha el conjunto.');
        Clear(Codigos);
        Codigos.Add('F*');
        Codigos.Add('F*');
        Francos.FiltrarCodigos(Lin, Codigos);
        Assert(Lin.Count() = 1, 'Repetir un código especial no puede convertirlo en patrón.');
        Assert(Lin.FindFirst(), 'La selección debe contener el literal repetido.');
        Assert(Lin."Cód. Concepto" = 'F*', 'El asterisco literal no puede arrastrar FR ni FR02.');
        Clear(Codigos);
        Codigos.Add('1062');
        Codigos.Add('@FR');
        Francos.FiltrarCodigos(Lin, Codigos);
        Assert(Lin.Count() = 2, 'Una lista mixta debe seleccionar exactamente dos códigos.');
        Assert(Lin.FindSet(), 'La selección mixta no debe quedar vacía por las marcas anteriores.');
        repeat
            Assert(Codigos.Contains(Lin."Cód. Concepto"), 'La selección mixta incluyó una fila ajena.');
        until Lin.Next() = 0;
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure FiltroPersistenteConservaAmbitoGruposYOrden()
    var
        Francos: Codeunit "Gestión Francos";
        Lin: Record "Línea Liquidación";
        Codigos: List of [Code[20]];
        Documento: Code[20];
        OtroDocumento: Code[20];
        Empleado: Code[20];
        OtroEmpleado: Code[20];
        Empresa: Text;
        Clave: Text;
        Total: Decimal;
    begin
        Empresa := CompanyName();
        Assert(Empresa.StartsWith('TEST_'), 'Las fixtures persistentes de filtro requieren una empresa aislada TEST_.');
        Documento := CodigoPrueba();
        OtroDocumento := CodigoPrueba();
        Empleado := CodigoPrueba();
        OtroEmpleado := CodigoPrueba();
        InsertarLineaFiltro(Documento, 1, Empleado, DMY2Date(10, 1, 2026), Lin.Estado::Calculada, 'F*');
        InsertarLineaFiltro(Documento, 2, Empleado, DMY2Date(20, 1, 2026), Lin.Estado::Calculada, '1062');
        InsertarLineaFiltro(Documento, 3, OtroEmpleado, DMY2Date(15, 1, 2026), Lin.Estado::Calculada, 'F*');
        InsertarLineaFiltro(Documento, 4, Empleado, DMY2Date(1, 2, 2026), Lin.Estado::Calculada, 'F*');
        InsertarLineaFiltro(Documento, 5, Empleado, DMY2Date(15, 1, 2026), Lin.Estado::Aprobada, 'F*');
        InsertarLineaFiltro(Documento, 6, Empleado, DMY2Date(15, 1, 2026), Lin.Estado::Calculada, 'FR02');
        InsertarLineaFiltro(OtroDocumento, 7, Empleado, DMY2Date(25, 1, 2026), Lin.Estado::Calculada, 'F*');
        Lin.SetCurrentKey("No. Empleado", "Fecha Liquidación", "Tipo Concepto");
        Lin.Ascending(false);
        Clave := Lin.CurrentKey();
        Lin.SetRange("No. Liquidación", Documento);
        Lin.SetRange("Fecha Liquidación", DMY2Date(1, 1, 2026), DMY2Date(31, 1, 2026));
        Lin.FilterGroup(2);
        Lin.SetRange("No. Empleado", Empleado);
        Lin.FilterGroup(10);
        Lin.SetRange(Estado, Lin.Estado::Calculada);
        Lin.SetLoadFields(Cantidad);
        Codigos.Add('F*');
        Codigos.Add('1062');
        Francos.FiltrarCodigos(Lin, Codigos);
        Assert(Lin.FilterGroup() = 10, 'El helper debe devolver el grupo que estaba activo.');
        Assert(Lin.GetFilter(Estado) <> '', 'Debe conservar el filtro de estado del grupo10.');
        Lin.FilterGroup(2);
        Assert(Lin.GetFilter("No. Empleado") = Empleado, 'Debe conservar el filtro de empleado del grupo2.');
        Lin.FilterGroup(0);
        Assert(Lin.GetFilter("No. Liquidación") = Documento, 'Debe conservar la liquidación explícita.');
        Assert(Lin.GetFilter("Fecha Liquidación") <> '', 'Debe conservar el rango de fecha.');
        Assert((Lin.CurrentKey() = Clave) and not Lin.Ascending(), 'Debe conservar clave y recorrido descendente usados por FIFO.');
        Assert(Lin.Count() = 2, 'Empleado, fecha, estado, documento y códigos deben seguir restringiendo conjuntamente.');
        Assert(Lin.FindSet(), 'Deben encontrarse las dos filas válidas persistidas.');
        Assert(Lin."No. Línea" = 2, 'El filtro no puede alterar el orden descendente de fechas.');
        repeat
            Assert(Codigos.Contains(Lin."Cód. Concepto"), 'El conjunto persistente incluyó un código ajeno.');
            Total += Lin.Cantidad;
        until Lin.Next() = 0;
        Assert(Total = 3, 'La suma debe contener sólo las cantidades1+2, sin filas de otro estado, empleado, fecha o documento.');
    end;

    local procedure InsertarLineaFiltro(Documento: Code[20]; Numero: Integer; Empleado: Code[20]; Fecha: Date; Estado: Enum "Estado Liq."; Codigo: Code[20])
    var
        Lin: Record "Línea Liquidación";
    begin
        Lin."No. Liquidación" := Documento;
        Lin."No. Línea" := Numero;
        Lin."No. Empleado" := Empleado;
        Lin."Fecha Liquidación" := Fecha;
        Lin.Estado := Estado;
        Lin."Cód. Concepto" := Codigo;
        Lin.Cantidad := Numero;
        Lin.Insert(false);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure FuenteSUMConservaImportesFiltrosYTraza()
    var
        Contexto: Codeunit "Contexto Liquidación";
        Fuente: Record "Fuente Datos Liquidación";
        Linea: Record "Línea Liquidación";
        Empleado: Code[20];
        Documento: Code[20];
        Esperado: Decimal;
        Entrada: Text;
    begin
        Empleado := CodigoPrueba();
        Documento := CodigoPrueba();
        InsertarLineaSUM(Documento, 1, Empleado, DMY2Date(10, 1, 2026), 100.125, "Estado Liq."::Calculada);
        InsertarLineaSUM(Documento, 2, Empleado, DMY2Date(20, 1, 2026), -25.375, "Estado Liq."::Aprobada);
        InsertarLineaSUM(Documento, 3, Empleado, DMY2Date(20, 1, 2026), 999, "Estado Liq."::Borrador);
        InsertarLineaSUM(Documento, 4, CodigoPrueba(), DMY2Date(20, 1, 2026), 888, "Estado Liq."::Calculada);
        InsertarLineaSUM(Documento, 5, Empleado, DMY2Date(1, 2, 2026), 777, "Estado Liq."::Calculada);
        Fuente."Nombre Variable" := CodigoPrueba();
        Fuente."Id. Tabla" := Database::"Línea Liquidación";
        Fuente."No. Campo Valor" := Linea.FieldNo(Importe);
        Fuente."Función Agregado" := Fuente."Función Agregado"::SUM;
        FiltroSUM(Fuente."Nombre Variable", Linea.FieldNo("No. Empleado"), '{EMP_NO}');
        FiltroSUM(Fuente."Nombre Variable", Linea.FieldNo("Fecha Liquidación"), '..{FECHA_REF}');
        FiltroSUM(Fuente."Nombre Variable", Linea.FieldNo(Estado), '<>0');
        Contexto.Init(Empleado, '', '', DMY2Date(31, 1, 2026), '', '', '', '', DMY2Date(1, 1, 2026));
        Linea.SetRange("No. Empleado", Empleado);
        Linea.SetFilter("Fecha Liquidación", '<=%1', DMY2Date(31, 1, 2026));
        Linea.SetFilter(Estado, '<>%1', Linea.Estado::Borrador);
        Linea.CalcSums(Importe);
        Esperado := Linea.Importe;
        Assert(Esperado = 74.75, 'La referencia debe sumar sólo las dos líneas válidas, conservando sus decimales y signos.');
        Assert(Contexto.ResolveFuente(Fuente) = Esperado, 'SUM debe coincidir con CalcSums bajo los mismos filtros.');
        Entrada := 'FDS:' + Format(Database::"Línea Liquidación") + '/' + Fuente."Nombre Variable";
        Assert(Contexto.GetParamLog() = Entrada, 'La lectura parcial debe conservar la referencia FDS.');
        Assert(Contexto.ResolveFuente(Fuente) = Esperado, 'Resolver otra vez no debe modificar el resultado.');
        Assert(Contexto.GetParamLog() = Entrada + '|' + Entrada, 'Cada resolución debe seguir agregando su propia traza.');
        Linea.CalcSums(Importe);
        Assert(Linea.Importe = Esperado, 'Resolver la fuente no debe modificar los importes leídos.');

        Contexto.Init(CodigoPrueba(), '', '', DMY2Date(31, 1, 2026), '', '', '', '', DMY2Date(1, 1, 2026));
        Assert(Contexto.ResolveFuente(Fuente) = 0, 'Una fuente sin filas debe devolver cero.');
        Assert(Contexto.GetParamLog() = Entrada, 'La fuente vacía también debe conservar la traza de resolución.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure FuenteSUMRespetaAliasDeFechasFamiliares()
    var
        Contexto: Codeunit "Contexto Liquidación";
        Fuente: Record "Fuente Datos Liquidación";
        Familiar: Record "Employee Relative";
        Empleado: Code[20];
        Entrada: Text;
    begin
        Empleado := CodigoPrueba();
        // Los campos obsoletos contienen las fechas opuestas: sólo el alias canónico elige la fila de 25.
        InsertarFamiliarSUM(Empleado, 1, DMY2Date(1, 1, 2026), DMY2Date(31, 1, 2026),
            DMY2Date(1, 2, 2026), DMY2Date(28, 2, 2026), 25);
        InsertarFamiliarSUM(Empleado, 2, DMY2Date(1, 2, 2026), DMY2Date(28, 2, 2026),
            DMY2Date(1, 1, 2026), DMY2Date(31, 1, 2026), 75);
        Fuente."Nombre Variable" := CodigoPrueba();
        Fuente."Id. Tabla" := Database::"Employee Relative";
        Fuente."No. Campo Valor" := Familiar.FieldNo("% Deducción");
        Fuente."Función Agregado" := Fuente."Función Agregado"::SUM;
        FiltroSUM(Fuente."Nombre Variable", Familiar.FieldNo("Employee No."), '{EMP_NO}');
        FiltroSUM(Fuente."Nombre Variable", 50211, '..{FECHA_REF}');
        FiltroSUM(Fuente."Nombre Variable", 50212, '..{FECHA_REF}');
        Contexto.Init(Empleado, '', '', DMY2Date(31, 1, 2026), '', '', '', '', DMY2Date(1, 1, 2026));
        Assert(Contexto.ResolveFuente(Fuente) = 25, 'Los filtros 50211/50212 deben usar las fechas de impuesto 50008/50009.');
        Entrada := 'FDS:' + Format(Database::"Employee Relative") + '/' + Fuente."Nombre Variable";
        Assert(Contexto.GetParamLog() = Entrada, 'La canonización no cambia la identidad de la fuente en la traza.');
        // Como campo de valor, el alias conserva la conversión histórica de Date a cero numérico.
        Fuente."No. Campo Valor" := 50211;
        Assert(Contexto.ResolveFuente(Fuente) = 0, 'El alias de ingreso usado como valor debe conservar su conversión numérica.');
        Fuente."No. Campo Valor" := 50212;
        Assert(Contexto.ResolveFuente(Fuente) = 0, 'El alias de egreso usado como valor debe conservar su conversión numérica.');
        Assert(Contexto.GetParamLog() = Entrada + '|' + Entrada + '|' + Entrada,
            'Los campos de valor canónicos no deben suprimir las trazas de las dos llamadas.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure FuenteSUMConservaFlowFieldYValorNoConfigurado()
    var
        Contexto: Codeunit "Contexto Liquidación";
        Fuente: Record "Fuente Datos Liquidación";
        Clase: Record "Clase Entidad Liq.";
        Atributo: Record "Tipo Atributo Liq.";
        Filtro: Record "Filtro Fuente Datos Liq.";
        Referencia: RecordRef;
        Campo: FieldRef;
        Esperado: Integer;
        Entrada: Text;
    begin
        Clase.Código := CodigoPrueba();
        Clase.Insert(false);
        Atributo.Código := CodigoPrueba();
        Atributo."Cód. Clase" := Clase.Código;
        Atributo.Insert(false);
        Clase.CalcFields("Cant. Atributos");
        Assert(Clase."Cant. Atributos" = 1, 'La fixture debe contener un FlowField calculable y no vacío.');
        Fuente."Nombre Variable" := CodigoPrueba();
        Fuente."Id. Tabla" := Database::"Clase Entidad Liq.";
        Fuente."No. Campo Valor" := Clase.FieldNo("Cant. Atributos");
        Fuente."Función Agregado" := Fuente."Función Agregado"::SUM;
        FiltroSUM(Fuente."Nombre Variable", Clase.FieldNo(Código), Clase.Código);
        // ResolveFuente exige un contexto fechado aun cuando este filtro sea constante.
        Contexto.Init('', '', '', DMY2Date(31, 1, 2026), '', '', '', '', DMY2Date(1, 1, 2026));
        // Referencia: lectura completa original, sin introducir CalcFields en el comportamiento de SUM.
        Referencia.Open(Database::"Clase Entidad Liq.");
        Campo := Referencia.Field(Clase.FieldNo(Código));
        Campo.SetRange(Clase.Código);
        Referencia.FindFirst();
        Campo := Referencia.Field(Clase.FieldNo("Cant. Atributos"));
        Esperado := Campo.Value();
        Referencia.Close();
        Assert(Contexto.ResolveFuente(Fuente) = Esperado,
            'Una fuente sobre FlowField debe conservar la lectura anterior sin rechazar el campo por SetLoadFields.');
        Fuente."No. Campo Valor" := 0;
        Assert(Contexto.ResolveFuente(Fuente) = 0, 'La fuente sin campo de valor debe seguir devolviendo cero.');
        Fuente."No. Campo Valor" := 999999;
        Filtro.SetRange("Nombre Variable", Fuente."Nombre Variable");
        Filtro.SetRange("No. Campo", Clase.FieldNo(Código));
        Assert(Filtro.Count() = 1, 'La fixture debe contener un único filtro del código de clase.');
        Filtro.FindFirst();
        Filtro."Filtro Valor" := CodigoPrueba();
        Filtro.Modify(false);
        Assert(Contexto.ResolveFuente(Fuente) = 0,
            'Con un conjunto vacío no debe adelantarse el error de un campo inexistente que nunca llega a leerse.');
        Entrada := 'FDS:' + Format(Database::"Clase Entidad Liq.") + '/' + Fuente."Nombre Variable";
        Assert(Contexto.GetParamLog() = Entrada + '|' + Entrada + '|' + Entrada,
            'El FlowField, el valor no configurado y el conjunto vacío deben conservar sus trazas.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure SeleccionNoJustificaBajaAnteriorAlReingreso()
    var
        Proceso: Codeunit "Proceso Liq. Por Lote";
        Empleado: Code[20];
        Periodo: Code[10];
        Tipo: Code[20];
        Proyecto: Code[20];
    begin
        PrepararSeleccionFase(Empleado, Periodo, Tipo, Proyecto);
        InsertarFaseSeleccion(Empleado, 1, DMY2Date(29, 1, 2026), 0D);
        InsertarEstadoSeleccion(Empleado, 'BAJ-1', DMY2Date(6, 11, 2025), DMY2Date(28, 1, 2026), '');
        InsertarEstadoSeleccion(Empleado, 'PS', DMY2Date(29, 1, 2026), DMY2Date(30, 1, 2026), Proyecto);
        InsertarEstadoSeleccion(Empleado, 'NV', DMY2Date(31, 1, 2026), 0D, Proyecto);
        Assert(not Proceso.EstadosJustifican(Empleado, Periodo, Tipo, ''),
            'La baja anterior al alta no puede justificar una Regular: los únicos días activos son de marea.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure SeleccionBajaAbiertaUsaFinEfectivo()
    var
        Proceso: Codeunit "Proceso Liq. Por Lote";
        Empleado: Code[20];
        Periodo: Code[10];
        Tipo: Code[20];
        Proyecto: Code[20];
    begin
        PrepararSeleccionFase(Empleado, Periodo, Tipo, Proyecto);
        InsertarFaseSeleccion(Empleado, 1, DMY2Date(24, 1, 2026), 0D);
        // El fin sin materializar deriva del siguiente estado, no del fin de enero.
        InsertarEstadoSeleccion(Empleado, 'BAJ-1', DMY2Date(17, 10, 2024), 0D, '');
        InsertarEstadoSeleccion(Empleado, 'PS', DMY2Date(24, 1, 2026), DMY2Date(25, 1, 2026), Proyecto);
        InsertarEstadoSeleccion(Empleado, 'NV', DMY2Date(26, 1, 2026), 0D, Proyecto);
        Assert(not Proceso.EstadosJustifican(Empleado, Periodo, Tipo, ''),
            'Una fecha fin vacía anterior al reingreso debe usar el fin efectivo del estado.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure SeleccionConservaPuertoActivoTrasReingreso()
    var
        Proceso: Codeunit "Proceso Liq. Por Lote";
        Empleado: Code[20];
        Periodo: Code[10];
        Tipo: Code[20];
        Proyecto: Code[20];
    begin
        PrepararSeleccionFase(Empleado, Periodo, Tipo, Proyecto);
        InsertarFaseSeleccion(Empleado, 1, DMY2Date(24, 1, 2026), 0D);
        InsertarEstadoSeleccion(Empleado, 'BAJ-1', DMY2Date(1, 1, 2026), DMY2Date(23, 1, 2026), '');
        InsertarEstadoSeleccion(Empleado, 'GP', DMY2Date(24, 1, 2026), DMY2Date(25, 1, 2026), '');
        InsertarEstadoSeleccion(Empleado, 'NV', DMY2Date(26, 1, 2026), 0D, Proyecto);
        Assert(Proceso.EstadosJustifican(Empleado, Periodo, Tipo, ''),
            'Los días activos de guardia fuera de la marea siguen justificando la Regular del reingresado.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure SeleccionSinFasesConservaFallback()
    var
        Proceso: Codeunit "Proceso Liq. Por Lote";
        Empleado: Code[20];
        Periodo: Code[10];
        Tipo: Code[20];
        Proyecto: Code[20];
    begin
        PrepararSeleccionFase(Empleado, Periodo, Tipo, Proyecto);
        InsertarEstadoSeleccion(Empleado, 'GP', DMY2Date(1, 1, 2026), 0D, '');
        Assert(Proceso.EstadosJustifican(Empleado, Periodo, Tipo, ''),
            'La ausencia de fases modeladas conserva el criterio permisivo existente.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure SeleccionEstadoEnHuecoEntreFasesNoJustifica()
    var
        Proceso: Codeunit "Proceso Liq. Por Lote";
        Empleado: Code[20];
        Periodo: Code[10];
        Tipo: Code[20];
        Proyecto: Code[20];
    begin
        PrepararSeleccionFase(Empleado, Periodo, Tipo, Proyecto);
        InsertarFaseSeleccion(Empleado, 1, DMY2Date(1, 1, 2026), DMY2Date(2, 1, 2026));
        InsertarFaseSeleccion(Empleado, 2, DMY2Date(29, 1, 2026), 0D);
        InsertarEstadoSeleccion(Empleado, 'NV', DMY2Date(1, 1, 2026), DMY2Date(2, 1, 2026), Proyecto);
        InsertarEstadoSeleccion(Empleado, 'GP', DMY2Date(10, 1, 2026), DMY2Date(11, 1, 2026), '');
        InsertarEstadoSeleccion(Empleado, 'NV', DMY2Date(29, 1, 2026), 0D, Proyecto);
        Assert(not Proceso.EstadosJustifican(Empleado, Periodo, Tipo, ''),
            'Tener otra fase en enero no habilita un estado que cae íntegramente en el hueco sin vínculo.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure SeleccionEstadoIniciadoAntesDelAltaConservaDiaActivo()
    var
        Proceso: Codeunit "Proceso Liq. Por Lote";
        Empleado: Code[20];
        Periodo: Code[10];
        Tipo: Code[20];
        Proyecto: Code[20];
    begin
        PrepararSeleccionFase(Empleado, Periodo, Tipo, Proyecto);
        InsertarFaseSeleccion(Empleado, 1, DMY2Date(31, 1, 2026), 0D);
        InsertarEstadoSeleccion(Empleado, 'GP', DMY2Date(1, 1, 2026), DMY2Date(31, 1, 2026), '');
        Assert(Proceso.EstadosJustifican(Empleado, Periodo, Tipo, ''),
            'La intersección inclusiva de un día alcanza; el estado no necesita empezar dentro de la fase.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure SeleccionNoRecortaExclusionDePersonaPorFase()
    var
        Proceso: Codeunit "Proceso Liq. Por Lote";
        Empleado: Code[20];
        Periodo: Code[10];
        Tipo: Code[20];
        Proyecto: Code[20];
    begin
        PrepararSeleccionFase(Empleado, Periodo, Tipo, Proyecto);
        InsertarFaseSeleccion(Empleado, 1, DMY2Date(1, 1, 2026), DMY2Date(9, 1, 2026));
        InsertarEstadoSeleccion(Empleado, 'GP', DMY2Date(1, 1, 2026), DMY2Date(9, 1, 2026), '');
        InsertarEstadoSeleccion(Empleado, 'BAJ-1', DMY2Date(10, 1, 2026), 0D, '');
        Assert(not Proceso.EstadosJustifican(Empleado, Periodo, Tipo, ''),
            'La baja vigente al cierre sigue excluyendo a la persona aunque, por definición, esté fuera de su fase.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure SeleccionVentanaSiguienteUsaSuPropiaFase()
    var
        Proceso: Codeunit "Proceso Liq. Por Lote";
        Linea: Record "Estado Tipo Liq.";
        Empleado: Code[20];
        Periodo: Code[10];
        Tipo: Code[20];
        Proyecto: Code[20];
    begin
        PrepararSeleccionFase(Empleado, Periodo, Tipo, Proyecto);
        Linea.SetRange("Cód. Tipo Liq.", Tipo);
        Linea.DeleteAll(false);
        InsertarLineaSeleccion(Tipo, 'AU9', Linea.Modo::Exige, "Ventana Estado Tipo Liq."::MesSiguiente, 0, true);
        InsertarFaseSeleccion(Empleado, 1, DMY2Date(1, 1, 2026), DMY2Date(20, 2, 2026));
        InsertarEstadoSeleccion(Empleado, 'AU9', DMY2Date(1, 2, 2026), DMY2Date(10, 2, 2026), '');
        Assert(Proceso.EstadosJustifican(Empleado, Periodo, Tipo, ''),
            'Una exigencia del mes siguiente se contrasta con su ventana y su fase, no con los días de enero.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure EliminarBorradorVacioUsaLimpiezaNormal()
    var
        Lotes: Codeunit "Lotes Liquidación Liq.";
        Liq: Record "Liquidación";
        Otra: Record "Liquidación";
        Tramo: Record "Tramo Cobertura Liq.";
        Movimiento: Record "Movimiento Franco Liq.";
        Peticion: JsonArray;
        Texto: Text;
        Numero: Code[20];
        Original: Integer;
    begin
        PrepararBorradorVacio(Liq);
        Numero := Liq."No.";
        AgregarBorradorPeticion(Peticion, Liq);
        PrepararBorradorVacio(Otra);
        Tramo."No. Liquidación" := Numero;
        Tramo."No. Línea" := 1;
        Tramo.Desde := DMY2Date(1, 1, 2026);
        Tramo.Hasta := DMY2Date(31, 1, 2026);
        Tramo.Insert(true);
        Movimiento.LockTable();
        if Movimiento.FindLast() then
            Original := Movimiento."No. Movimiento";
        Original += 1;
        Movimiento.Init();
        Movimiento."No. Movimiento" := Original;
        Movimiento."No. Lote" := Original;
        Movimiento."No. Empleado" := Liq."No. Empleado";
        Movimiento."No. Liquidación" := Numero;
        Movimiento.Tipo := Movimiento.Tipo::Devengo;
        Movimiento.Cantidad := 1;
        Movimiento.Insert(true);
        Peticion.WriteTo(Texto);
        Lotes.EliminarBorradoresVaciosJson(Texto);
        Assert(not Liq.Get(Numero), 'La PK explícita del borrador injustificado debe eliminarse.');
        Assert(Otra.Get(Otra."No."), 'Un borrador ajeno a la petición debe conservarse.');
        Tramo.SetRange("No. Liquidación", Numero);
        Assert(Tramo.IsEmpty(), 'Delete(true) debe ejecutar la limpieza normal de tramos.');
        Movimiento.SetRange("Revierte Movimiento", Original);
        Assert(Movimiento.FindFirst(), 'Delete(true) debe registrar la reversión normal del franco, sin borrar su historia.');
        Assert((Movimiento.Tipo = Movimiento.Tipo::Reversion) and (Movimiento.Cantidad = -1), 'La reversión debe conservar la cantidad opuesta.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure EliminarBorradorRechazaCalculadaOJustificada()
    var
        Lotes: Codeunit "Lotes Liquidación Liq.";
        Liq: Record "Liquidación";
        Texto: Text;
    begin
        PrepararBorradorVacio(Liq);
        Liq.Estado := Liq.Estado::Calculada;
        Liq.Modify(false);
        Texto := PeticionBorrador(Liq);
        asserterror Lotes.EliminarBorradoresVaciosJson(Texto);
        Assert(GetLastErrorText().Contains('no está en Borrador'), 'Debe rechazarse el estado aunque los totales sean cero.');

        // AssertError revierte las fixtures anteriores: preparar otro escenario completo.
        PrepararBorradorVacio(Liq);
        InsertarEstadoSeleccion(Liq."No. Empleado", 'GP', DMY2Date(1, 1, 2026), DMY2Date(31, 1, 2026), '');
        Texto := PeticionBorrador(Liq);
        asserterror Lotes.EliminarBorradoresVaciosJson(Texto);
        Assert(GetLastErrorText().Contains('todavía justifican'), 'Un borrador vacío con días legítimos no debe borrarse.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure EliminarBorradorRechazaRevisionODependencia()
    var
        Lotes: Codeunit "Lotes Liquidación Liq.";
        Liq: Record "Liquidación";
        Dependiente: Record "Liquidación";
        Texto: Text;
    begin
        PrepararBorradorVacio(Liq);
        Texto := PeticionBorrador(Liq);
        Liq."Fecha Liquidación" := DMY2Date(30, 1, 2026);
        Liq.Modify(false);
        asserterror Lotes.EliminarBorradoresVaciosJson(Texto);
        Assert(GetLastErrorText().Contains('cambió desde la revisión'), 'La revisión obsoleta debe impedir la eliminación.');

        PrepararBorradorVacio(Liq);
        Dependiente.Init();
        Dependiente."No." := CodigoPrueba();
        Dependiente."No. Liq. Origen" := Liq."No.";
        Dependiente.Insert(false);
        Texto := PeticionBorrador(Liq);
        asserterror Lotes.EliminarBorradoresVaciosJson(Texto);
        Assert(GetLastErrorText().Contains('otra liquidación dependiente'), 'La dependencia debe bloquearse antes del primer Delete.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure EliminarBorradorIgnoraSoloNovedadSinDatos()
    var
        Lotes: Codeunit "Lotes Liquidación Liq.";
        Liq: Record "Liquidación";
        Novedad: Record "Novedad Liquidación";
        Concepto: Record "Concepto Liquidación";
        Texto: Text;
        Numero: Code[20];
        Movimiento: Integer;
    begin
        PrepararBorradorVacio(Liq);
        Novedad."Cód. Período" := Liq."Cód. Período";
        Novedad.Estado := Novedad.Estado::Aplicada;
        Novedad.Insert(false);
        Movimiento := Novedad."No. Movimiento";
        Numero := Liq."No.";
        Texto := PeticionBorrador(Liq);
        Lotes.EliminarBorradoresVaciosJson(Texto);
        Assert(not Liq.Get(Numero), 'Una fila colectiva sin concepto ni valores no debe justificar ni bloquear el borrador.');
        Assert(Novedad.Get(Movimiento), 'La fila vacía debe conservarse: el puente no depura novedades.');
        Assert((Novedad."Cód. Concepto" = '') and (Novedad.Cantidad = 0) and (Novedad.Importe = 0) and
            (Novedad."Valor Unitario" = 0) and (Novedad.Estado = Novedad.Estado::Aplicada), 'La fila vacía no debe modificarse.');

        PrepararBorradorVacio(Liq);
        Concepto.Código := CodigoPrueba();
        Concepto."Vigencia Desde" := DMY2Date(1, 1, 2026);
        Concepto.Insert(false);
        Novedad.Init();
        Novedad."No. Movimiento" := 0;
        Novedad."Cód. Período" := Liq."Cód. Período";
        Novedad."Cód. Concepto" := Concepto.Código;
        Novedad.Insert(false);
        Texto := PeticionBorrador(Liq);
        asserterror Lotes.EliminarBorradoresVaciosJson(Texto);
        Assert(GetLastErrorText().Contains('destino de novedades'), 'Una novedad con concepto, aunque ordene cero, debe seguir bloqueando.');

        // El rechazo revierte las fixtures anteriores; esta variante vuelve a prepararlas.
        PrepararBorradorVacio(Liq);
        Novedad.Init();
        Novedad."No. Movimiento" := 0;
        Novedad."Cód. Período" := Liq."Cód. Período";
        Novedad.Cantidad := 1;
        Novedad.Insert(false);
        Texto := PeticionBorrador(Liq);
        asserterror Lotes.EliminarBorradoresVaciosJson(Texto);
        Assert(GetLastErrorText().Contains('destino de novedades'), 'Un valor sin concepto no debe confundirse con una fila vacía.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure PuertoCoberturaPagaDiaPosteriorSinEstirarElViaje()
    var
        Contexto: Codeunit "Contexto Liquidación";
        Proyecto: Record Job;
        Asignacion: Record "Personal Proyecto";
        Puerto: Record "Estado Empleado";
        Periodo: Record "Período Liquidación";
        Tipo: Record "Tipo Liquidación";
        Cabecera: Record "Liquidación";
        Linea: Record "Línea Liquidación";
        Uso: Record "Uso Parámetro Liq.";
        VersionProyecto: BigInteger;
        VersionAsignacion: BigInteger;
        VersionEstado: BigInteger;
        Conteos: Text;
    begin
        PrepararPuertoCobertura(Proyecto, Asignacion, Puerto, Periodo, Tipo);
        Proyecto.Get(Proyecto."No.");
        Asignacion.Get(Asignacion."No. Empleado", Asignacion."No. Proyecto");
        Puerto.Get(Puerto."No. Mov.");
        VersionProyecto := Proyecto.SystemRowVersion;
        VersionAsignacion := Asignacion.SystemRowVersion;
        VersionEstado := Puerto.SystemRowVersion;
        Conteos := StrSubstNo('%1|%2|%3', Cabecera.Count(), Linea.Count(), Uso.Count());
        InicializarPuertoCobertura(Contexto, Proyecto, Asignacion, Periodo, Tipo, DMY2Date(23, 4, 2026));
        VerificarPuertoCobertura(Contexto, 21, 2, 22);
        VerificarPuertoCobertura(Contexto, 21, 2, 22);
        Proyecto.Get(Proyecto."No.");
        Asignacion.Get(Asignacion."No. Empleado", Asignacion."No. Proyecto");
        Puerto.Get(Puerto."No. Mov.");
        Assert(Proyecto.SystemRowVersion = VersionProyecto, 'Contar el puerto no debe cambiar el arribo ni las horas del proyecto.');
        Assert((Proyecto."Ending Date" = DMY2Date(22, 4, 2026)) and (Proyecto."Hora ingreso a puerto" = 083000T), 'El arribo físico debe conservarse.');
        Assert((Asignacion.SystemRowVersion = VersionAsignacion) and (Puerto.SystemRowVersion = VersionEstado), 'El día adicional ya está cargado: no debe reescribir asignaciones ni estados.');
        Assert(Conteos = StrSubstNo('%1|%2|%3', Cabecera.Count(), Linea.Count(), Uso.Count()), 'La lectura de días no crea recibos, líneas ni marcas de uso de parámetros.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure PuertoCoberturaConservaElCasoQueTerminaAlArribo()
    var
        Contexto: Codeunit "Contexto Liquidación";
        Proyecto: Record Job;
        Asignacion: Record "Personal Proyecto";
        Puerto: Record "Estado Empleado";
        Periodo: Record "Período Liquidación";
        Tipo: Record "Tipo Liquidación";
    begin
        PrepararPuertoCobertura(Proyecto, Asignacion, Puerto, Periodo, Tipo);
        Asignacion."Fecha Baja" := Proyecto."Ending Date";
        Asignacion.Modify(false);
        Puerto."Fecha Fin" := Proyecto."Ending Date";
        Puerto.Modify(false);
        // Una cobertura posterior no inventa un estado que el empleado no tiene.
        InicializarPuertoCobertura(Contexto, Proyecto, Asignacion, Periodo, Tipo, DMY2Date(23, 4, 2026));
        VerificarPuertoCobertura(Contexto, 21, 1, 22);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure PuertoCoberturaNoCuentaElMesSiguiente()
    var
        Contexto: Codeunit "Contexto Liquidación";
        Proyecto: Record Job;
        Asignacion: Record "Personal Proyecto";
        Puerto: Record "Estado Empleado";
        Periodo: Record "Período Liquidación";
        Tipo: Record "Tipo Liquidación";
    begin
        PrepararPuertoCobertura(Proyecto, Asignacion, Puerto, Periodo, Tipo);
        Asignacion."Fecha Baja" := DMY2Date(2, 5, 2026);
        Asignacion.Modify(false);
        Puerto."Fecha Fin" := DMY2Date(2, 5, 2026);
        Puerto.Modify(false);
        InicializarPuertoCobertura(Contexto, Proyecto, Asignacion, Periodo, Tipo, DMY2Date(2, 5, 2026));
        // Arribo 22 más ocho días de puerto 23..30. Mayo pertenece a otro período.
        VerificarPuertoCobertura(Contexto, 21, 9, 22);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure PuertoCoberturaExigeArriboPeriodoYReiniciaElLimite()
    var
        Contexto: Codeunit "Contexto Liquidación";
        Proyecto: Record Job;
        Asignacion: Record "Personal Proyecto";
        Puerto: Record "Estado Empleado";
        Periodo: Record "Período Liquidación";
        Tipo: Record "Tipo Liquidación";
        PeriodoInexistente: Code[10];
    begin
        PrepararPuertoCobertura(Proyecto, Asignacion, Puerto, Periodo, Tipo);
        InicializarPuertoCobertura(Contexto, Proyecto, Asignacion, Periodo, Tipo, DMY2Date(23, 4, 2026));
        VerificarPuertoCobertura(Contexto, 21, 2, 22);
        Tipo.Disparador := Tipo.Disparador::Ninguno;
        Tipo.Modify(false);
        InicializarPuertoCobertura(Contexto, Proyecto, Asignacion, Periodo, Tipo, DMY2Date(23, 4, 2026));
        VerificarPuertoCobertura(Contexto, 21, 1, 22);
        Tipo.Disparador := Tipo.Disparador::Arribo;
        Tipo.Modify(false);
        PeriodoInexistente := CopyStr(CodigoPrueba(), 1, MaxStrLen(PeriodoInexistente));
        Contexto.Init(Asignacion."No. Empleado", Proyecto."No.", PeriodoInexistente, Proyecto."Ending Date", '', '', '', Tipo.Código,
            Periodo."Fecha Desde", DMY2Date(23, 4, 2026));
        VerificarPuertoCobertura(Contexto, 21, 1, 22);
        InicializarPuertoCobertura(Contexto, Proyecto, Asignacion, Periodo, Tipo, DMY2Date(23, 4, 2026));
        VerificarPuertoCobertura(Contexto, 21, 2, 22);
        // La firma anterior conserva su límite de valoración aun después de una llamada ampliada: no hereda
        // el puerto declarado del 23. El 23 es igual un día de puerto porque la asignación llega hasta ahí.
        Contexto.Init(Asignacion."No. Empleado", Proyecto."No.", Periodo.Código, Proyecto."Ending Date", '', '', '', Tipo.Código, Periodo."Fecha Desde");
        VerificarPuertoCobertura(Contexto, 21, 2, 22);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure PuertoCoberturaConservaElPreembarqueAnterior()
    var
        Contexto: Codeunit "Contexto Liquidación";
        Proyecto: Record Job;
        Asignacion: Record "Personal Proyecto";
        Puerto: Record "Estado Empleado";
        Estados: Record "Estado Empleado";
        Periodo: Record "Período Liquidación";
        Tipo: Record "Tipo Liquidación";
        CodigoPuerto: Code[20];
    begin
        PrepararPuertoCobertura(Proyecto, Asignacion, Puerto, Periodo, Tipo);
        CodigoPuerto := Puerto."Cód. Estado";
        Estados.SetRange("Tipo Entidad", Estados."Tipo Entidad"::Empleado);
        Estados.SetRange("No. Empleado", Asignacion."No. Empleado");
        Estados.SetRange("No. Proyecto", Proyecto."No.");
        Estados.DeleteAll(false);
        Proyecto."Starting Date" := DMY2Date(3, 4, 2026);
        Proyecto.Modify(false);
        Asignacion."Fecha Alta Asignación" := Proyecto."Starting Date";
        Asignacion."Fecha Baja" := Proyecto."Ending Date";
        Asignacion.Modify(false);
        InsertarEstadoSeleccion(Asignacion."No. Empleado", CodigoPuerto, DMY2Date(2, 4, 2026), DMY2Date(2, 4, 2026), Proyecto."No.");
        InsertarEstadoSeleccion(Asignacion."No. Empleado", CodigoPuerto, Proyecto."Ending Date", Proyecto."Ending Date", Proyecto."No.");
        Contexto.Init(Asignacion."No. Empleado", Proyecto."No.", Periodo.Código, Proyecto."Ending Date", '', '', '', Tipo.Código, Periodo."Fecha Desde");
        VerificarPuertoCobertura(Contexto, 19, 2, 20);
        // La firma nueva con el mismo límite conserva el mismo día previo, una sola vez.
        InicializarPuertoCobertura(Contexto, Proyecto, Asignacion, Periodo, Tipo, Proyecto."Ending Date");
        VerificarPuertoCobertura(Contexto, 19, 2, 20);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure PuertoCoberturaExcluyeOtrosProyectosYEstados()
    var
        Contexto: Codeunit "Contexto Liquidación";
        Proyecto: Record Job;
        Asignacion: Record "Personal Proyecto";
        Puerto: Record "Estado Empleado";
        Periodo: Record "Período Liquidación";
        Tipo: Record "Tipo Liquidación";
        OtroEstado: Record "Cód. Estado Empleado";
    begin
        PrepararPuertoCobertura(Proyecto, Asignacion, Puerto, Periodo, Tipo);
        OtroEstado.Código := CodigoPrueba();
        OtroEstado."Transcurre en Marea" := false;
        OtroEstado.Insert(false);
        InsertarEstadoSeleccion(Asignacion."No. Empleado", OtroEstado.Código, DMY2Date(24, 4, 2026), DMY2Date(24, 4, 2026), Proyecto."No.");
        InsertarEstadoSeleccion(Asignacion."No. Empleado", Puerto."Cód. Estado", DMY2Date(24, 4, 2026), DMY2Date(24, 4, 2026), CodigoPrueba());
        InicializarPuertoCobertura(Contexto, Proyecto, Asignacion, Periodo, Tipo, DMY2Date(24, 4, 2026));
        VerificarPuertoCobertura(Contexto, 21, 2, 22);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure PuertoCoberturaSinHastaPosteriorSumaElDiaDeLaAsignacion()
    var
        Contexto: Codeunit "Contexto Liquidación";
        Proyecto: Record Job;
        Asignacion: Record "Personal Proyecto";
        Puerto: Record "Estado Empleado";
        Periodo: Record "Período Liquidación";
        Tipo: Record "Tipo Liquidación";
    begin
        PrepararPuertoCobertura(Proyecto, Asignacion, Puerto, Periodo, Tipo);
        // La asignación llega al 23, un día después del arribo (22): ese día de puerto lo suma la
        // asignación aunque la cobertura no pase del arribo. Es el reflejo del día de víspera.
        InicializarPuertoCobertura(Contexto, Proyecto, Asignacion, Periodo, Tipo, Proyecto."Ending Date");
        VerificarPuertoCobertura(Contexto, 21, 2, 22);
        InicializarPuertoCobertura(Contexto, Proyecto, Asignacion, Periodo, Tipo, DMY2Date(21, 4, 2026));
        VerificarPuertoCobertura(Contexto, 21, 2, 22);
        InicializarPuertoCobertura(Contexto, Proyecto, Asignacion, Periodo, Tipo, 0D);
        VerificarPuertoCobertura(Contexto, 21, 2, 22);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure PuertoPosteriorSumaHastaLaBajaDeLaAsignacionSinEstirarElViaje()
    var
        Contexto: Codeunit "Contexto Liquidación";
        Proyecto: Record Job;
        Asignacion: Record "Personal Proyecto";
        Puerto: Record "Estado Empleado";
        Periodo: Record "Período Liquidación";
        Tipo: Record "Tipo Liquidación";
    begin
        PrepararPuertoCobertura(Proyecto, Asignacion, Puerto, Periodo, Tipo);
        // Arribo 22, baja 24, cobertura hasta el arribo: el día del arribo (AM) más 23 y 24 de la asignación.
        Asignacion."Fecha Baja" := DMY2Date(24, 4, 2026);
        Asignacion.Modify(false);
        InicializarPuertoCobertura(Contexto, Proyecto, Asignacion, Periodo, Tipo, Proyecto."Ending Date");
        VerificarPuertoCobertura(Contexto, 21, 3, 22);
        // Con cobertura hasta el 23 el puerto declarado por estado ya paga el 23: la asignación sólo agrega el 24.
        InicializarPuertoCobertura(Contexto, Proyecto, Asignacion, Periodo, Tipo, DMY2Date(23, 4, 2026));
        VerificarPuertoCobertura(Contexto, 21, 3, 22);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure PuertoPosteriorNoSumaSinAsignacionAbiertaNiParaOtroDisparador()
    var
        Contexto: Codeunit "Contexto Liquidación";
        Proyecto: Record Job;
        Asignacion: Record "Personal Proyecto";
        Puerto: Record "Estado Empleado";
        Periodo: Record "Período Liquidación";
        Tipo: Record "Tipo Liquidación";
    begin
        PrepararPuertoCobertura(Proyecto, Asignacion, Puerto, Periodo, Tipo);
        Asignacion."Fecha Baja" := DMY2Date(25, 4, 2026);
        Asignacion.Modify(false);
        // Un disparador que no es el arribo no lleva el puerto posterior de la asignación.
        Tipo.Disparador := Tipo.Disparador::Ninguno;
        Tipo.Modify(false);
        InicializarPuertoCobertura(Contexto, Proyecto, Asignacion, Periodo, Tipo, Proyecto."Ending Date");
        VerificarPuertoCobertura(Contexto, 21, 1, 22);
        // Asignación sin baja: no hay hasta dónde sumar.
        Tipo.Disparador := Tipo.Disparador::Arribo;
        Tipo.Modify(false);
        Asignacion."Fecha Baja" := 0D;
        Asignacion.Modify(false);
        InicializarPuertoCobertura(Contexto, Proyecto, Asignacion, Periodo, Tipo, Proyecto."Ending Date");
        VerificarPuertoCobertura(Contexto, 21, 1, 22);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure HorasProyectoSaleDeLaFechaYHoraDeZarpadaYArribo()
    var
        Contexto: Codeunit "Contexto Liquidación";
        Proyecto: Record Job;
        Asignacion: Record "Personal Proyecto";
        Puerto: Record "Estado Empleado";
        Periodo: Record "Período Liquidación";
        Tipo: Record "Tipo Liquidación";
        Variable: Record "Variable Sistema Liq.";
    begin
        PrepararPuertoCobertura(Proyecto, Asignacion, Puerto, Periodo, Tipo);
        Variable."Cód. Cálculo" := 'HORAS_PROYECTO';
        // Zarpe 1/4 a las 09:00 y arribo 22/4 a las 08:30: 21 días menos media hora.
        InicializarPuertoCobertura(Contexto, Proyecto, Asignacion, Periodo, Tipo, Proyecto."Ending Date");
        Assert(Contexto.ComputeVariableSistema(Variable) = 503.5, 'Las horas del proyecto van del zarpe al arribo, con sus horas.');
        // Una hora en blanco cuenta como 00:00: el arribo a las 00:00 del 22/4 son 21 días menos 9 horas.
        Proyecto."Hora ingreso a puerto" := 0T;
        Proyecto.Modify(false);
        InicializarPuertoCobertura(Contexto, Proyecto, Asignacion, Periodo, Tipo, Proyecto."Ending Date");
        Assert(Contexto.ComputeVariableSistema(Variable) = 495, 'Una hora de arribo en blanco cuenta como 00:00.');
        // Sin arribo no se inventa una duración.
        Proyecto."Ending Date" := 0D;
        Proyecto.Modify(false);
        InicializarPuertoCobertura(Contexto, Proyecto, Asignacion, Periodo, Tipo, DMY2Date(22, 4, 2026));
        Assert(Contexto.ComputeVariableSistema(Variable) = 0, 'Sin fecha de arribo las horas del proyecto son cero.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure TipoQueLiquidaAlArriboCubreSoloSuProyectoAunqueSeaImproductivo()
    var
        Proyecto: Record Job;
        Asignacion: Record "Personal Proyecto";
        Puerto: Record "Estado Empleado";
        Periodo: Record "Período Liquidación";
        Tipo: Record "Tipo Liquidación";
    begin
        PrepararPuertoCobertura(Proyecto, Asignacion, Puerto, Periodo, Tipo);
        // El pilotaje: proyecto Improductivo, disparado al arribo. Cubre su tramo, no el mes.
        Tipo."Tipo Proyecto" := Tipo."Tipo Proyecto"::Improductivo;
        Tipo.Disparador := Tipo.Disparador::Arribo;
        Tipo.Modify(false);
        Assert(Tipo.CubreSoloElProyecto(Tipo.Código), 'Un tipo disparado al arribo cubre el tramo del proyecto aunque éste sea Improductivo.');
        // La regular: improductiva y sin disparador, cubre el período entero.
        Tipo.Disparador := Tipo.Disparador::Ninguno;
        Tipo.Modify(false);
        Assert(not Tipo.CubreSoloElProyecto(Tipo.Código), 'Un tipo improductivo sin disparador cubre el período entero.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure PuertoPosteriorSeAcotaAlFinDelPeriodo()
    var
        Contexto: Codeunit "Contexto Liquidación";
        Proyecto: Record Job;
        Asignacion: Record "Personal Proyecto";
        Puerto: Record "Estado Empleado";
        Periodo: Record "Período Liquidación";
        Tipo: Record "Tipo Liquidación";
    begin
        PrepararPuertoCobertura(Proyecto, Asignacion, Puerto, Periodo, Tipo);
        Asignacion."Fecha Baja" := DMY2Date(5, 5, 2026);
        Asignacion.Modify(false);
        // Arribo 22 (AM) más los días 23 a 30; mayo es de otro período.
        InicializarPuertoCobertura(Contexto, Proyecto, Asignacion, Periodo, Tipo, Proyecto."Ending Date");
        VerificarPuertoCobertura(Contexto, 21, 9, 22);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure PuertoCoberturaConservaLaFechaDeValoracion()
    var
        Contexto: Codeunit "Contexto Liquidación";
        Proyecto: Record Job;
        Asignacion: Record "Personal Proyecto";
        Puerto: Record "Estado Empleado";
        Periodo: Record "Período Liquidación";
        Tipo: Record "Tipo Liquidación";
        Version: Record "Parámetro Vigente";
        Fuente: Record "Fuente Datos Liquidación";
        Codigo: Code[20];
    begin
        PrepararPuertoCobertura(Proyecto, Asignacion, Puerto, Periodo, Tipo);
        Codigo := CodigoPrueba();
        Version."Cód. Parámetro Base" := Codigo;
        Version."Cód. Parámetro" := Codigo;
        Version."Vigencia Desde" := DMY2Date(22, 4, 2026);
        Version.Valor := 100;
        Version.Insert(false);
        Version.Init();
        Version."Cód. Parámetro Base" := Codigo;
        Version."Cód. Parámetro" := Codigo;
        Version."Vigencia Desde" := DMY2Date(23, 4, 2026);
        Version.Valor := 900;
        Version.Insert(false);
        Fuente."Nombre Variable" := CodigoPrueba();
        Fuente."Id. Tabla" := Database::"Parámetro Vigente";
        Fuente."No. Campo Valor" := Version.FieldNo(Valor);
        Fuente."Función Agregado" := Fuente."Función Agregado"::SUM;
        FiltroSUM(Fuente."Nombre Variable", Version.FieldNo("Cód. Parámetro Base"), Codigo);
        FiltroSUM(Fuente."Nombre Variable", Version.FieldNo("Vigencia Desde"), '..{FECHA_REF}');
        InicializarPuertoCobertura(Contexto, Proyecto, Asignacion, Periodo, Tipo, DMY2Date(23, 4, 2026));
        VerificarPuertoCobertura(Contexto, 21, 2, 22);
        Assert(Contexto.ResolveFuente(Fuente) = 100, 'El día de puerto adicional no debe mover FECHA_REF al 23 ni cargar sus valores o cotizaciones.');
        Assert(Contexto.ResolveFuente(Fuente) = 100, 'La lectura repetida conserva la referencia de valoración del arribo.');
        Version.Get(Codigo, Codigo, DMY2Date(23, 4, 2026));
        Assert(not Version."En Uso", 'La prueba de la referencia no debe usar BuildContext ni marcar parámetros.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure PuertoCoberturaSoloPuertoPosteriorNoGeneraViajeNegativo()
    var
        Contexto: Codeunit "Contexto Liquidación";
        Proyecto: Record Job;
        Asignacion: Record "Personal Proyecto";
        Puerto: Record "Estado Empleado";
        Periodo: Record "Período Liquidación";
        Tipo: Record "Tipo Liquidación";
    begin
        PrepararPuertoCobertura(Proyecto, Asignacion, Puerto, Periodo, Tipo);
        Contexto.Init(Asignacion."No. Empleado", Proyecto."No.", Periodo.Código, Proyecto."Ending Date", '', '', '', Tipo.Código,
            DMY2Date(23, 4, 2026), DMY2Date(23, 4, 2026));
        VerificarPuertoCobertura(Contexto, 0, 1, 0);
        // Quien sólo tenía puerto hasta el arribo no recibe un día por ampliar cobertura.
        Puerto."Fecha Fin" := Proyecto."Ending Date";
        Puerto.Modify(false);
        Asignacion."Fecha Baja" := Proyecto."Ending Date";
        Asignacion.Modify(false);
        Contexto.Init(Asignacion."No. Empleado", Proyecto."No.", Periodo.Código, Proyecto."Ending Date", '', '', '', Tipo.Código,
            DMY2Date(23, 4, 2026), DMY2Date(23, 4, 2026));
        VerificarPuertoCobertura(Contexto, 0, 0, 0);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure PuertoCoberturaRespetaElHuecoEntreTramos()
    var
        Contexto: Codeunit "Contexto Liquidación";
        Proyecto: Record Job;
        Asignacion: Record "Personal Proyecto";
        Puerto: Record "Estado Empleado";
        Periodo: Record "Período Liquidación";
        Tipo: Record "Tipo Liquidación";
        Tramo: Record "Tramo Cobertura Liq.";
        Cabecera: Record "Liquidación";
        Documento: Code[20];
    begin
        PrepararPuertoCobertura(Proyecto, Asignacion, Puerto, Periodo, Tipo);
        Puerto."Fecha Fin" := DMY2Date(24, 4, 2026);
        Puerto.Modify(false);
        Asignacion."Fecha Baja" := Puerto."Fecha Fin";
        Asignacion.Modify(false);
        // Sin tramos, el envolvente 1..24 incluye arribo 22 y puerto personal 23/24.
        InicializarPuertoCobertura(Contexto, Proyecto, Asignacion, Periodo, Tipo, DMY2Date(24, 4, 2026));
        VerificarPuertoCobertura(Contexto, 21, 3, 22);
        Documento := CodigoPrueba();
        Assert(not Cabecera.Get(Documento), 'El identificador de la prueba no debe pertenecer a una liquidación existente.');
        Tramo."No. Liquidación" := Documento;
        Tramo."No. Línea" := 1;
        Tramo.Desde := DMY2Date(1, 4, 2026);
        Tramo.Hasta := DMY2Date(22, 4, 2026);
        Tramo.Días := 22;
        Tramo.Insert(false);
        Tramo.Init();
        Tramo."No. Liquidación" := Documento;
        Tramo."No. Línea" := 2;
        Tramo.Desde := DMY2Date(24, 4, 2026);
        Tramo.Hasta := DMY2Date(24, 4, 2026);
        Tramo.Días := 1;
        Tramo.Insert(false);
        Contexto.Init(Asignacion."No. Empleado", Proyecto."No.", Periodo.Código, Proyecto."Ending Date", '', '', Documento, Tipo.Código,
            Periodo."Fecha Desde", DMY2Date(24, 4, 2026));
        // El día 23 pertenece al hueco; los días de navegación y del viaje no cambian.
        VerificarPuertoCobertura(Contexto, 21, 2, 22);
        Assert(not Cabecera.Get(Documento), 'Leer tramos de prueba no debe crear una cabecera ni ejecutar el cálculo.');
    end;

    local procedure PrepararPuertoCobertura(var Proyecto: Record Job; var Asignacion: Record "Personal Proyecto"; var Puerto: Record "Estado Empleado"; var Periodo: Record "Período Liquidación"; var Tipo: Record "Tipo Liquidación")
    var
        Empleado: Record Employee;
        CodigoEstado: Record "Cód. Estado Empleado";
        Navegacion: Record "Estado Empleado";
    begin
        if not CompanyName().StartsWith('TEST_') then
            Error('Los fixtures de puerto sólo pueden ejecutarse en una empresa aislada TEST_.');
        Empleado."No." := CodigoPrueba();
        Empleado.Insert(false);
        Proyecto."No." := CodigoPrueba();
        Proyecto."Starting Date" := DMY2Date(1, 4, 2026);
        Proyecto."Ending Date" := DMY2Date(22, 4, 2026);
        Proyecto."Hora de zarpada" := 090000T;
        Proyecto."Hora ingreso a puerto" := 083000T;
        Proyecto.Insert(false);
        Asignacion."No. Empleado" := Empleado."No.";
        Asignacion."No. Proyecto" := Proyecto."No.";
        Asignacion."Fecha Alta Asignación" := Proyecto."Starting Date";
        Asignacion."Fecha Baja" := DMY2Date(23, 4, 2026);
        Asignacion.Insert(false);
        CodigoEstado.Código := CodigoPrueba();
        CodigoEstado."Transcurre en Marea" := true;
        CodigoEstado.Insert(false);
        Navegacion."Tipo Entidad" := Navegacion."Tipo Entidad"::Empleado;
        Navegacion."No. Empleado" := Empleado."No.";
        Navegacion."No. Proyecto" := Proyecto."No.";
        Navegacion."Cód. Estado" := CodigoEstado.Código;
        Navegacion."Fecha Inicio" := Proyecto."Starting Date";
        Navegacion."Fecha Fin" := DMY2Date(21, 4, 2026);
        Navegacion.Insert(false);
        CodigoEstado.Init();
        CodigoEstado.Código := CodigoPrueba();
        CodigoEstado."Transcurre en Marea" := true;
        CodigoEstado.Insert(false);
        Puerto."Tipo Entidad" := Puerto."Tipo Entidad"::Empleado;
        Puerto."No. Empleado" := Empleado."No.";
        Puerto."No. Proyecto" := Proyecto."No.";
        Puerto."Cód. Estado" := CodigoEstado.Código;
        Puerto."Fecha Inicio" := Proyecto."Ending Date";
        Puerto."Fecha Fin" := DMY2Date(23, 4, 2026);
        Puerto.Insert(false);
        Periodo.Código := CopyStr(CodigoPrueba(), 1, MaxStrLen(Periodo.Código));
        Periodo."Fecha Desde" := DMY2Date(1, 4, 2026);
        Periodo."Fecha Hasta" := DMY2Date(30, 4, 2026);
        Periodo.Insert(false);
        Tipo.Código := CodigoPrueba();
        Tipo.Disparador := Tipo.Disparador::Arribo;
        Tipo.Activo := true;
        Tipo.Insert(false);
    end;

    local procedure InicializarPuertoCobertura(var Contexto: Codeunit "Contexto Liquidación"; Proyecto: Record Job; Asignacion: Record "Personal Proyecto"; Periodo: Record "Período Liquidación"; Tipo: Record "Tipo Liquidación"; Hasta: Date)
    begin
        Contexto.Init(Asignacion."No. Empleado", Proyecto."No.", Periodo.Código, Proyecto."Ending Date", '', '', '', Tipo.Código,
            Periodo."Fecha Desde", Hasta);
    end;

    local procedure VerificarPuertoCobertura(var Contexto: Codeunit "Contexto Liquidación"; Navegacion: Decimal; Puerto: Decimal; Viaje: Decimal)
    var
        Variable: Record "Variable Sistema Liq.";
    begin
        Variable."Cód. Cálculo" := 'DIAS_MAREA';
        Assert(Contexto.ComputeVariableSistema(Variable) = Viaje, 'Los días del viaje para acuerdos no deben incorporar el puerto ajeno a la ventana física de la marea.');
        Variable."Cód. Cálculo" := 'DIAS_PROYECTO';
        Assert(Contexto.ComputeVariableSistema(Variable) = Navegacion, 'El puerto fuera del viaje no debe alterar la navegación.');
        Variable."Cód. Cálculo" := 'DIAS_PUERTO';
        Assert(Contexto.ComputeVariableSistema(Variable) = Puerto, 'Los días de puerto deben respetar los estados y la cobertura independiente de la fecha de valoración.');
    end;

    local procedure PrepararBorradorVacio(var Liq: Record "Liquidación")
    var
        Empleado: Code[20];
        Periodo: Code[10];
        Tipo: Code[20];
        Proyecto: Code[20];
    begin
        // Esta rutina comprueba TEST_ antes de su primera escritura.
        PrepararSeleccionFase(Empleado, Periodo, Tipo, Proyecto);
        InsertarFaseSeleccion(Empleado, 1, DMY2Date(1, 1, 2026), 0D);
        InsertarEstadoSeleccion(Empleado, 'NV', DMY2Date(1, 1, 2026), DMY2Date(31, 1, 2026), Proyecto);
        Liq.Init();
        Liq."No." := CodigoPrueba();
        Liq."No. Empleado" := Empleado;
        Liq."Cód. Período" := Periodo;
        Liq."Cód. Tipo Liq." := Tipo;
        Liq."Fecha Liquidación" := DMY2Date(31, 1, 2026);
        Liq.Insert(false);
        Liq.Get(Liq."No.");
    end;

    local procedure AgregarBorradorPeticion(var Peticion: JsonArray; Liq: Record "Liquidación")
    var
        Fila: JsonObject;
    begin
        Fila.Add('numero', Liq."No.");
        Fila.Add('rowversion', Format(Liq.SystemRowVersion, 0, 9));
        Peticion.Add(Fila);
    end;

    local procedure PeticionBorrador(Liq: Record "Liquidación") Texto: Text
    var
        Peticion: JsonArray;
    begin
        // Releer para que la petición use la revisión persistida tras Insert/Modify.
        Liq.Get(Liq."No.");
        AgregarBorradorPeticion(Peticion, Liq);
        Peticion.WriteTo(Texto);
    end;

    local procedure PrepararSeleccionFase(var Empleado: Code[20]; var CodPeriodo: Code[10]; var Tipo: Code[20]; var Proyecto: Code[20])
    var
        Periodo: Record "Período Liquidación";
        TipoLiq: Record "Tipo Liquidación";
        Job: Record Job;
        Empresa: Text;
    begin
        Empresa := CompanyName();
        Assert(Empresa.StartsWith('TEST_'), 'Las pruebas de selección sólo pueden preparar datos en una empresa aislada TEST_.');
        Empleado := CodigoPrueba();
        CodPeriodo := CopyStr(CodigoPrueba(), 1, MaxStrLen(CodPeriodo));
        Tipo := CodigoPrueba();
        Proyecto := CodigoPrueba();
        Periodo.Código := CodPeriodo;
        Periodo."Fecha Desde" := DMY2Date(1, 1, 2026);
        Periodo."Fecha Hasta" := DMY2Date(31, 1, 2026);
        Periodo.Insert(false);
        TipoLiq.Código := Tipo;
        TipoLiq.Orden := 10000;
        TipoLiq."Agrupa por Empleado" := true;
        TipoLiq.Insert(false);
        Job."No." := Proyecto;
        Job.Tipo := 1;
        Job.Insert(false);
        InsertarLineaSeleccion(Tipo, '', "Modo Estado Tipo Liq."::Exige, "Ventana Estado Tipo Liq."::Periodo, 2, false);
        InsertarLineaSeleccion(Tipo, 'NV|PL|PS', "Modo Estado Tipo Liq."::Excluye, "Ventana Estado Tipo Liq."::Cobertura, 1, false);
        InsertarLineaSeleccion(Tipo, 'BAJ*', "Modo Estado Tipo Liq."::ExcluyePersona, "Ventana Estado Tipo Liq."::Cobertura, 0, false);
    end;

    local procedure InsertarLineaSeleccion(Tipo: Code[20]; CodEstado: Text[50]; Modo: Enum "Modo Estado Tipo Liq."; Ventana: Enum "Ventana Estado Tipo Liq."; TipoProyecto: Integer; Empieza: Boolean)
    var
        Linea: Record "Estado Tipo Liq.";
    begin
        Linea."Cód. Tipo Liq." := Tipo;
        Linea."Cód. Estado" := CodEstado;
        Linea.Modo := Modo;
        Linea.Ventana := Ventana;
        Linea."Tipo Proyecto" := TipoProyecto;
        Linea."Empieza en la Ventana" := Empieza;
        Linea.Insert(false);
    end;

    local procedure InsertarFaseSeleccion(Empleado: Code[20]; Numero: Integer; Desde: Date; Hasta: Date)
    var
        Fase: Record "Fase Alta Empleado";
    begin
        Fase."No. Empleado" := Empleado;
        Fase."No. Fase" := Numero;
        Fase."Fecha Alta" := Desde;
        Fase."Fecha Baja" := Hasta;
        Fase.Insert(false);
    end;

    local procedure InsertarEstadoSeleccion(Empleado: Code[20]; Codigo: Code[20]; Desde: Date; Hasta: Date; Proyecto: Code[20])
    var
        Estado: Record "Estado Empleado";
    begin
        Estado."Tipo Entidad" := Estado."Tipo Entidad"::Empleado;
        Estado."No. Empleado" := Empleado;
        Estado."Cód. Estado" := Codigo;
        Estado."Fecha Inicio" := Desde;
        Estado."Fecha Fin" := Hasta;
        Estado."No. Proyecto" := Proyecto;
        Estado.Insert(false);
    end;

    local procedure InsertarLineaSUM(Documento: Code[20]; Numero: Integer; Empleado: Code[20]; Fecha: Date; Importe: Decimal; Estado: Enum "Estado Liq.")
    var
        Linea: Record "Línea Liquidación";
    begin
        Linea."No. Liquidación" := Documento;
        Linea."No. Línea" := Numero;
        Linea."No. Empleado" := Empleado;
        Linea."Fecha Liquidación" := Fecha;
        Linea.Importe := Importe;
        Linea.Estado := Estado;
        Linea.Insert(false);
    end;

    local procedure InsertarFamiliarSUM(Empleado: Code[20]; Numero: Integer; Desde: Date; Hasta: Date; DesdeObsoleto: Date; HastaObsoleto: Date; Porcentaje: Decimal)
    var
        Familiar: Record "Employee Relative";
        Referencia: RecordRef;
        Campo: FieldRef;
    begin
        Familiar."Employee No." := Empleado;
        Familiar."Line No." := Numero;
        Familiar."% Deducción" := Porcentaje;
        Referencia.GetTable(Familiar);
        Campo := Referencia.Field(50008);
        Campo.Value := Desde;
        Campo := Referencia.Field(50009);
        Campo.Value := Hasta;
        Campo := Referencia.Field(50211);
        Campo.Value := DesdeObsoleto;
        Campo := Referencia.Field(50212);
        Campo.Value := HastaObsoleto;
        Referencia.Insert(false);
        Referencia.Close();
    end;

    local procedure FiltroSUM(Nombre: Code[30]; Campo: Integer; Valor: Text)
    var
        Filtro: Record "Filtro Fuente Datos Liq.";
    begin
        Filtro."Nombre Variable" := Nombre;
        Filtro."No. Campo" := Campo;
        Filtro."Filtro Valor" := CopyStr(Valor, 1, MaxStrLen(Filtro."Filtro Valor"));
        Filtro.Insert(false);
    end;

    local procedure CodigoPrueba(): Code[20]
    begin
        exit('T' + CopyStr(DelChr(Format(CreateGuid()), '=', '{}-'), 1, 19));
    end;

    local procedure InsertarLinea(var Lin: Record "Línea Liquidación" temporary; Numero: Integer; Codigo: Code[20])
    begin
        Lin.Init();
        Lin."No. Liquidación" := 'TEST';
        Lin."No. Línea" := Numero;
        Lin."Cód. Concepto" := Codigo;
        Lin.Insert(false);
    end;

    local procedure Assert(Condicion: Boolean; Mensaje: Text)
    begin
        if not Condicion then
            Error(Mensaje);
    end;
}
