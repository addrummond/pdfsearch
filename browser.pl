#!/usr/bin/perl
use warnings;
use strict;

use common;

my $cgi = new CGI;

my $qs_hash = $cgi->Vars;
my $tt = new Template({ INCLUDE_PATH => TEMPLATES_DIR, INTERPOLATE => 1 }) || die "$Template::ERROR\n";

print $cgi->header(-status => "200 OK", -type => 'text/html', -encoding => 'utf-8');
$tt->process("browser.html", { path => $qs_hash->{path} ? $qs_hash->{path} : "", url_prefix => URL_PREFIX });
