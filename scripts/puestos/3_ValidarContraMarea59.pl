use strict; use warnings; use utf8;
binmode(STDOUT, ':utf8');
my $SCR = $ENV{SCR};

# Simula lo que va a hacer el motor despues de la migracion, sin tocar la base:
#   puesto vigente a la fecha de referencia -> categoria -> VALOR_CAL_ENT -> produccion
# y lo compara contra lo que pago el recibo de Meta4.
#
# La fecha de referencia de un Cierre de Marea es el ARRIBO, no el fin del periodo.
# Para A28/59 es el 29/01/2026.

my $FECHA_REF = '2026-01-29';
my $KILOS     = 633.639;

my %MAP = (
  CB01=>'OF01', CB02=>'FE01', CB03=>'OF03', CB04=>'MR00', CB06=>'MR01', CB07=>'MR05',
  CB09=>'MR09', CB10=>'OF05', MQ01=>'OF02', MQ02=>'FE02', MQ03=>'OF04', MQ04=>'OF06',
  MQ05=>'MR04', PT02=>'MR08', PT04=>'MR07', ME01=>'MR02', ME02=>'MR03', ME03=>'MR06',
);
my %VALOR = (MR00=>14286, MR01=>12143, MR02=>12143, MR03=>11429, MR04=>10714,
             MR05=>10714, MR06=>11429, MR07=>11429, MR08=>10000, MR09=>11429);

# Lo que pago el recibo, deducido de la produccion / kilos. Dato del documento.
my %RECIBO = (
  '03753'=>10000, '03772'=>10714, '03774'=>11429, '03957'=>14286, '03961'=>12143,
  '04066'=>10714, '04091'=>10000, '04105'=>10714, '04169'=>10000, '04274'=>10000,
  '04301'=>10000, '04368'=>10000, '04517'=>10000, '04648'=>10000, '04669'=>10714,
  '04683'=>10000, '04733'=>10000, '04734'=>10000, '04738'=>10000, '04789'=>11429,
  '04798'=>12143, '04880'=>10000, '04913'=>14286, '04914'=>10714, '04915'=>10714,
  '04918'=>10000,
);

# Puesto vigente a FECHA_REF, con la MISMA regla que ValorParaLiquidacion: la ultima
# vigencia que empezo antes o en esa fecha y que no cerro antes de ella.
my %vig;
open(my $p, '<:utf8', "$SCR/puestos_norm.psv") or die $!;
<$p>;
while (<$p>) {
    chomp; my ($leg,$d,$h,$pue) = split /\|/, $_, -1;
    next unless exists $RECIBO{$leg};
    next unless $d le $FECHA_REF;
    next unless $h eq '' || $h ge $FECHA_REF;
    # FindLast: gana la que empieza mas tarde
    $vig{$leg} = [$d,$pue] if !$vig{$leg} || $d ge $vig{$leg}[0];
}
close $p;

printf "%-7s %-7s %-6s %-9s %-9s %-16s %s\n",
       'Legajo','Puesto','Cat','Ton mapeo','Ton recibo','Producción','';
print '-' x 72, "\n";
my ($ok,$mal,$sin) = (0,0,0);
for my $leg (sort keys %RECIBO) {
    my $v = $vig{$leg};
    if (!$v) { printf "%-7s %-7s %-6s %-9s %-9s %-16s %s\n", $leg,'—','—','','',
                      '', 'SIN PUESTO VIGENTE'; $sin++; next }
    my ($d,$pue) = @$v;
    my $cat = $MAP{$pue} // '';
    my $ton = $VALOR{$cat} // 0;
    my $esp = $RECIBO{$leg};
    my $marca = ($ton == $esp) ? '.' : 'NO COINCIDE';
    $ton == $esp ? $ok++ : $mal++;
    printf "%-7s %-7s %-6s %9d %9d %16.2f %s\n",
           $leg, $pue, $cat, $ton, $esp, $KILOS*$ton, $marca;
}
print '-' x 72, "\n";
printf "coinciden=%d  fallan=%d  sin puesto=%d  (de %d)\n", $ok, $mal, $sin, scalar keys %RECIBO;
