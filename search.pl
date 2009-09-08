#!/usr/bin/perl
use warnings;
use strict;

use SWISH::API;
use common;
use parseqstring;
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
my $query_strings = parse_qstring($query) if $query;
my $query_re = re_for_strings($query_strings) if $query;

my $swish = SWISH::API->new(INDEX_FILE);
$swish->abort_last_error
    if $swish->Error;

my $locateresults;
my $results;
if ($qs_hash->{filenames_only}) {
    
    my $cmd = LOCATE_LOCATION . ' -d ' . LOCATE_DB_LOCATION . " \"$query\"";
    print STDERR "CMD $cmd\n";
    my $rs = `$cmd`;
    #die "Error running 'locate': $!" if $? >> 8;
    if ($rs != /^\s*$/) {
        my @lrs = grep { -f $_ && $_ =~ /.pdf$/i } split(/\n/, $rs);
        my $pref = PATH_PREFIX_TO_STRIP_FROM_LOCATE_RESULTS;
        for (@lrs) {
            $_ =~ s/^$pref//;
            chomp;
        }
        $locateresults = \@lrs;
    }
}
else {
    $results = $swish->query($query);
}

# Ick.
sub iter_over_filenames {
    my $action = shift;
    my @rlist;

    if ($locateresults) {
        my $i = 0;
        foreach (@$locateresults) {
            if ((! $qs_hash->{no_meta}) && ($i >= MAX_RESULTS_WHEN_GIVING_METADATA)) {
                last;
            }
            &$action($i, \@rlist, $_);
            ++$i;
        }
    }
    else {
        for (my $i = 0; 
             (my $result = $results->next_result) && ($qs_hash->{no_meta} || $i < MAX_RESULTS_WHEN_GIVING_METADATA);
             ++$i) {
            &$action($i, \@rlist, $result->property('swishdocpath'));
        }
    }

    return \@rlist;
}

sub result_loop {
    my $i = shift;
    my $rlistref = shift;
    my $name = shift;

    $name =~ s/^\.\///;
    my $f = catfile(DOC_PATH_PREFIX, $name);

    my $numpages = "";
    my $title = "";
    my $author = "";
    my $subject = "";
    my $snippet_begin = "";
    my $snippet_end = "";
    my $snippet_match = "";

    if ($name && $name =~ /\.pdf$/i && (! $qs_hash->{no_meta})) {
        my $cachefilename = catfile(METADATA_CACHE_DIR, $name) . '.mdcache';
        my $ocrfilename = catfile(METADATA_CACHE_DIR, $name) . '.ocr';
      
        if (-f $cachefilename) {
            # Open metadata stored in JSON format in cache (if any).
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
        if (-f $ocrfilename) {
            # Open cached OCR text (if any) to find matching snippet.
            if ($i < MAX_SNIPPETS && -f $ocrfilename) {
                my $ocr;
                eval { 
                    local undef $/;
                    open OCR, $ocrfilename;
                    $ocr = <OCR>;
                    close OCR;
                };
                if ((! $@) && $ocr) {
                    if ($ocr =~ /[^\w]$query_re[^\w]/i) {
                        $snippet_match = $&;

                        use integer; # Integer division.
                        my $start = length($`) - (SNIPPET_LENGTH / 2);
                        $start = 0 if $start < 0;
                        my $middle = length($`) + length($&);
                        $snippet_begin = substr($ocr, $start, SNIPPET_LENGTH / 2);
                        $snippet_end = substr($ocr, $middle, SNIPPET_LENGTH / 2);
                        $snippet_begin =~ s/\s+/ /g;
                        $snippet_begin .= substr($snippet_match, 0, 1);
                        $snippet_end =~ s/\s+/ /g;
                        $snippet_end = substr($snippet_match, -1, 1) . $snippet_end;
                        $snippet_match =~ s/^.//; # Remove first char.
                        $snippet_match =~ s/.$//; # Remove last char.
                        $snippet_match =~ s/\s+/ /g; 
                    }
                }
            }
        }
    }

    my ($vol, $dir, $fname) = splitpath($name);
    push @$rlistref, { 'url' => $f, 'name' => $name, 'short_name' => $qs_hash->{no_meta} ? $name : trunc($name), 'dir_url' => $dir, 'numpages' => $numpages, 'title' => $title, 'author' => $author, 'subject' => $subject, 'snippet_begin' => $snippet_begin, 'snippet_end' => $snippet_end, 'snippet_match' => $snippet_match };
}

my $rlistref = iter_over_filenames(\&result_loop);

print $cgi->header(-status => "200 OK", -type => 'text/html', -encoding => 'utf-8');
$tt->process('results.html', { 'url_prefix' => URL_PREFIX, 'query_url' => QUERY_URL, 'results' => $rlistref, 'query' => $query, 'meta' => ($qs_hash->{no_meta} ? 0 : 1), 'filenames_only' => $qs_hash->{filenames_only}, 'subtitle' => "results for $query" }) || die $tt->error;

}
