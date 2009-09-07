#!/usr/bin/perl
use warnings;
use strict;

use common;
use fserialize qw( list_dir );
use File::Spec::Functions qw( splitpath catfile catdir );
use JSON qw( to_json );

my $cgi = new CGI;

my $qs_hash = $cgi->Vars;

my $dir = catdir(DOC_PATH_PREFIX, $qs_hash->{dir} ? $qs_hash->{dir} : "/");

my $tree_json = to_json(list_dir($dir) || die "Error constructing dir tree");
# We say that it's text/html to make testing in Firefox easier.
print $cgi->header(-status => "200 OK", -type => 'text/html', -encoding => 'utf-8');
print $tree_json;
