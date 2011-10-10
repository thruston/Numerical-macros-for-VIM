#!/usr/bin/perl 
#
# A filter to line up tables neatly - mainly for use from Vim
#
# 1. Read the data from stdin into a "table" object
# 2. Munge the table according to the supplied list of verbs+options
# 3. Print the table out again to stdout
#
# Usage: table delim verb [options] verb [options] ...
#
# Delimiter either specified or worked out from context if omitted
# Normally just '  ' but in tex: & and \cr; in latex & and \\; in HTML etc...
#
# Verbs: xp              transpose rows and cells
#        sort col        sort by value of column, use UPPERCASE to reverse
#        add function    add sum, mean, var, sd etc to foot of column
#        arr col-list    rearrange/insert/delete cols or functions on cols.
#        dp dp-list      round numbers is each col to specified decimal places
#        reshape wide | long   reshape table (for R etc)
#        make tex | latex | plain   output in tex etc form
#        label           label columns with letters
#
# For full documentaion read (or better still extract) the POD at the end
#
# Toby Thurston -- 27 Sep 2011

use strict;
use warnings;
use feature "switch";
use bignum  ('p', -12);         # nice rounding to 12 places
use Statistics::Descriptive;    # used for add functions
use List::Util qw(min max sum);   
use POSIX      qw(floor ceil);
use Time::HiRes qw( gettimeofday tv_interval );

my $DEBUG = 0;

# following Cowlishaw, TRL p.136
#                     sign?    mantissa------>     exponent? 
my $Number_atom = qr{ [-+]? (?:\d+\.\d*|\.?\d+) (?:E[-+]?\d+)? }ixmso;
my $Number_pattern   = qr{\A $Number_atom \Z}ixmso;
my $Interval_pattern = qr{\A\( ( $Number_atom ) \, ( $Number_atom ) \)\Z}ixsmo;
my $Date_pattern     = qr{\A (\d+)-?(\d\d)-?(\d\d) \Z}ixmso; # make groups capture
my $Hrule_pattern    = qr{\A -+ \Z}ixmso; # just a line of --------------

my %Action_for = (
    xp      => \&transpose,
    sort    => \&sort_rows_by_column,
    add     => \&add_totals,
    arr     => \&arrange_cols,
    make    => \&set_output_form,
    gen     => \&append_new_rows,
    dp      => \&round_cols,
    label   => \&add_col_labels,
    reshape => \&reshape_table,
);

# deal with the command line
my @agenda = ();
while (@ARGV) {
    push @agenda, split q{ }, shift @ARGV;
}

my $delim = @agenda ? shift @agenda : 2;
my $separator;

if ($delim =~ /\A[1-9]\Z/xms) {
    $separator = q{ } x $delim; 
    $delim = qr/\s{$delim,}/xms;
}
elsif (exists $Action_for{lc $delim}) {
    unshift @agenda, $delim;
    $separator = q{  };
    $delim = qr/\s{2,}/xms;
}
else {
    $separator = qq{$delim };
    $delim     = qr/$delim/xms;
}

my $indent = 0;
my $eol_marker = q{};

my $start_time = [ gettimeofday ];
my @time_messages = ();

# read the data from stdin
my @input_lines = <>;

if (@input_lines) {
    chomp(@input_lines);

    # find the clear margin of blank space to the left of the table, ignoring any completely blank lines
    $indent = min( map { /^(\s*)\S/; length($1) } grep { !/^\s*$/ } @input_lines );

    # recognize TeX and LateX delims automatically
    if ($input_lines[0] =~ /\&.*(\\cr|\\\\) \s* \Z/xms) {
        $eol_marker = $1;
        $delim = qr/\s*\&\s*/xms;
        $separator = ' & ';
    }
}

push @time_messages, sprintf "Read: %d ms\n", int(0.5+1000*tv_interval($start_time));

