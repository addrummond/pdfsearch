#!/usr/bin/perl
use warnings;
use strict;

use common;
use fserialize qw( list_dir );
use File::Spec::Functions qw( splitpath catfile catdir );
use URI::Query;
use File::Temp qw ( tempfile );
# This script doesn't use the standard CGI module because we need to read in some headers
# before we start reading in the file.
use CGI qw( :standard );
use JSON;

local $/ = "\r\n";

if (! $ENV{CONTENT_TYPE}) {
    print header(-status => "400 Bad Request", -type => 'text/html', -encoding => 'utf-8');
    print "\n"; # No point in giving proper error for ajax.
    exit 0;
}

my $boundary;
$ENV{'CONTENT_TYPE'} =~ /multipart\/form-data; boundary=(--.*)/;
if (! $1) {
    print header(-status => "400 Bad Request", -type => 'text/html', -encoding => 'utf-8');
    print "\n"; # No point in giving proper error for a bad request.
    exit 0;
}
$boundary = $1;
chomp $boundary;

(my $tmpfh, my $tmpfname) = tempfile() || die "Error creating temporary file for upload: $!";

my %parms;
my $current_parm;
my $current_parm_value = "";
my $final_filename;
my $state = 'initial';
my $bytes_read = 0;
while (defined(my $line = <>)) {
    if ($state eq 'initial') {
        chomp $line;
        if($line =~ /\Q$boundary\E/) {
            $state = 'inpart';
        }
    }
    elsif ($state eq 'inpart')  {
        if ($line =~ /^Content-Disposition: form-data; name="((?:magic)|(?:dir))"/) {
            $current_parm = $1;
            $state = 'parmvalue1';
        }
        elsif ($line =~/^Content-Disposition: form-data; name="userfile"; filename="([^"]*)"/) {
            $parms{'filename'} = $1;
            $state = 'b4filecontents';
        }
    }
    elsif ($state eq 'parmvalue1') {
        # Skip blank line.
        $state = 'parmvalue2';
    }
    elsif ($state eq 'parmvalue2') {
        chomp $line;
        if ($line =~ /\Q$boundary\E/) {
            $current_parm_value = substr($current_parm_value, 0, -1); # Chomp won't work because $/ has been set to "\r\n".
            $parms{$current_parm} = $current_parm_value;
            $state = 'inpart';
            $current_parm = "";
            $current_parm_value = "";
        }
        else {
            $current_parm_value .= $line . "\n";
        }
    }
    elsif ($state eq 'b4filecontents') {
        # Skip Content-Type.
        $state = 'b4filecontents2';
    }
    elsif ($state eq 'b4filecontents2') {
        # Skip blank line.
        $state = 'filecontents';
    }
    elsif ($state eq 'filecontents') {
        if (! ($parms{magic} && $parms{dir} && $parms{filename})) {
            print header(-status => "400 Bad Request", -type => 'text/html', -encoding => 'utf-8');
            print "\n";
            exit 0;
        }
        else {
            if (! $final_filename) { # If this is our first time in this state.
                # Check that the file doesn't already exist in the locker.
                $final_filename = catfile(DOC_PATH_PREFIX, $parms{dir}, $parms{filename});
                if (-f $final_filename) {
                    print header(-status => "400 Bad Request", -type => 'text/html', -encoding => 'utf-8');
                    print "\nThe file already exists.\n";
                    exit 0;
                }

            }

            # Stuff we do for every iteration of this state.
            $bytes_read += length($line);
            print $tmpfh $line;
            eval {
                open my $h, ">" . catfile(FILE_LENGTH_DATASTORE_DIR, $parms{magic});
                flock $h, 2; # Lock exclusive (could wait indefinitely but Apache has a timeout for CGI scripts).
                print $h to_json([$bytes_read, $ENV{CONTENT_LENGTH} + 0]), "\n";
                flock $h, 8; # Unlock
                close $h;
            };
            print STDERR "File upload warning 2" if $@;
        }
    }
    else { die "Bad state!"; }
}

seek($tmpfh, 0, 0) || die "Error seeking temp upload file.";
(open my $final, ">$final_filename") || die "Error creating final file for upload.";
my $bytes;
while (sysread($tmpfh, $bytes, 524288)) {
    syswrite($final, $bytes) || die "Error copying file to final resting place";
}

close($tmpfh) || die "Error closing temp upload file.";
#unlink($file_position_handle) || die "Error unlinking file position file.";
close($final) || die "Error closing final file.";

print header(-status => "200 OK", -type => 'text/html', -encoding => 'utf-8');
print "\n";

