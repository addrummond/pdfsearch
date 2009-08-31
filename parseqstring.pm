package parseqstring;

use warnings;
use strict;

require Exporter;

use vars qw(@ISA @EXPORT @EXPORT_OK);
use common;

# Returns a (reference to a) list of strings which the user wants to find
# (ignores AND, OR and terms preceded by -).
sub parse_qstring {
    my $qstring = shift;

    my $inquote = 0;
    my $inminus = 0;
    my $currentword = "";
    my @words;

    my $resetvs = sub { # Doing it this way so it closes over outer vars
        push @words, $currentword if ! $inminus;
        $currentword = "";
    };

    for (my $i = 0; $i < length($qstring); ++$i) {
        my $c = substr($qstring,$i,1);
        if ($c eq '"' || $c eq "'") {
            &$resetvs;
            $inminus = 0 if $inquote;
            $inquote = ! $inquote;
        }
        elsif ($c eq "-") {
            &$resetvs;
            $inminus = 1;
            $inquote = 0;
        }
        elsif ($c =~ /\s/) {
            if ($inquote) {
                $currentword .= $c;
            }
            else {
                &$resetvs;
                # Leaving $inminus alone...
            }
        }
        else {
            $currentword .= $c;
        }
    }
    push @words, $currentword if ! $inminus;

    return \@words;
}

sub re_for_strings { 
    my $strings = shift;

    my @res;
    for my $string (@$strings) {
        my $re = "(";
        for (my $i = 0; $i < length($string); ++$i) {
            my $c = substr($string, $i, 1);
            $re .= sprintf("\\x%x", ord($c)); # Saves escaping.
        }
        $re .= ")";
        push @res, $re;
    }

    return join "|", @res;
}

@ISA = qw( Exporter Autoloader );
@EXPORT = qw( parse_qstring re_for_strings );

1;
