#!/usr/bin/perl 
# Toby Thurston -- 07 Jun 2013 
#
# Filter maths lines for Vim 

use strict;
use warnings;
use DateTime;
use Math::Complex qw/cplx Re Im/;
use POSIX qw/floor/;

my $Number_pattern = qr{[-+]?                # optional sign
                        (?:\d+\.\d*|\.?\d+)  # mantissa [following Cowlishaw, TRL p.136]
                        (?:E[-+]?\d+)?       # exponent
                       }ixmso;

while ( <> ) {
    chomp;
    my $original_line = $_;
    my ($prefix, $expression) = $original_line =~ m{\A(.*?)(\S+)\s*\Z}ixmso;

    my $mode = 'replace';
    if ( $expression =~ m{\A(.*?)([=]+)\Z}xmsio ) {
        $mode = $2 eq '='  ? 'append_rounded'
              :              'append_exact'; # more than 1 = sign 
        $expression = $1;
    }

    my $style = 'plain';
    if ( $expression =~ m{\A\$(.*)\Z}xmsio ) { 
        $style = 'tex';
        $expression = $1;
    }

    my $original_expression = $expression; 

    # Syntactic sugar... 
    $expression =~ s{π}                                       {bignum::PI()}gixmso  ; 
    $expression =~ s{\\pi}                                     {bignum::PI()}gismxo  ; 
    $expression =~ s{×}                                       {*}gismxo             ; 
    $expression =~ s{·}                                       {*}gismxo             ; 
    $expression =~ s{÷}                                       {/}gismxo             ; 
    $expression =~ s{\\times}                                  {*}gismxo             ; 
    $expression =~ s{\\over}                                   {/}gismxo             ; 
    $expression =~ s{√($Number_pattern)}                       {sqrt($1)}gismxo       ; 
    $expression =~ s{e\^($Number_pattern)}                     {exp($1)}gismxo       ; 
    $expression =~ s{e\*\*($Number_pattern)}                   {exp($1)}gismxo       ; 
    $expression =~ s{e\^}                                      {exp}gismxo           ; 
    $expression =~ s{\^}                                       {**}gismxo            ; 
    $expression =~ s{\\left\(}                                 {(}gismxo             ; 
    $expression =~ s{\\right\)}                                {)}gismxo             ; 
    $expression =~ s{\\smf12}                                  {.5*}gismxo           ; 
    $expression =~ s{\\}                                       {}gismxo              ; 
    $expression =~ s{\{}                                       {(}gismxo             ; 
    $expression =~ s{\}}                                       {)}gismxo             ; 
    $expression =~ s{!}                                        {->bfac()}gisxmo      ; 
    $expression =~ s{($Number_pattern)([-+]$Number_pattern)i}  {cplx($1,$2)}gisxmo   ; 
    $expression =~ s{([-+]$Number_pattern)i}                   {cplx(0,$1)}gisxmo    ; 
    $expression =~ s{\b-i\b}                                   {cplx(0,-1)}gisxmo    ; 
    $expression =~ s{\bi\b}                                    {cplx(0,1)}gisxmo     ; 
    $expression =~ s{\|(\S+?)\|}                {abs($1)}gisxmo    ; 

    my $ans = eval $expression; 

    if ($@) {
        print "$original_line\n$expression <== $@\n";
        next;
    }

    if ($ans =~ m{\.}imsxo){        # strip trailing 0s from decimal fractions
        $ans =~ s{\.?0+\Z}{}xmiso;  # yuk!
    }
 
    print $prefix;

    if ($style eq 'tex') {
        print '$'
    }

    if ($mode eq 'replace') {
        print $ans;
    }
    else {
        if ($mode eq 'append_exact') {
            print "$original_expression = $ans";
        }
        else {
            print $original_expression;
            if ('Math::Complex' eq ref $ans) {
                my $x = Re($ans);
                my $y = Im($ans);
                if (is_whole($x) && is_whole($y)) {
                    print " = $ans";
                }
                else {
                    printf "\\simeq %g%+gi",floor($x*1e4+0.5)/1e4,floor($y*1e4+0.5)/1e4;
                }
            }
            else {
                if (is_whole($ans) || is_nice($ans)) {
                    print " = $ans";
                }
                else {
                    printf " \\simeq %.6g", $ans;
                }
            }
        }
    }

    if ($style eq 'tex') {
        print '$'
    }

    print "\n";
}

exit;

sub is_whole {
    my $n = shift;
    return $n==floor($n+0.5);
}

sub is_nice {
    my $n = shift;
    return abs($n-floor($n*1e6+0.5)/1e6)<1e-12
}


sub today {
    my $delta = shift || 0;
    my $date = DateTime->today;
    $date->add( days => $delta );
    return $date->ymd;
}

sub mean {
    my $sum = 0;
    return 0 unless @_;
    for (@_) {
        $sum += $_;
    }
    return $sum/@_;
}

#sub pi {
#    return bignum::PI()
#}

__END__





2013-06-07
2013-07-10

