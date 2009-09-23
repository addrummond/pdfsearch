package fserialize;

use warnings;
use strict;

require Exporter;

use vars qw(@ISA @EXPORT @EXPORT_OK);
use common;
use File::Spec::Functions qw( splitpath catfile catdir );
use File::stat;

sub list_dir {
    my $dir = shift;

    opendir my $DIR, $dir || return 0;
    my @entries;
    while (defined(my $e = readdir($DIR))) {
        next if $e =~ /^\./;
        my $fn = catfile($dir, $e);
        my $size = stat($fn)->size || die "Error stat'ing file.";
        my $created = stat($fn)->ctime || die "Error stat'ing file.";
        my $modified = stat($fn)->mtime || die "Error stat'ing file.";
        # 1 = dir, 0 = file.
        push @entries, [ -d $fn ? 1 : 0, $e, $size, $created, $modified ];
    }
    closedir($DIR) || die "Error closing dir: $!";

    return \@entries;
}

@ISA = qw( Exporter Autoloader );
@EXPORT = qw( list_dir );

1;
