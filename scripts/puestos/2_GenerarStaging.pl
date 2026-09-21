use strict; use warnings; use utf8;
binmode(STDOUT, ':utf8');
my $SCR = $ENV{SCR};

# Genera el INSERT del historial de puestos como atributo, a partir del archivo ya
# normalizado. Traduce ID_PUESTO -> codigo de categoria, y CIERRA cada vigencia contra
# la fase de alta del empleado.
#
# LO QUE NO SE CARGA, y por que:
#  · Puestos de tierra (PP*, PN*, PF*, PE*, PV*, PC*, PZ*, PD*, PG*, CM*, MAE, ADM) y DES
#    "Desconocido": no tienen categoria del CCT a la que llevarlos. Sin fila, el concepto
#    cae en la categoria del encuadre, que es el comportamiento de hoy. Es el fallback
#    seguro y no hay que inventarles un codigo.
#  · Vigencias enteras posteriores a la ultima baja del empleado.

my %MAP = (
  CB01=>'OF01', CB02=>'FE01', CB03=>'OF03', CB04=>'MR00', CB06=>'MR01', CB07=>'MR05',
  CB09=>'MR09', CB10=>'OF05', MQ01=>'OF02', MQ02=>'FE02', MQ03=>'OF04', MQ04=>'OF06',
  MQ05=>'MR04', PT02=>'MR08', PT04=>'MR07', ME01=>'MR02', ME02=>'MR03', ME03=>'MR06',
);

# Empleado -> (activo, ultima baja). Sin fila en BC, el empleado no existe y se saltea.
my (%act, %baja);
open(my $b, '<:utf8', "$SCR/bc_emp.psv") or die $!;
while (<$b>) { chomp; my @c = split /\|/, $_, -1; next unless @c >= 3;
               $act{$c[0]} = ($c[1] eq 'A'); $baja{$c[0]} = $c[2] }
close $b;

my ($tot,$sinEmp,$sinMapeo,$postBaja,$recortada,$ok) = (0)x6;
my @rows;
open(my $p, '<:utf8', "$SCR/puestos_norm.psv") or die $!;
<$p>;
while (<$p>) {
    chomp; my ($leg,$d,$h,$pue) = split /\|/, $_, -1;
    $tot++;
    if (!exists $act{$leg})       { $sinEmp++; next }
    my $cat = $MAP{$pue};
    if (!defined $cat)            { $sinMapeo++; next }

    # Cerrar contra la baja: una vigencia de puesto no puede sobrevivir a la relacion
    # laboral. Sin esto quedan 1.951 abiertas contra ~336 activos.
    my $tope = $act{$leg} ? '' : ($baja{$leg} // '');
    if ($tope ne '') {
        if ($d gt $tope)                  { $postBaja++; next }
        if ($h eq '' || $h gt $tope)      { $h = $tope; $recortada++ }
    }
    push @rows, [$leg, $d, $h, $cat];
    $ok++;
}
close $p;

printf STDERR "normalizadas=%d  a cargar=%d\n", $tot, $ok;
printf STDERR "  sin empleado en BC                : %d\n", $sinEmp;
printf STDERR "  puesto de tierra / DES / sin mapeo: %d\n", $sinMapeo;
printf STDERR "  vigencia entera posterior a la baja: %d\n", $postBaja;
printf STDERR "  vigencia recortada en la baja      : %d\n", $recortada;

# El INSERT, en lotes de 900 filas: el limite de un VALUES en SQL Server es 1000.
my $APP = 'd4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890';
my $T   = "dbo.[ArbuTest\$Atributo Entidad Liq_\$$APP]";
open(my $o, '>:encoding(UTF-8)', "$SCR/cargaPuestos.sql") or die $!;
print $o "SET NOCOUNT ON;\nSET XACT_ABORT ON;\n\n";
print $o "IF OBJECT_ID('tempdb..#Puesto') IS NOT NULL DROP TABLE #Puesto;\n";
print $o "CREATE TABLE #Puesto (Leg nvarchar(20) COLLATE DATABASE_DEFAULT, Desde date, Hasta date, Cat nvarchar(10) COLLATE DATABASE_DEFAULT);\n\n";
my $i = 0;
while ($i <= $#rows) {
    my $j = $i + 899; $j = $#rows if $j > $#rows;
    print $o "INSERT INTO #Puesto (Leg,Desde,Hasta,Cat) VALUES\n";
    print $o join(",\n", map { sprintf("('%s','%s',%s,'%s')", $_->[0], $_->[1],
                        ($_->[2] eq '' ? "'1753-01-01'" : "'$_->[2]'"), $_->[3]) } @rows[$i..$j]);
    print $o ";\n";
    $i = $j + 1;
}
print $o "\nSELECT COUNT(*) AS FilasEnStaging FROM #Puesto;\n";
close $o;
printf STDERR "generado: %s  (%d filas)\n", "$SCR/cargaPuestos.sql", scalar @rows;
