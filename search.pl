#!/usr/bin/perl
use warnings;
use strict;

use SWISH::API;
use common;
use File::Spec::Functions qw(catfile catdir splitpath);
use PDF;
use Encode qw(decode);
use Encode::Guess;
use JSON;

sub guessenc {
    my $s = shift(@_);
    if ($s) {
        my $decoder = Encode::Guess->guess($s);
        if (ref($decoder)) { $decoder->decode($s); }
        else { $s; }
    }
    else { $s; }
}

sub trunc {
    my ($vol, $dirs, $s) = File::Spec::Functions::splitpath(shift);
    if (length($s) > MAX_TITLE_LENGTH_BEFORE_TRUNCATION) {
        return substr($s, 0, MAX_TITLE_LENGTH_BEFORE_TRUNCATION - 6) . ".." . substr($s, -4);
    }
    $s;
}

my $cgi = new CGI;
my $qs_hash = $cgi->Vars;

my $tt = new Template({ INCLUDE_PATH => TEMPLATES_DIR, INTERPOLATE => 1 }) || die "$Template::ERROR\n";

if (! $qs_hash->{query}) {

print $cgi->header(-status => "200 OK", -type => 'text/html', -encoding => 'utf-8');
$tt->process("search.html", { 'query_url' => QUERY_URL, 'subtitle' => 'search', 'meta' => 1 }) || die $tt->error;

}
else {

my $query = $qs_hash->{query};

my $swish = SWISH::API->new(INDEX_FILE);
$swish->abort_last_error
    if $swish->Error;

my $results = $swish->query($query);
my @rlist;
for (my $i = 0;
     (my $result = $results->next_result) && ($qs_hash->{no_meta} || $i < MAX_RESULTS_WHEN_GIVING_METADATA);
     ++$i) {
    my $name = $result->property('swishdocpath');
    $name =~ s/^\.\///;
    my $f = catfile(DOC_PATH_PREFIX, $name);

    my $numpages = "";
    my $title = "";
    my $author = "";
    my $subject = "";
    if ($name && $name =~ /\.pdf$/ && (! $qs_hash->{no_meta})) {
        my $cachefilename = catfile(METADATA_CACHE_DIR, $name) . '.mdcache';
        if (-f $cachefilename) {
            my $json;
            eval {
                local undef $/;
                open J, $cachefilename;
                $json = <J>;
                close J;
            };
            if (! $@) {
                my $mdata = JSON::from_json($json);
                if (ref($mdata) eq "HASH") {
                    $numpages = $mdata->{numpages};
                    $title = $mdata->{title};
                    $author = $mdata->{author};
                    $subject = $mdata->{subject};
                }
            }
        }
    }

    my ($vol, $dir, $fname) = splitpath($name);
    push @rlist, { 'url' => $f, 'name' => $name, 'short_name' => $qs_hash->{no_meta} ? $name : trunc($name), 'dir_url' => $dir, 'numpages' => $numpages, 'title' => $title, 'author' => $author, 'subject' => $subject };
}
print $cgi->header(-status => "200 OK", -type => 'text/html', -encoding => 'utf-8');
$tt->process('results.html', { 'url_prefix' => URL_PREFIX, 'query_url' => QUERY_URL, 'results' => \@rlist, 'query' => $query, 'meta' => ($qs_hash->{no_meta} ? 0 : 1), 'subtitle' => "results for $query" }) || die $tt->error;

}