# split the input lines into cells in $table->{data}
my $table = { rows => 0, cols => 0 };
for (@input_lines) {
    s/^\s*//; # remove leading space
    s/\s*$//; # remove trailing space
    s/\t/  /g; # remove tabs 
    if ( $eol_marker ne q{} ) {
        $_ =~ s/\s*\Q$eol_marker\E\s*//iox;
    }
    if ( /^$/ || /$Hrule_pattern/ || /^\\noalign/ || /^\\intertext/ || /^\#/ ) {
        push @{$table->{specials}->[$table->{rows}]}, $_; 
        next;
    }
    my @cells = split $delim; 
    push @{$table->{data}}, \@cells ;
    $table->{rows}++;   
    $table->{cols} = max($table->{cols},scalar @cells);
}
push @time_messages, sprintf "Split: %d ms\n", int(0.5+1000*tv_interval($start_time));

# work through the list of verbs
while (@agenda) {
    my $verb   = lc shift @agenda;
    my $option = @agenda ? shift @agenda : undef;
    if ( exists $Action_for{lc $option}) {
        unshift @agenda, $option;
        $option = undef;
    }
    if ( exists $Action_for{$verb} ) {
        $table = $Action_for{$verb}->($table,$option)
    }
}

push @time_messages, sprintf "Verbs: %d ms\n", int(0.5+1000*tv_interval($start_time));

# FIXME check to see if header is all text and one cell short
# then shove it over to the right by one (like a data.frame for R)

# work out the widths and alignments
my @widths = (0) x $table->{cols};
my @aligns = (0) x $table->{cols};
for (my $c=0; $c<$table->{cols}; $c++ ) {
    for (my $r=0; $r<$table->{rows}; $r++ ) {
        next unless defined $table->{data}->[$r][$c];
        $widths[$c] = max($widths[$c], length $table->{data}->[$r][$c]);
        if ( $table->{data}->[$r][$c] =~ $Number_pattern ) {
            $aligns[$c]++;
        }
        else {
            $aligns[$c]--;
        }
    }
}

my $table_width = sum(0,@widths) + length($separator) * ($table->{cols}-1);

for (my $c=0; $c<$table->{cols}; $c++ ) {
    $widths[$c] *= -1 if $aligns[$c] < 0;
}

push @time_messages, sprintf "Widths: %d ms\n", int(0.5+1000*tv_interval($start_time));

# print the table to stdout
for (my $r=0; $r<$table->{rows}; $r++ ) {
    if ( exists $table->{specials}->[$r] ) {
        for my $special_line ( @{$table->{specials}->[$r]} ) {
            print q{ } x $indent;
            if ($special_line =~ $Hrule_pattern) {
                if ($eol_marker eq '\\cr') {
                    print '\\noalign{\\vskip2pt\\hrule\\vskip4pt}' ; # auto convert ---- to tex rule
                }
                else {
                    print '-' x $table_width; # expand or shrink -------- lines
                }
            }
            else {
                print $special_line;
            }
            print "\n";
        }
    }
    my $out = q{ } x $indent;
    for (my $c=0; $c<=$#{$table->{data}->[$r]}; $c++ ) {
        if (defined $table->{data}->[$r][$c]) {
            $out .= sprintf "%*s", $widths[$c], $table->{data}->[$r][$c];
        }
        $out .=  $separator;
    }
    $out =~ s/$separator\Z/ $eol_marker/;
    print $out, "\n";
}

push @time_messages, sprintf "Total: %d ms\n", int(0.5+1000*tv_interval($start_time));
print @time_messages if $DEBUG;
exit;

sub set_output_form {
    my ($tab, $form_name) = @_;
    given($form_name) {
        when("tex")   { $separator = ' & '; $eol_marker = '\\cr' }
        when("latex") { $separator = ' & '; $eol_marker = '\\\\' }
        when("debug") { $separator = ' ! '; $eol_marker = '<<'   }
        default       { $separator = q{  }; $eol_marker = q{}    }
    }
    return $tab;
}

