#!/usr/bin/perl
use warnings;
use strict;

use common;
use fserialize qw( list_dir );
use File::Spec::Functions qw( splitpath catfile catdir );

my $cgi = new CGI;
my $dir = $cgi->param('dir');
my $file = $cgi->param('userfile');
my ($vol, $remdir, $fname) = splitpath($file);
print STDERR "FFF: $file", "\n";

# Santize the directory and file names.
if ($dir =~ /\.\./ || $fname =~ /\\|\/|(?:\.\.)/) {
    print $cgi->header(-status => '400 Bad Request', -type => 'text/html', -encoding => 'utf-8');
    print 'Error: filename cannot contain "\\", "/" or ".."\n';
    exit 0;
}

# TODO TODO: To be really secure, we should probably check that none of the directories in the path
# are symlinks (the ".." link is obviously the main security risk, but in principle there could be
# other symlinks leading outside the locker dir).

my $newf;
eval {
    my $localname = catfile(DOC_PATH_PREFIX, $dir, $fname);

    if (-f $localname || -d $localname) {
        print $cgi->header(-status => '400 Bad Request', -type => 'text/html', -encoding => 'utf-8');
        print 'Error: a file of that name already exists in this directory.\n';
        exit 0;
    }

    open($newf, ">$localname") || die "Could not open file '$localname' on server for upload: $!";
    binmode $newf || die "Error switching to binary mode: $!";
    my ($bytes, $n);
    while (((defined ($n = sysread($file, $bytes, 10000))) || die "Error reading file uploaded: $!") && $n > 0) {
        my $nr = syswrite $newf, $bytes;
        last if ($nr == 0);
        die "Error writing to file on server for upload: $!" if (! defined($nr));
    }
    close $newf;

    print $cgi->header(-status => "200 OK", -type => 'text/html', -encoding => 'utf-8');
    print "\n";
};
if ($@) {
    unlink $newf;
    close $newf;
    die $@;
}

