#!/usr/bin/perl 
# Toby Thurston --- 2011-08-23
#
# Filter maths lines for Vim 

use strict;
use warnings;
use bignum  ('a', 20 );         
use DateTime;

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
    $expression =~ s{π}                      {bignum::PI()}gixmso  ; 
    $expression =~ s{\\pi}                    {bignum::PI()}gismxo  ; 
    $expression =~ s{×}                      {*}gismxo             ; 
    $expression =~ s{÷}                      {/}gismxo             ; 
    $expression =~ s{\\times}                 {*}gismxo             ; 
    $expression =~ s{\\over}                  {/}gismxo             ; 
    $expression =~ s{e\^($Number_pattern)}    {exp($1)}gismxo       ; 
    $expression =~ s{e\*\*($Number_pattern)}  {exp($1)}gismxo       ; 
    $expression =~ s{e\^}                     {exp}gismxo           ; 
    $expression =~ s{\^}                      {**}gismxo            ; 
    $expression =~ s{\\left\(}                {(}gismxo             ; 
    $expression =~ s{\\right\)}               {)}gismxo             ; 
    $expression =~ s{\\smf12}                 {.5*}gismxo           ; 
    $expression =~ s{\\}                      {}gismxo              ; 
    $expression =~ s{\{}                      {(}gismxo             ; 
    $expression =~ s{\}}                      {)}gismxo             ; 
    $expression =~ s{!}                       {->bfac()}gisxmo      ; 

    my $ans = eval $expression; 

    if ($@) {
        print "$original_line\n$expression <-- $@\n";
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
            my $rounded = sprintf "%.6f", $ans;
            my $int     = int($ans);
            print $ans == $int     ?  " = $int"
                : $ans == $rounded ?  " = $ans"
                :               " \\simeq $rounded";
        }
    }

    if ($style eq 'tex') {
        print '$'
    }

    print "\n";
}

exit;

sub today {
    my $delta = shift || 0;
    my $date = DateTime->today;
    $date->add( days => $delta->numify );
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

sub pi {
    return bignum::PI()
}

__END__