sub transpose {
    my ($tab) = @_;
    my @transposed_tab;
    for my $row (@{$tab->{data}}) {
        for my $i (0 .. $tab->{cols}-1) {
            push(@{$transposed_tab[$i]}, $row->[$i] );
        }
    } 
    $tab->{data} = \@transposed_tab;
    @$tab{'rows','cols'} = @$tab{'cols','rows'}; 

    return $tab;
}

# Sort by column.  Create an extra temp col with "arr" for fancy sorting.
sub sort_rows_by_column {
    my ($tab, $col) = @_;

    my $reverse = 0;
    given($col) {
        when (undef)     { $col = 0 }
        when (/^[a-z]$/) { $col = ord($col)-ord('a') }
        when (/^[A-Z]$/) { $col = ord($col)-ord('A'); $reverse++ }
        when (/^\d+$/)   { $col -= 1 } # 0 indexed
        when (/^-\d+$/)  { $col = $table->{cols}+1+$col }
        default          { $col = 0 }
    }
   
    # check bounds 
    $col = $col >= $tab->{cols} ? $tab->{cols}-1
         : $col <  0            ? 0
         :                        $col;
    
    my @sorted;

    if ($reverse) {
        @sorted = map  { $_->[0] }
                  sort { $b->[1] <=> $a->[1] || $b->[2] cmp $a->[2] } 
                  map  { [$_, as_number_reversed($_->[$col]), uc($_->[$col])] } @{$tab->{data}};
    }
    else {
        @sorted = map  { $_->[0] }
                  sort { $a->[1] <=> $b->[1] || $a->[2] cmp $b->[2] } 
                  map  { [$_, as_number($_->[$col]), uc($_->[$col])] } @{$tab->{data}};
    }

    $tab->{data} = \@sorted;
    return $tab;
    
}

sub as_number {
    my ($s) = @_;
    return 1e9 unless defined $s;
    return $s if $s =~ $Number_pattern;
    return -1e9;
}

sub as_number_reversed {
    my ($s) = @_;
    return -1e9 unless defined $s;
    return $s if $s =~ $Number_pattern;
    return 1e9;
}

sub add_col_labels {
    # add a row of labels for each column
    my ($tab) = @_;
    my $label = 'a';
    my @labels = ();
    for (1..$tab->{cols}) {
        push @labels, $label++;
    }
    $tab->{rows} = unshift @{$tab->{data}}, [ @labels ];
    return $tab;
}

sub add_totals {
    # Add values of function to bottom of cols
    my ($tab, $expr) = @_;
    given($expr) {
        when (undef) { $expr = 'sum' }
        when ("var") { $expr = 'variance' }
        when ("sd")  { $expr = 'standard_deviation' }
    }

    my @new_stats_row = ();
    my $stat = Statistics::Descriptive::Full->new();

    for (my $c = 0; $c < $tab->{cols}; $c++ ) {
        $stat->clear();
        for (my $r = 0; $r < $tab->{rows}; $r++ ) {
            my $s = $tab->{data}->[$r][$c];
            if (defined $s && $s =~ $Number_pattern) {
                $stat->add_data($s);
            }
        }
        my $value = $expr;
        if ( $stat->count > 0 ) {
            if ( $expr =~ m{\A([a-z_]+)\((\d+)\)\Z}ixmso ) {
                $value = $stat->$1($2);
            }
            else {
                $value = $stat->$expr;
            }
        }

        push @new_stats_row, $value;
    }
    push @{$tab->{data}}, [ @new_stats_row ];
    $tab->{rows}++;
    return $tab
}

sub append_new_rows {
    my ($tab, $sequence) = @_;
    $sequence =~ s/:/../xims;
    for my $n (eval $sequence ) {
        push @{$tab->{data}}, [ ($n) ];
        $tab->{rows}++;
    }
    $tab->{cols}++;
    return $tab
}

