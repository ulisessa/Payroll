namespace UAS.Payroll;

using Microsoft.HumanResources.Setup;

// DEPENDENCIA: Este permission set cubre únicamente los objetos del módulo Payroll (rango 50000-61000).
// Para acceso completo se requieren además los siguientes roles estándar de BC:
//   • Employee / HR Setup  → "D365 HUMAN RES, FULL" o equivalente
//   • Job (Marea)          → "D365 PROJECT MGMT" o equivalente
// Asignar junto a uno de los roles anteriores.
permissionset 50301 "Liq.Pesca-Liquidador"
{
    // Can run calculations and manage liquidations for a period.
    // Cannot modify master configuration (CCT, concepts, parameters, bracket tables,
    // sources, system variables, Ganancias tables).
    Assignable = true;
    Caption = 'Liq. Pesca - Liquidador';

    Permissions =
        // ── Transactional / operational — full access ──
        tabledata "Estado Empleado" = RIM,
        tabledata "Personal Proyecto" = RIMD,
        tabledata "Período Liquidación" = RIM,
        tabledata "Liquidación" = RIMD,
        tabledata "Línea Liquidación" = RIMD,
        tabledata "Detalle Variable Línea Liq." = RIMD,
        tabledata "Resumen Variable Liq." = RIMD,
        tabledata "Incidencia Liquidación" = RIMD,
        tabledata "Ded. Ganancias Empleado" = RIMD,
        // ── Master data — read only ──
        tabledata "Cód. Estado Empleado" = R,
        tabledata "Convenio Colectivo" = R,
        tabledata "Categoría CCT" = R,
        tabledata "Concepto Liquidación" = R,
        tabledata "Parámetro" = R,
        tabledata "Parámetro Vigente" = R,
        tabledata "Tabla Escalonada" = R,
        tabledata "Tabla Escalonada Det." = R,
        tabledata "Fuente Datos Liquidación" = R,
        tabledata "Fracción Acumulador" = R,
        tabledata "Variable Sistema Liq." = R,
        tabledata "Concepto CCT Vigente" = R,
        tabledata "Ded. Ganancias Vigente" = R,
        tabledata "Human Resources Setup" = R,
        // ── Tables — schema ──
        table "Estado Empleado" = X,
        table "Cód. Estado Empleado" = X,
        table "Convenio Colectivo" = X,
        table "Categoría CCT" = X,
        table "Concepto Liquidación" = X,
        table "Parámetro Vigente" = X,
        table "Personal Proyecto" = X,
        table "Período Liquidación" = X,
        table "Liquidación" = X,
        table "Línea Liquidación" = X,
        table "Tabla Escalonada" = X,
        table "Tabla Escalonada Det." = X,
        table "Fuente Datos Liquidación" = X,
        table "Parámetro" = X,
        table "Fracción Acumulador" = X,
        table "Variable Sistema Liq." = X,
        table "Concepto CCT Vigente" = X,
        table "Incidencia Liquidación" = X,
        table "Ded. Ganancias Vigente" = X,
        table "Ded. Ganancias Empleado" = X,
        table "Detalle Variable Línea Liq." = X,
        table "Resumen Variable Liq." = X,
        // ── Codeunits ──
        codeunit "Motor Liquidación" = X,
        codeunit "Evaluador Fórmula" = X,
        codeunit "Contexto Liquidación" = X,
        codeunit "Gestión Estado Empleado" = X,
        codeunit "Proceso Liq. Por Lotes" = X,
        codeunit "Gestión Liquidación" = X,
        // ── Pages ──
        page "Lista Liquidaciones" = X,
        page "Ficha Liquidación" = X,
        page "Líneas Liquidación" = X,
        page "Estados Empleado" = X,
        page "Cód. Estados Empleado" = X,
        page "Nuevo Estado Empleado" = X,
        page "Estado Empleado FactBox" = X,
        page "Convenios Colectivos" = X,
        page "Categorías CCT" = X,
        page "Conceptos Liquidación" = X,
        page "Concepto Liq. Card" = X,
        page "Parámetros" = X,
        page "Parámetro Card" = X,
        page "Parámetro Vigente Subpag" = X,
        page "Parámetro Sufijo Sub" = X,
        page "Parámetros Vigentes" = X,
        page "Personal Proyecto" = X,
        page "Períodos Liquidación" = X,
        page "Tabla Escalonada List" = X,
        page "Tabla Escalonada Card" = X,
        page "Tabla Escalonada Det. Sub" = X,
        page "Fuente Datos Liquidación" = X,
        page "Fuente Datos Card" = X,
        page "Tabla Liq. Lookup" = X,
        page "Campo Liq. Lookup" = X,
        page "Fracción Acumulador Sub" = X,
        page "Variable Sistema Liq." = X,
        page "Variables Liq. Test Sub" = X,
        page "Concepto CCT Sub" = X,
        page "Incidencias Liquidación Sub" = X,
        page "Asistente Fórmula Liq." = X,
        page "Lanzador Liquidaciones" = X,
        page "Detalle Variable Línea Sub" = X,
        page "Variables Cálculo Línea" = X,
        page "Ded. Ganancias Vigente" = X,
        page "Ded. Ganancias Vigente Card" = X,
        page "Ded. Ganancias Empleado Sub" = X,
        page "Payroll Role Center" = X,
        // ── Reports ──
        report "Recibo de Sueldo" = X;
}
