#!/usr/bin/perl
use warnings;
use strict;

use common;
use fserialize;

my $cgi = new CGI;

my $qs_hash = $cgi->Vars;

my $tree_json = fserialize::build_tree(DOC_PATH_PREFIX, $qs_hash->{dirs_only}) || die "Error constructing dir tree";
print $cgi->header(-status => "200 OK", -type => 'text/html', -encoding => 'utf-8');
print $tree_json;