sub reshape_table {
    my ($tab, $direction) = @_;
    
    return $tab if $tab->{cols}<3; # do nothing on thin tables
    
    given($direction) {
        when ("long") { return make_long_table($tab) }
        when ("wide") { return make_wide_table($tab) }
        default {
            if ($tab->{cols}==3) { return make_wide_table($tab) } 
            return make_long_table($tab)
        }
    }

    return $tab;
}

sub make_long_table {
    my ($tab) = @_;
    
    my @long_tab = ();
    my $header_row = shift @{$tab->{data}};

    push @long_tab, [ ($header_row->[0], 'Key', 'Value') ];

    for my $row ( @{$tab->{data}} ) {
        my $group_value = $row->[0];
        for my $i (1..(@$row-1) ) {
            push @long_tab, [ ( $group_value, $header_row->[$i], $row->[$i] ) ]; 
        }
    }

    $tab->{data} = \@long_tab;
    $tab->{rows} = scalar @long_tab;
    $tab->{cols} = 3;
    return $tab;
}

sub make_wide_table {
    my ($tab) = @_;

    my $header_row = shift @{$tab->{data}};

    my %values = ();
    my @keys = ();
    my %seen = ();
    for my $row ( @{$tab->{data}} ) {
        my ($x, $y, $value) = @$row;
        $values{$x}{$y} = $value;
        push @keys, $y unless $seen{$y}++;
    }

    my @wide_tab = ();
    push @wide_tab, [ ($header_row->[0], @keys) ];
    for my $x ( sort keys %values ) {
        my @row = ( $x );
        for my $y ( @keys ) {
            push @row, $values{$x}{$y}
        }
        push @wide_tab, [ @row ];
    }

    $tab->{data} = \@wide_tab;
    $tab->{rows} = scalar @wide_tab;
    $tab->{cols} = 1 + scalar @keys;
    return $tab;

}


sub round_cols {
    my ($tab, $dp_string) = @_;

    # no-op unless we have a string of numbers
    return $tab unless defined $dp_string && $dp_string =~ m{\A \d+ \Z}xims;

    # extend short string by repeating last digit
    my $ldp = length($dp_string);
    if ($ldp < $tab->{cols}) {
        $dp_string .= substr($dp_string, -1) x ($tab->{cols}-$ldp);
    }

    for my $row (@{$tab->{data}}) {
        my $i = 0;
        for my $cell (@{$row}) {
            my $dp = substr $dp_string, $i++, 1;
            next if !defined $cell;
            if ( $cell =~ $Number_pattern ) {
                $cell = sprintf "%.${dp}f", $cell;
            }
            elsif ( $cell =~ $Interval_pattern ) {
                $cell = sprintf "(%.${dp}f,%.${dp}f)", $1, $2;
            }
        }
    }
    return $tab;
}

