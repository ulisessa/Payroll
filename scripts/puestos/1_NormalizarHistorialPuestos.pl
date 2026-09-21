use strict; use warnings;

# Normaliza M4T_HIST_PUESTOS.
#
# REGLA CENTRAL: cada vigencia se cierra el dia ANTERIOR al inicio de la siguiente del
# mismo empleado. Una fila sin FEC_FIN NO significa "vigente hoy": significa "abierta
# cuando se escribio", y la pisa cualquier fila posterior. Es la misma leccion que las
# islas de Estado Empleado — el fin sale de la fila que ARRANCA ultima, nunca del maximo
# de FEC_FIN, porque el blanco es el minimo de la columna, no el maximo.
#
# Los huecos genuinos SE CONSERVAN: si FEC_FIN esta puesta y cae antes del inicio de la
# siguiente, manda FEC_FIN. El atributo admite huecos; inventar continuidad seria afirmar
# un puesto que la fuente no afirma.
#
# COMENT trae saltos de linea adentro, asi que un registro puede ocupar dos lineas
# fisicas. Un registro EMPIEZA con "NNNNN"| ; todo lo demas es continuacion.

my (%h, $n, $cont);

open(my $f, '<:encoding(UTF-8)', $ARGV[0]) or die $!;
my $hdr = <$f>;
my $buf = '';
while (my $l = <$f>) {
    $l =~ s/\r?\n$//;
    if ($l =~ /^"\d+"\|/) { procesar($buf); $buf = $l }
    else                  { $buf .= ' ' . $l; $cont++ }
}
procesar($buf);
close $f;

sub procesar {
    my $line = shift;
    return if !defined $line || $line eq '';
    $line =~ s/"//g;
    my @c = split /\|/, $line, -1;
    return if @c < 5;
    my ($leg, $ini, $fin, $pue, $mot) = @c[0..4];
    $ini =~ s/ .*//; $fin =~ s/ .*//;
    return unless $leg ne '' && $ini ne '' && $pue ne '';
    push @{$h{$leg}}, [$ini, $fin, $pue, $mot];
    $n++;
}

sub d2n { my @p = split /-/, shift; return $p[0]*10000 + $p[1]*100 + $p[2] }
sub prevday {
    my ($y, $m, $d) = split /-/, shift;
    return sprintf("%04d-%02d-%02d", $y, $m, $d-1) if $d > 1;
    $m--; if ($m < 1) { $m = 12; $y-- }
    my @dm = (31, ((($y%4==0 && $y%100!=0) || $y%400==0) ? 29 : 28), 31,30,31,30,31,31,30,31,30,31);
    return sprintf("%04d-%02d-%02d", $y, $m, $dm[$m-1]);
}

my ($trunc, $gap, $solap, $out, $mismo, $abiertas) = (0,0,0,0,0,0);
open(my $o, '>:encoding(UTF-8)', $ARGV[1]) or die $!;
print $o "Leg|Desde|Hasta|Puesto|Motivo\n";
for my $leg (sort keys %h) {
    my @r = sort { d2n($a->[0]) <=> d2n($b->[0]) } @{$h{$leg}};
    for my $i (0 .. $#r) {
        my ($ini, $fin, $pue, $mot) = @{$r[$i]};
        # dos filas con el mismo inicio: la primera queda de ancho cero, se descarta
        if ($i < $#r && d2n($r[$i+1][0]) <= d2n($ini)) { $mismo++; next }
        my $tope = ($i < $#r) ? prevday($r[$i+1][0]) : '';
        my $hasta = $fin;
        if ($tope ne '') {
            if    ($fin eq '')              { $hasta = $tope; $trunc++ }
            elsif (d2n($fin) > d2n($tope))  { $hasta = $tope; $solap++ }
            elsif (d2n($fin) < d2n($tope))  { $gap++ }
        } elsif ($fin eq '') { $abiertas++ }
        print $o join('|', $leg, $ini, $hasta, $pue, $mot), "\n";
        $out++;
    }
}
close $o;

printf "registros=%d  lineas de continuacion unidas=%d  salida=%d  empleados=%d\n",
       $n, $cont // 0, $out, scalar(keys %h);
printf "  abiertas truncadas por una fila posterior  : %d\n", $trunc;
printf "  solapes recortados (FEC_FIN pisaba la sig) : %d\n", $solap;
printf "  huecos genuinos conservados                : %d\n", $gap;
printf "  descartadas (mismo inicio que la siguiente): %d\n", $mismo;
printf "  quedan realmente abiertas (ultima del emp) : %d\n", $abiertas;
