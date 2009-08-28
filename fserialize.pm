package fserialize;

use warnings;
use strict;

require Exporter;

use vars qw(@ISA @EXPORT @EXPORT_OK);
use common;
use JSON;
use File::Spec::Functions qw( splitpath catfile );

# Helper for build_tree.
sub build_tree_ {
    my $tree = shift;
    my $current = shift;
    my $depth = shift;
    my $dirs_only = shift;

    if ($depth > MAX_FILE_BROWSER_DIR_DEPTH) {
        return $tree;
    }

    my @entries = glob(catfile($current, "*"));
    foreach my $entry (@entries) {
        my ($vol, $dirs, $file) = splitpath($entry);
        if (-d $entry) {
            push @$tree, build_tree_([$file], $entry, $depth + 1);
        }
        elsif (-f $entry && (! $dirs_only)) {
            push @$tree, $file;
        }
    }

    return $tree;
}

# * Builds a JSON representation of a file/dir tree from a given root dir.
# * Optionally includes or does not include files as well as directories
#   (pass true value as second arg for dirs only).
# * Caches the JSON in a .JSON_DIR_CACHE directory.
sub build_tree {
    my $current = shift;
    my $dirs_only = shift;

    my $cachedir = catfile($current, ".JSON_DIR_CACHE");
    my $cachefile = catfile($cachedir, "json" . ($dirs_only ? "do" : ""));
    if (-f $cachefile) {
        my @s1 = stat($current);
        my $current_utime = $s1[9]; # Magic number...
        
        my @s2 = stat($cachefile);
#        print STDERR $cachefile, "\n";
        my $cachefile_utime = $s2[9];

#        print STDERR $cachefile_utime, " ", $current_utime, "\n\n";
        if ($cachefile_utime >= $current_utime) { # Yuck.
#            print STDERR "USING CACHE\n";
            
            local undef $/;
            open F, $cachefile;
            my $json = <F>;
            close F;
            return $json;
        }
    }

    my $json = JSON::to_json(build_tree_([$current], $current, 0, $dirs_only));
    if (! -d $cachedir) {
        if (! mkdir $cachedir) { # Ignore any errors - we just won't make the cache.
#            print STDERR "Shit!\n";
            return $json;
        }
    }
    open O, ">$cachefile";
    print O $json;
    close O;
    my $now = time;
    utime $now, $now, ($current, $cachefile); # Don't think this should be necessary, but can't hurt (can it?).

    return $json;
}

@ISA = qw( Exporter Autoloader );
@EXPORT = qw( build_tree );

1;
