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

my $config_file = '.StreamTaffy.conf';

# Set config defaults.
my %cfg = (
	cgi_live_dir => 'live/',
	overlay_default => 'templates/blank.html',
	overlay_follow => 'templates/follow-*.html',
	overlay_visible => 'live/overlay.html',
	debug_level => 0,
	
	debug_log => 'live/debug.log'
	);

# Read config from file.
open ( FILE, $config_file ) or die "Could not find $config_file";
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

# Predeclare debug prototype.
sub debug ($$);

my $debug;
if ($cfg{debug_level})  {
	open DEBUG, '>>', "$cfg{debug_log}"
	   or warn "Could not open debug log file '$cfg{debug_log}' : $!";
	}


my $template;

my $type = shift @ARGV;
my @page;

if ($type eq 'channel.follow')  {
	my $user_id = shift @ARGV;
	my $user_name = join '',@ARGV;
	
	# Check for previous follow to prevent spam.
	# This open command will NOT create the file if it does not exist.
	open LIST, '+<', "$cfg{cgi_live_dir}/follower.log"
	   or debug 1,"Could not open follower log '$cfg{cgi_live_dir}/follower.log': $!";
	flock LIST, 2;  # Exclusive lock
	while (<LIST>)  {
		my ($id) = /^.{19}\t(\d+)/;
		exit if $id eq $user_id;
		}
	# If we made it through, the user ID was not in the list.  Add it.
	print LIST &timestamp . "\t$user_id\t$user_name\n";
	
	flock LIST, 8;  # Unlock
	close LIST;
	
	my @templates = glob "$cfg{overlay_follow}";
	
	
	open TEMPLATE, '<', $templates[int(rand(@templates))]
	   or debug 1,"Missing follow template '$cfg{overlay_follow}': $!";
	while (<TEMPLATE>)  {
		s/\$USER_NAME/$user_name/g;
		push @page, $_;
		
		}
	close TEMPLATE;
	
	}
elsif ($type eq 'channel.subscribe')  {
	my $is_gift = shift @ARGV;
	my $tier = shift @ARGV;
	my $user_id = shift @ARGV;
	my $user_name = join '',@ARGV;
	
	my @templates = glob "$cfg{overlay_sub}";
	
	open TEMPLATE, '<', $templates[int(rand(@templates))]
	   or debug 1,"Missing sub template '$cfg{overlay_sub}': $!";
	while (<TEMPLATE>)  {
		s/\$USER_NAME/$user_name/g;
		push @page, $_;
		
		}
	close TEMPLATE;
	
	}
else  {
	
	exit;
	}

&overlay_event(@page);


sub overlay_event  {
	# Use a lock file to block other operations.
	open LOCK, '<', "$cfg{cgi_live_dir}/overlay.lock"
	   or debug 1,"Locking failed! $!";
	flock LOCK, 2;  # 2 for exclusive locking
	
	# Get the timeout from the template and write the page.
	my $timer;
	open TEMP, '>', "$cfg{cgi_live_dir}/overlay.tmp"
	   or debug 1,"Could not open overlay_temp_file '$cfg{cgi_live_dir}/overlay.tmp' for writing: $!";
	foreach (@_)  {
		print TEMP;
		$timer = $1 if /meta http-equiv="refresh" content="(\d+)"/;
		}
	close TEMP;
	
	
	# Minimum timeout
	$timer = 5 if $timer < 5;
	
	# Replace the old link
	rename "$cfg{cgi_live_dir}/overlay.tmp", $cfg{overlay_visible}
	   or debug 1,"Changing link A failed! $!";
	
	# Wait long enough to make sure the previous page has refreshed.
	sleep 4;
	
	link $cfg{overlay_default}, "$cfg{cgi_live_dir}/overlay.tmp"
	   or debug 1,"Creating temporary link B failed! $!";
	rename "$cfg{cgi_live_dir}/overlay.tmp", $cfg{overlay_visible}
	   or debug 1,"Changing link B failed! $!";
	
	# Wait for event to end.
	sleep $timer - 4;
	
	
	
	flock LOCK, 8;  # 8 unlocks
	close LOCK;
	}



sub debug ($$)  {
	my ($level, $msg) = @_;
	return unless $cfg{debug_level} >= $level;
	chomp $msg;
	print DEBUG &timestamp . " DEBUG$level: $msg\n";
	warn "DEBUG$level: $msg";
	}


sub timestamp  {
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
	return sprintf ( "%d\.%02d.%02d-%02d:%02d:%02d", ($year + 1900, $mon + 1, $mday, $hour, $min, $sec) );
	}
