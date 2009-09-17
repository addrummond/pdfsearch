#!/usr/bin/perl
use warnings;
use strict;

use common;
use File::Spec::Functions qw( splitpath catfile catdir );
use File::Temp qw ( tempfile );
use CGI;
use JSON qw( from_json );

my $cgi = new CGI;
my $qs_hash = $cgi->Vars;

if (! $qs_hash->{magic}) {
    print $cgi->header(-status => '400 Bad Request', -type =>'text/html', -encoding => 'utf-8');
    print "No magic\n";
    print STDERR "No magic.";
    exit 0;
}

if (! open(LENGTHSTORE, catfile(FILE_LENGTH_DATASTORE_DIR, $qs_hash->{magic}))) {
    print $cgi->header(-status => '400 Bad Request', -type => 'text/html', -encoding => 'utf-8');
    print "Could not open magic file\n";
    exit 0;
}
flock LENGTHSTORE, 2; # Lock exclusive (could wait indefinitely but Apache has a timeout for CGI scripts).

my $l = <LENGTHSTORE>;
die "Error reading length file" unless $l;
chomp $l;
my $json = from_json($l);
die "Error reading file lengths: '$l'" if ((! (ref($json) eq "ARRAY")) || scalar(@$json) != 2);
flock LENGTHSTORE, 8; # Release lock.
close(LENGTHSTORE) || die "Error closing length store file: $!";

print $cgi->header(-status => '200 OK', -type => 'text/html', -encoding => 'utf-8');
print "$l\n";

