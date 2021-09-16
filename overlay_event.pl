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
use File::Copy;




##############
##  Config  ##
##############


my $config_file = 'StreamTaffy.conf';

# Set config defaults.
my %cfg = (
	cgi_live_dir => 'live',
	overlay_default => 'templates/blank.html',
	overlay_visible => 'live/overlay.html',
	overlay_follow => 'templates/follow-*.html',
	overlay_newsub => 'templates/newsub-*.html',
	overlay_resub => 'templates/resub-*.html',
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

# Remove trailing slash if needed.
chop $cfg{cgi_live_dir} if $cfg{cgi_live_dir} =~ m|/$|;




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
	#my ($user_id, $user_name) = @ARGV;
	my $user_id = shift @ARGV;
	my $user_name = join '',@ARGV;
	
	# Check for previous follow to prevent spam.
	my $file = "$cfg{cgi_live_dir}/follower.log";
	my $fh;
	
	# Try creating the log if it does not exist.
	if (-f $file)  {
		open $fh, '+<', $file
		   or debug 1,"Could not open follower log '$file': $!";
		}
	else  {
		open $fh, '+>', $file
		   or debug 1,"Could not create follower log '$file': $!";
		}
	
	flock $fh, 2;  # Exclusive lock
	
	while (<$fh>)  {
		my ($id) = /^.{19}\t(\d+)/;
		exit if $id eq $user_id;
		}
	# If we made it through, the user ID was not in the list.  Add it.
	print $fh &timestamp . "\t$user_id\t$user_name\n";
	
	flock $fh, 8;  # Unlock
	close $fh;
	
	
	my @templates = glob "$cfg{overlay_follow}";
	
	unless (@templates)  {
		debug 1,"No templates found matching pattern $cfg{overlay_follow}";
		exit;
		}
	
	open $fh, '<', $templates[int(rand(@templates))]
	   or debug 1,"Missing follow template '$cfg{overlay_follow}': $!";
	while (<$fh>)  {
		s/\$USER_NAME/$user_name/g;
		push @page, $_;
		
		}
	close $fh;
	
	}
elsif ($type eq 'channel.subscribe')  {
	#my ($event_id,
	#    $is_gift,
	#    $tier,
	#    $user_id,
	#    $user_name
	#    ) = @ARGV;
	
	my $event_id = shift @ARGV;
	my $is_gift = shift @ARGV;
	my $tier = shift @ARGV;
	my $user_id = shift @ARGV;
	my $user_name = join '',@ARGV;
	
	# Check for a duplicate event ID.
	exit if &duplicate_event_check($event_id);
	
	
	
	my @templates = glob "$cfg{overlay_newsub}";
	
	unless (@templates)  {
		debug 1,"No templates found matching pattern $cfg{overlay_newsub}";
		exit;
		}
	
	open TEMPLATE, '<', $templates[int(rand(@templates))]
	   or debug 1,"Missing sub template '$cfg{overlay_newsub}': $!";
	while (<TEMPLATE>)  {
		s/\$USER_NAME/$user_name/g;
		push @page, $_;
		
		}
	close TEMPLATE;
	
	}
elsif ($type eq 'channel.subscription.message')  {
	#my ($event_id,
	#    $months,
	#    $tier,
	#    $user_id,
	#    $user_name,
	#    $message
	#    ) = @ARGV;
	
	my $event_id = shift @ARGV;
	my $months = shift @ARGV;
	my $tier = shift @ARGV;
	my $user_id = shift @ARGV;
	my $user_name = join '',@ARGV;
	
	
	# Check for a duplicate event ID.
	exit if &duplicate_event_check($event_id);
	
	# Text in message must be escaped properly.
	#$message =~ s/&/\&amp;/g;
	#$message =~ s/</\&lt;/g;
	#$message =~ s/>/\&gt;/g;
	
	my @templates = glob "$cfg{overlay_resub}";
	
	unless (@templates)  {
		debug 1,"No templates found matching pattern $cfg{overlay_resub}";
		exit;
		}
	
	open TEMPLATE, '<', $templates[int(rand(@templates))]
	   or debug 1,"Missing sub template '$cfg{overlay_resub}': $!";
	while (<TEMPLATE>)  {
		s/\$USER_NAME/$user_name/g;
		#s/\$MESSAGE/$message/g;
		s/\$MONTHS/$months/g;
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
	# This file should not have any content; it only serves as a control.
	open LOCK, '+>', "$cfg{cgi_live_dir}/overlay.lock"
	   or debug 1,"Locking $cfg{cgi_live_dir}/overlay.lock failed! $!";
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
	   or debug 1,"Moving $cfg{cgi_live_dir}/overlay.tmp to $cfg{overlay_visible} failed! $!";
	
	# Wait long enough to make sure the previous page has refreshed.
	sleep 4;
	
	copy( $cfg{overlay_default}, "$cfg{cgi_live_dir}/overlay.tmp")
	   or debug 1,"Creating temporary file $cfg{cgi_live_dir}/overlay.tmp failed! $!";
	rename "$cfg{cgi_live_dir}/overlay.tmp", $cfg{overlay_visible}
	   or debug 1,"Moving $cfg{cgi_live_dir}/overlay.tmp back to $cfg{overlay_visible} failed! $!";
	
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


sub duplicate_event_check  {
	
	my ($id) = @_;
	
	my $file = "$cfg{cgi_live_dir}/event.log";
	my $fh;
	
	# Try creating the log if it does not exist.
	if (-f $file)  {
		open $fh, '+<', $file
		   or debug 1,"Could not open event log '$file': $!";
		}
	else  {
		open $fh, '+>', $file
		   or debug 1,"Could not create event log '$file': $!";
		}
	
	flock $fh, 2;  # Exclusive lock
	
	# Check for an existing event first.
	while (<$fh>)  {
		chomp;
		# Return 1 for duplicates.
		return 1 if $id eq substr $_, 20;
		}
	
	
	# If we made it through, the user ID was not in the list.  Add it.
	print $fh &timestamp . " $id\n";
	
	flock $fh, 8;  # Unlock
	close $fh;
	
	# If no duplicate was detected, return false.
	return 0;
	}


