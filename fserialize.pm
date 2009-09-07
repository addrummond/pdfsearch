package fserialize;

use warnings;
use strict;

require Exporter;

use vars qw(@ISA @EXPORT @EXPORT_OK);
use common;
use File::Spec::Functions qw( splitpath catfile catdir );

sub list_dir {
    my $dir = shift;

    opendir my $DIR, $dir || return 0;
    my @entries;
    while (defined(my $e = readdir($DIR))) {
        next if $e =~ /^\./;
        # 1 = dir, 0 = file.
        push @entries, [ -d catfile($dir, $e) ? 1 : 0, $e ];
    }
    closedir($DIR) || die "Error closing dir: $!";

    return \@entries;
}

@ISA = qw( Exporter Autoloader );
@EXPORT = qw( list_dir );

1;