sub arrange_cols {
    my ($tab, $permutation) = @_;
    return $tab unless $permutation;
    
    for (my $r = 0; $r < $tab->{rows}; $r++ ) {
        my $new;
        my %value_for = ();
        if ($permutation =~ /\{/) {
            my $key = 'a';
            for (my $c=0; $c<$tab->{cols}; $c++ ) {
                my $value = $tab->{data}->[$r]->[$c];
                given($value) {
                    when (/$Number_pattern/ && $value<0 ) { $value = "($value)" }
                    when (/$Date_pattern/)                { $value = "'$value'" }          
                }
                $value_for{$key++} = $value;
            }
        }
        for my $m ( $permutation =~ m{[a-z1-9#?]|\{.*?\}}gxmso ) {
            my $value;
            given($m) {
                when (/^[a-z]$/) { $value = $tab->{data}->[$r]->[ord($m)-ord('a')] }
                when (/^[1-9]$/) { $value = $tab->{data}->[$r]->[$m-1] }
                when (q{#})      { $value = $r }
                when (q{?})      { $value = rand()-0.5 }
                default {
                    # strip {} from expr
                    $m =~ s/^\{//; $m =~ s/\}$//;
                    # substitute cell values (and don't bother checking for out of range letters)
                    $m =~ s/\b([a-z])\b/$value_for{$1}/g; 
                    # evaluate & replace answer with expression on error
                    $value = eval $m; $value = $m if $@;
                }
            }
            push @$new, $value;
        }
        $tab->{data}->[$r] = $new;
    }
    $tab->{cols} = scalar @{$tab->{data}->[0]};
    return $tab;
}

# Day of the week from base
sub dow {
    my ($base) = @_;
    if ($base =~ $Date_pattern ) {
        $base = base($base);
    }
    if ($base =~ $Number_pattern) {
        # Note that in Perl % always gives an integer even if base is a float
        return qw(Mon Tue Wed Thu Fri Sat Sun)[$base%7]  
    }
    return "DoW($base)";
}

# Convert yyyy-mm-dd to base date assuming Gregorian calendar rules
sub base {
    my ($date) = @_;
    my ($y,$m,$d);
    if (!defined $date || $date eq q{}) {
        (undef, undef, undef, $d, $m, $y) = localtime ;
        $y += 1900;
        $m -= 2;
    }
    elsif ($date =~ $Date_pattern ) {
        ($y, $m, $d) = ($1, $2, $3);
        $m -=3;
    } 
    else {
        return "Base($date)";
    }
    while ($m<0)  { $y-=1; $m+=12 }
    while ($m>11) { $y+=1; $m-=12 }
    my $base=365*$y + floor($y/4) - floor($y/100) + floor($y/400) + floor(.4+.6*$m) + 30*$m + $d - 307;
    return $base;
}

# Gregorian-ymd:  returns "y m d" from a base number according
# to normal Gregorian calendar rules.  Like date('s',base,'b')
# but allows for negative base numbers, and returns y m d as a
# list.
sub date {
    my ($d) = @_;
    my ($y, $m) = (0,0);
    $d = floor($d);
    my $s = floor($d/146097); $d=$d-$s*146097;
    if ($d == 146096) { ($y, $m, $d) = ($s*400+400, 12, 31) } # special case 1
    else {
        my $c=floor($d/36524); $d=$d-$c*36524;
        my $o=floor($d/1461);  $d=$d-$o*1461;
        if ( $d==1460) { ($y, $m, $d) = ($s*400+$c*100+$o*4, 12, 31) } # special case 2
        else {
            $y=floor($d/365); $d=$d-$y*365+1; # d is now in range 1-365
            my @prior_days = ( $y==3 && ( $o < 24 || $c == 3 ) )
                ? (0, 31, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335, 999)
                : (0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334, 999);
            while ( $prior_days[$m] < $d) {
                $m++;
            }
            $d = $d - $prior_days[$m-1];
            $y = $s*400+$c*100+$o*4+$y+1;
        }
    }
    return sprintf "%d-%02d-%02d", $y, $m, $d;
}

__END__

=head1 NAME 

Table --- a filter to line up tables nicely

This filter is primarily intended to be used as an assitant for the Vim editor.  The
idea is that you create a Vim command that calls table.pl on a marked area in your file
which is then replaced with the (improved) output of table.pl. It also works as a
simple command line filter.  The details of setting up Vim are explained below.

=head2 Motivation

If your work involves editing lots of plain text you will get familiar with a plain
text editor such as Vim or Emacs or similar. You will get familiar with the
facilities for arranging code and paragraphs of plain text.  Eventually you will
need to create a table of data or other information, something like this

      event  eruption  waiting 
          1     3.600       79 
          2     1.800       54 
          3     3.333       74 
          4     2.283       62 
          5     4.533       85 

and you may find that your editor has some useful facilities for working in "block"
mode that help to manage the table.  But you might also find that the facilities are
just a little bit limited.   You want to know the totals of each column, but you
really didn't want to load the data into a spreadsheet or a statistics system like
R; you just want the simple totals.   That's what table.pl is for.  Calling ":Table add"
creates this:

      event  eruption  waiting 
          1     3.600       79 
          2     1.800       54 
          3     3.333       74 
          4     2.283       62 
          5     4.533       85 
         15    15.549      354 

OK, that's not perfect, but all you have to do now is change that 15 to "Sum" (or just
undo the last change to get rid of the new line).  Table.pl also  
lets you transpose a table (to get this...)

      event         1      2      3      4      5 
      eruption  3.600  1.800  3.333  2.283  4.533 
      waiting      79     54     74     62     85 

as well as sort by any column in the table, rearrange the columns, delete columns,
or add new columns computed from the others.  It can't do everything you can do in a
spreadsheet but it can do most of the simple things, and you can use it right in the
middle of your favourite editor. 

=head2 Design

The overall flow is as follows

1. Deal with the command line in a nice flexible way.  

2. Read <STDIN> and parse each line into a row of table cells.

3. Update the table according to the verbs given on the command line.

4. Work out the widths and alignments for each column in the finished table.

5. Print the table neatly to <STDOUT>

Steps 4 and 5 tend to be the slowest.  Note that you don't have to supply any verbs; 
so in this case step 3 takes no time at all, and the default action is therefore just 
to line up your table neatly.  Text columns are aligned left, numeric columns aligned right.

=head1 USAGE 

=head2 Use from the command line

You are unlikely to want to do this much, but try something like this

   cat somefile.txt | perl table.pl xp sort xp    # or whatever verbs you want

=head2 Setting up a Table command in Vim

Add a line like the following to your ".vimrc" file.

    :command! -nargs=* -range=% Table <line1>,<line2>!perl ~/perl/table.pl <q-args>

which you should adjust appropriately so your perl can find where you put table.pl.
You can of course use some word other than "Table" as the command name. Take your pick, 
except that Vim insists on the name starting with an uppercase letter. 

With this definition, when you type ":Table" in normal mode in Vim, it will call table.pl
on the current area and replace it with the output.  If you are in Visual Line mode then
the current area will just be the marked lines.  If you are in Normal mode then the current
area will be the whole file.  

From now on, I'm assuming you are using a Vim :Table command to access table.pl

=head2 Use from within VIM or GVim or MacVim, etc 

    :Table [delimiter] [verb [option]]...

Use blank to separate the command line: the delimiter argument and any verbs or options must be 
single blank-separated words.  Any word that looks like a verb will be treated as a verb, even
if you meant it to be an option.  See below for details.

The delimiter is used to split up each input line into cells.  It can be any string or regular
expression that's a valid argument to the perl C<split> function.  Except one containing blanks
or a whole number between 0 and 9.  You can't use blanks (even inside quotes) because of the 
simple way that I split up the command line, and so I use whole numbers to mean "split on at least
that many consecutive blanks" so if you use 1 as an argument the line will be split on every 
blank space, and so on. The default argument is 2.  This means the line will be split at every occurrence
of two or more blanks.  This is generally what you want.  Consider this example.

    Item          Amount 
    First label       23 
    Second thing      45 
    Third one         55 
    Total            123 

In most circumstances you can just leave the delimiter out and let it default to two or more spaces.
Incidentally, any tab characters in your input are silently converted to double spaces before parsing.

After the optional delimiter you should specify a sequence of verbs.  If the verb needs an option then
that goes right after the verb.  Verbs and options are separated by blanks.  The parsing is very simple.
If it looks like a verb it's treated as one.  If it doesn't, it's assumed to be an option.  Anything
not recognized is just silently ignored.

=head1 DESCRIPTION

=head2 Verbs

In all the examples below you need to prefix the command with ":Table".  You can string 
together as many verbs (plus optional arguments) as you like. 

=over

=item xp - transpose the table

C<xp> just transposes the entire table. It takes no options.  

    First   100 
    Second  200     
    Third   300 

becomes    

    First  Second  Third 
      100     200    300 

It's often useful in combination with verbs that operate on columns like C<sort> or C<add>.
So the sequence "xp add xp" will give you row totals, for example.

=item add [sum|mean|sd|var|...] - insert the sum|mean|etc at the bottom of a column

C<add> adds the total to the foot of a column.  Or the mean, standard deviation, variance, etc.
The optional argument can be any valid method for a Statistics::Descriptive::Full object.  If you omit
the optional argument it defaults to "sum".   If you put "sd" it will be expanded to "standard_deviation",
similarly "var" is expanded to "variance".   

Non-numerical entries in a column are simply ignored.   

=item sort [a|b|c|...] - sort on column a|b|etc

C<sort> sorts the table on the given column.  "a" is the first, "b" the second, etc.
If you use upper case letters, "A", "B", etc the sort direction is reversed.

You can also use numbers, so "sort 2" sorts on the second column, while
"sort 99" will sort on the last one (assuming there are fewer than 100 columns).
Like perl index addressing "sort -1" means sort on the last column, "sort -2" last but one etc.
NB *unlike* perl index addressing, "sort 1" sorts the first column not the second. 
(but "sort 0" also sorts on the first column...).  Because sorting is stable in perl, then
if you want to sort on column b then column a, you can do "sort a sort b" to get the desired
effect. 

=item arr [arrange-expression] - rearrange the columns 

At it simplest C<arr> lets you rearrange, duplicate, or delete columns.  So if you have a
four column table then: 

=over

=item * 

"C<arr dabc>" puts the fourth column first

=item *

"C<arr aabcd>" duplicates the first column

=item *

"C<arr cd>" deletes the first two columns

=back

and so on. The syntax admittedly is a little unwieldy with large numbers of columns, 
so you might find it easier to transpose the table first with "xp" and then 
use the regular line editing facilities in Vim to rearrange the rows, before
transposing them back to columns.   You might also use the C<label> verb 
to add alphabetic labels to the top of all the columns before you start.

Note: Astute readers may spot a problem here.  The sequence "arr add" meaning 
"delete cols b and c and duplicate col d" won't work because "add" is a 
valid verb.  In this case (as similar ones) just put a pair of empty braces
on the end, like so "arr add{}".

Besides letters to identify column values you can use "?" to insert a random number,
and "#" to insert the row number.

You can also insert arbitrary calculated columns by putting an expression in curly braces.

=over

=item * 

"C<arr ab{a+b}>" adds a new column that contains the sum of the values in the first two

=item *

"C<arr a{a**2}{sqrt(a)}>" adds two new cols with square and square root of the value in col 1.

=back

and so on.  Each single letter "a", "b", etc is changed into the corresponding
cell value and then the resulting expression is evaluated. You can use any normal Perl function:
sin, cos, atan2, sqrt, log, exp, int, abs, and so on.  You can also use min, max (from List::Util)
and floor and ceil from POSIX.  

There are also some very simple date routines included.  C<base> returns the number of days
since 1 Jan in the year 1 (assuming the Gregorian calendar extended backwards).  The argument 
should be blank for today, or in the form "yyyy-mm-dd".  C<date> does the opposite: given
a number that represents the number of days since the year dot, it returns the date in "yyyy-mm-dd" form.
There's also C<dow> which takes a base number and returns the day of the week, as a three letter string.

So given a table with a column of dates, like this

    2011-01-17  
    2011-02-23  
    2011-03-19  
    2011-07-05  

the command "arr a{dow(base(a))}" creates this

    2011-01-17  Mon 
    2011-02-23  Wed 
    2011-03-19  Sun 
    2011-07-05  Wed 


=item dp [nnnnn...] - round numbers to n decimal places

As delivered table.pl calculates with 12 decimal places, so you might need to round your answers a bit.
This is what C<dp> does.  The required argument is a string of digits indicating how many decimal places
between 0 and 9 you want for each column.  There's no default, it just does nothing with no argument, but
if your string is too short the last digit is repeated as necessary.  So to round everything to a whole number
do "dp 0".  To round the first col to 0, the second to 3 and the rest to 4 do "dp 034", and so on. 

=item make [plain|tex|latex] - set the output format

C<make> sets the output format.   Normally this happens automagically, but if, for example, you want to separate
your input data by single spaces, you might find it helpful to do ":Table 1 make plain" to line everything up
with the default two spaces.   Or you might want explicitly to make a plain table into TeX format.

Note that this only affects the rows, it won't magically generate the TeX or LaTeX table preamble.

=item reshape [long|wide] - expand or condense data tables for R

This is used to take a square table and make it a long one.  It's best explained with an example.

Consider the following table.

    Exposure category     Lung cancer  No lung cancer 
    Asbestos exposure               6              51 
    No asbestos exposure           52             941 

Nice and compact, but the values are in a 2x2 matrix rather than a useful column.  Sometimes you want
them to look like this.

    Exposure category     Key             Value 
    Asbestos exposure     Lung cancer         6 
    Asbestos exposure     No lung cancer     51 
    No asbestos exposure  Lung cancer        52 
    No asbestos exposure  No lung cancer    941 

And that's what "reshape long" does.  Here's another example.

    Region      Quarter     Sales
    East        Q1          1200
    East        Q2          1100
    East        Q3          1500
    East        Q4          2200
    West        Q1          2200
    West        Q2          2500
    West        Q3          1990
    West        Q4          2600

With this input, "reshape wide" gives you this

    Region    Q1    Q2    Q3    Q4 
    East    1200  1100  1500  2200 
    West    2200  2500  1990  2600 

Notice that parts of the headings may get lost in transposition. 

=item label - add alphabetic labels to all the columns

C<label> simply adds an alphabetic label at the top of the 
columns to help you work out which is which when rearranging.

=back

=head2 Special rows

Any blank lines in your table are saved as special lines and reinserted at the 
appropriate place on output. So if you have a long table you can use blanks
to separate blocks of data.  Similarly any lines consisting entirely of "-" characters
are treated as horizontal rules and reinserted (appropriately sized) on output. 
Any lines starting with "#" are treated as comment lines, and again reinserted in the 
right places on output. 

=head2 Support for TeX and LaTeX

C<table.pl> also supports tables neatly in TeX and LaTeX documents. 
To convert a plain table to TeX format use "make tex".  If you already have 
a TeX table then C<table.pl> automatically spots the TeX delimiters "&" and "\cr",
and puts them back in when it formats the output. Everything else works as described above.
If you convert from plain to TeX format, then any horizontal rules will be converted 
to the appropriate bit of TeX input to get a neat output rule.    

=head1 REQUIRED ARGUMENTS

None.  The default with no arguments is just to line up your table neatly.

=head1 OPTIONS

See the detailed description of the verbs and options in the L<DESCRIPTION> section above.

=head1 DIAGNOSTICS

Some errors will generate extra lines in the output, explaining what went wrong. 
You can always get rid of them and back to a known postion by using the editor undo command. 

=head1 EXIT STATUS

Not set. 

=head1 CONFIGURATION

None.

=head1 DEPENDENCIES

Perl 5.10 or better (for "use feature switch").

Note that you don't actually need VIM compiled with Perl support, table.pl works entirely as an 
external filter. 

=head1 INCOMPATIBILITIES

Largely *because* it works as an external filter, table.pl is not very "Vim-like", so died-in-the-wool
Vim users may prefer other facilities for playing with columns of data. 

=head1 BUGS AND LIMITATIONS

Probably plenty, because I've not done very rigorous testing.

=head1 AUTHOR

Toby Thurston -- 10 Oct 2011 

=head1 LICENSE AND COPYRIGHT

Same terms as Perl and VIM.  Free to use, but not to pass off as your own.  
No warranty expressed or implied.

=cut
