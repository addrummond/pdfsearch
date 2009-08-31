package common;

use warnings;
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK);

require Exporter;

use CGI;
use Template;

use constant INDEX_FILE => '/var/pdflockerindex/index.swish-e';
use constant TEMPLATES_DIR => './includes';
use constant QUERY_URL => 'search.pl';
use constant DOC_PATH_PREFIX => '/web/locker';
# Note: trailing slash is required here (not for the others).
use constant URL_PREFIX => 'http://files.ling.umd.edu/locker/';
use constant METADATA_CACHE_DIR => '/var/pdflockerindex/metadata-cache';

use constant MAX_RESULTS_WHEN_GIVING_METADATA => 1000;
use constant MAX_SNIPPETS => 200;
use constant MAX_TITLE_LENGTH_BEFORE_TRUNCATION => 50;
use constant MAX_FILE_BROWSER_DIR_DEPTH => 20;

use constant PDFTOTEXT_PATH => '/opt/local/bin/pdftotext';

use constant SNIPPET_LENGTH => 250;

@ISA = qw( Exporter Autoloader );
@EXPORT = qw( INDEX_FILE TEMPLATES_DIR QUERY_URL DOC_PATH_PREFIX USERNAME PASSWORD LOCAL_FS_DOC_PATH_PREFIX MAX_RESULTS_WHEN_GIVING_METADATA MAX_TITLE_LENGTH_BEFORE_TRUNCATION URL_PREFIX MAX_FILE_BROWSER_DIR_DEPTH METADATA_CACHE_DIR PDFTOTEXT_PATH SNIPPET_LENGTH MAX_SNIPPETS );
