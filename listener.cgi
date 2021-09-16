#!/usr/bin/perl

# This file is part of StreamTaffy, an overlay system for Twitch streams.

# StreamTaffy is free software: you can redistribute it and/or modify
# it under the terms of version 3 of the GNU Affero General Public License as
# published by the Free Software Foundation.
#
# StreamTaffy is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with StreamTaffy.  If not, see <https://www.gnu.org/licenses/>.
#
# Copyright 2021 Michael Pirkola


use v5.20;
use Digest::SHA qw(hmac_sha256_hex);
use JSON 'decode_json';




##############
##  Config  ##
##############


# The support files should not be stored in a hosted location with the CGI
# scripts.  To accommodate this, the web server can be configured to pass a
# DATA_DIR environment variable to the CGI script, specifying where to look
# for the remaining files.  If updating from git, it may make sense to use
# symlinks for the hosted CGI and HTML files which point back to the data dir.
my $dir;
if ($ENV{DATA_DIR})  {
	$dir = $ENV{DATA_DIR};
	# Remove trailing slash if needed.
	chop $dir if $dir =~ m|/$|;
	}
else  {
	$dir = '.';
	}
$dir .= '/StreamTaffy' if (-d "$dir/StreamTaffy" );


# This file should definitely not be in a location that
# the webserver is serving.  The recommended method is
# to set the DATA_DIR environment variable to a safe location
# in nginx (or other server) config.
my $config_file = "$dir/StreamTaffy.conf";


# Set config defaults.
my %cfg = (
	cgi_live_dir => 'live',
	overlay_default => 'templates/blank.html',
	overlay_follow => 'templates/follow-*.html',
	overlay_visible => 'live/overlay.html',
	overlay_newsub => 'templates/newsub-*.html',
	debug_level => 0,
	
	debug_log => 'live/debug.log'
	);

# Read config from file.
open ( FILE, $config_file ) or die "Could not open $config_file";
while (<FILE>)  {
	# Skip comments and blank lines
	next if ( /^\s*#/ or /^\s*$/ );
	chomp;
	# Remove leading and trailing spaces
	s/^\s*(.*?)\s*/$1/;
	die "Config file error: line $_ unparseable in $config_file.\n" unless /=/;
	my ( $key, $value ) = split /\s*=\s*/;
	$cfg{$key} = $value;
	}
close FILE;

# Remove trailing slash if needed.
chop $cfg{cgi_live_dir} if $cfg{cgi_live_dir} =~ m|/$|;




# Predeclare debug prototype.
sub debug ($$);

my $debug;
if ($cfg{debug_level})  {
	open DEBUG, '>>', "$dir/$cfg{debug_log}"
	   or warn "Could not open debug log file '$dir/$cfg{debug_log}' : $!";
	}


my $buffer;

read(STDIN, $buffer, $ENV{'CONTENT_LENGTH'});


debug 2,"\nInput stream:\n";
debug 3,$_ foreach( sort `env` );
debug 2,"$buffer\n";

my $message = $ENV{HTTP_TWITCH_EVENTSUB_MESSAGE_ID} .
              $ENV{HTTP_TWITCH_EVENTSUB_MESSAGE_TIMESTAMP} .
              $buffer;

my $digest = hmac_sha256_hex($message, $cfg{secret});
my $hash = decode_json($buffer);

my $output;
my $success;
if ($ENV{HTTP_TWITCH_EVENTSUB_MESSAGE_SIGNATURE} eq 'sha256=' . $digest)  {
	$output = "Content-Type: text/plain\n\n$$hash{challenge}\n";
	$success = 'yes';
	}
else  {
	debug 3,"Failed signature check!";
	$output = "Status: 409\n";
	}

say $output;
debug 3,"\nOutput:\n$output\n";

exit unless $success and $ENV{HTTP_TWITCH_EVENTSUB_MESSAGE_TYPE} eq 'notification';
debug 3,"Continuing...\n";

my $template;
my @args = ($$hash{subscription}{type});
if ($$hash{subscription}{type} eq 'channel.follow')  {
	push @args, ($$hash{event}{user_id}, $$hash{event}{user_name});
	}
elsif ($$hash{subscription}{type} eq 'channel.subscribe')  {
	push @args, (
	    $ENV{HTTP_TWITCH_EVENTSUB_MESSAGE_ID},
	    $$hash{event}{is_gift},
	    $$hash{event}{tier},
	    $$hash{event}{user_id},
	    $$hash{event}{user_name}
	    );
	
	}
elsif ($$hash{subscription}{type} eq 'channel.subscription.message')  {
	push @args, (
	    $ENV{HTTP_TWITCH_EVENTSUB_MESSAGE_ID},
	    $$hash{event}{cumulative_months},
	    $$hash{event}{tier},
	    $$hash{event}{user_id},
	    $$hash{event}{user_name}
	    # Message text needs escaping
	    #$$hash{event}{message}{text}
	    # This won't work for translating emotes in the future,
	    # but it's good enough for now.
	    );
	
	}
else  {
	debug 1,"Subscription event type $$hash{subscription}{type} not yet supported.";
	exit;
	}

my $command = "cd $dir;./overlay_event.pl " . join( ' ', @args );

debug 2,"Running $command\n";
&dispatch ($command);



sub debug ($$)  {
	my ($level, $msg) = @_;
	return unless $cfg{debug_level} >= $level;
	chomp $msg;
	print DEBUG &timestamp . " DEBUG$level: $msg\n";
	#warn "DEBUG$level: $msg";
	}

sub dispatch  {
	# Properly close filehandles to allow CGI process to exit.
	my $command = join '',@_;
	system $command . ' 1>&- 2>&- &';
	}

sub timestamp  {
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
	return sprintf ( "%d\.%02d.%02d-%02d:%02d:%02d", ($year + 1900, $mon + 1, $mday, $hour, $min, $sec) );
	}

