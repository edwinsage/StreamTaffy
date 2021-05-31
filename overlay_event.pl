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

my $config_file;
$config_file .= '.StreamTaffy.rc';

my %cfg;
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

if ($type eq 'channel.follow')  {
	my $user_id = shift @ARGV;
	my $user_name = join '',@ARGV;
	
	# Check for previous follow to prevent spam.
	# This open command will NOT create the file if it does not exist.
	open LIST, '+<', $cfg{follower_log}
	   or debug 1,"Could not open follower log '$cfg{follower_log}': $!";
	flock LIST, 2;  # Exclusive lock
	while (<LIST>)  {
		my ($line) = /^(\d+)/;
		exit if $line eq $user_id;
		}
	# If we made it through, the user ID was not in the list.  Add it.
	print LIST "$user_id\t$user_name\n";
	
	flock LIST, 8;  # Unlock
	close LIST;
	
	
	my @page;
	open TEMPLATE, '<', $cfg{overlay_follow}
	   or debug 1,"Missing follow template '$cfg{overlay_follow}': $!";
	while (<TEMPLATE>)  {
		s/\$USER_NAME/$user_name/g;
		push @page, $_;
		
		}
	close TEMPLATE;
	
	# Use a lock file to block other operations.
	open LOCK, '<', $cfg{overlay_lock_file}
	   or debug 1,"Locking failed! $!";
	flock LOCK, 2;  # 2 for exclusive locking
	
	# Write the page
	open TEMP, '>', $cfg{overlay_temp_file}
	   or debug 1,"Could not open overlay_temp_file '$cfg{overlay_temp_file}' for writing: $!";
	print TEMP foreach @page;
	close TEMP;
	
	
	&overlay_event;
	
	
	flock LOCK, 8;  # 8 unlocks
	close LOCK;
	
	
	
	}




sub overlay_event  {
	# Get the timeout from the file.
	my $timer;
	open OVERLAY, '<', $cfg{overlay_temp_file}
	   or debug 1,"Could not open overlay_temp_file '$cfg{overlay_temp_file}' for reading: $!";
	while (<OVERLAY>)  {
		($timer) = /meta http-equiv="refresh" content="(\d+)"/;
		last if $timer;
		}
	close OVERLAY;
	
	# Minimum timeout
	$timer = 5 if $timer < 5;
	
	# Replace the old link
	rename $cfg{overlay_temp_file}, $cfg{overlay_visible}
	   or debug 1,"Changing link A failed! $!";
	
	# Wait long enough to make sure the previous page has refreshed.
	sleep 5;
	
	link $cfg{overlay_blank}, $cfg{overlay_temp_file}
	   or debug 1,"Creating temporary link B failed! $!";
	rename $cfg{overlay_temp_file}, $cfg{overlay_visible}
	   or debug 1,"Changing link B failed! $!";
	
	# Wait for event to end.
	sleep $timer - 5;
	
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
