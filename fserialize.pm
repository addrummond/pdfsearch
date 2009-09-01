package fserialize;

use warnings;
use strict;

require Exporter;

use vars qw(@ISA @EXPORT @EXPORT_OK);
use common;
use JSON;
use File::Spec::Functions qw( splitpath catfile catdir );

# Helper for build_tree.
sub build_tree_ {
    my $tree = shift;
    my $current = shift;
    my $depth = shift;
    my $dirs_only = shift;

    print STDERR $current, "\n";

    if ($depth > MAX_FILE_BROWSER_DIR_DEPTH) {
        return $tree;
    }

   opendir my $DIR, $current || die "Can't open $current: $!";
   while (defined(my $e = readdir($DIR))) {
        next if $e eq "." || $e eq "..";
        my $entry = catdir($current, $e);
        next if (-l $entry);

        if (-d $entry) {
            push @$tree, build_tree_([$e], $entry, $depth + 1);
        }
        elsif (-f $entry && (! $dirs_only)) {
            push @$tree, $e;
        }
    }
    closedir $DIR;

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
        my $cachefile_utime = $s2[9];

        if ($cachefile_utime >= $current_utime) { # Yuck.
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
