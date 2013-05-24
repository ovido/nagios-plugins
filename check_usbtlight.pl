#! /usr/bin/perl -w
#
# tlight.pl - nagios addon
# modified version for Allnet 300RF (the wireless version)
#
# Copyright (C) 2004, 2005 Gerd Mueller / Netways GmbH
# Modified for USB traffic light by Birger Schmidt / Netways GmbH
# Modified for HTTPS and clewarecontrol 2.5 support by Rene Koch / ovido gmbh
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#
#

use POSIX;
use strict;
use Getopt::Long;
use LWP::UserAgent;
use Data::Dumper;
use File::Basename;
use Time::HiRes qw/usleep/;

&Getopt::Long::config('bundling');

my %COLOURS = ( 'green' => 2, 'yellow' => 1, 'red' => 0 );
my %COLOURSREV = reverse %COLOURS;
my %STATES = ( 'on' => 1, 'off' => 0 );

my $PROGNAME = basename($0);
my $opt_url;
my $opt_user;
my $opt_passwd;
my $opt_all;

my $opt_hostgroup;
my $opt_servicegroup;

my $opt_h;
my $status;
my $debug = undef;
my $force = 1;

$status = GetOptions(
	"a"              => \$opt_all,
	"all"            => \$opt_all,
	"url=s"          => \$opt_url,
	"hostgroup=s"    => \$opt_hostgroup,
	"servicegroup=s" => \$opt_servicegroup,
	"help|h"         => \$opt_h,
	"user=s"         => \$opt_user,
	"passwd=s"       => \$opt_passwd,
    "debug"          => \$debug,
#    "force"          => \$force,
);

if ( $opt_h || $status == 0 || !$opt_url ) {
	print_help();
	exit 0;
}

my $device = find_light();

my $ua = new LWP::UserAgent;
$ua->agent( "TLightW-Agent/0.1 " . $ua->agent );

if (LWP::UserAgent->VERSION >= 6.0){
  $ua->ssl_opts(verify_hostname => 0, SSL_verify_mode => 0x00);               # disable SSL cert verification
}

my $url = $opt_url . "/cgi-bin/status.cgi?host=all&type=detail&servicestatustypes=20&serviceprops=42&noheader=1&embedded=1";

$url .= "&hostgroup=" . $opt_hostgroup."&style=all"
  if ( $opt_hostgroup
	&& $opt_hostgroup ne ""
	&& $opt_hostgroup ne "--servicegroup" );
$url .= "&servicegroup=" . $opt_servicegroup
  if ( $opt_servicegroup && $opt_servicegroup ne "" );

my $req = new HTTP::Request GET => $url;
if ($opt_user){
   $req->authorization_basic($opt_user,$opt_passwd);
}

my $res = $ua->request($req);

if ( $res->is_success ) {
	my $content = $res->content;

	my $status = 'green';
	my $matches;
	my @lines;

	@lines = split( /\n/, $content );

	my $device_status = 'green';
	foreach (@lines) {
		if ( /<\/TR><\/TABLE><\/TD>/ ... /<\/TR>/ ) {

			$device_status = 'green'  if (/<\/TR><\/TABLE><\/TD>/);
			$device_status = 'yellow' if (m/statusWARNING/);
			$device_status = 'red'    if (m/statusCRITICAL/);

			# Only Hardstate are interesting
			if (m/>([0-9]+)\/([0-9]+)<\/TD>/) {
				$device_status = 'green' if ( $1 ne $2 );
			}

			if (/<\/TR>/) {
				$status = $device_status if ( $device_status eq 'red' );
				$status = $device_status
				  if ( $device_status eq 'yellow' and $status eq 'green' );

			}

		}

	}
	$status = 'red' if ( $content =~ m/statusHOSTDOWN/ );

	my $perfdata = "|green=";
	if ( $status eq "green" ) {
		$perfdata .= "1";
	}
	else {
		$perfdata .= "0";
	}
	$perfdata .= " yellow=";
	if ( $status eq "yellow" ) {
		$perfdata .= "1";
	}
	else {
		$perfdata .= "0";
	}

	$perfdata .= " red=";
	if ( $status eq "red" ) {
		$perfdata .= "1";
	}
	else {
		$perfdata .= "0";
	}

	my $bulb = $COLOURS{$status};

    # switch bulb
    switch_bulb( $bulb, $device );

	print "OK - Status \"" . $status . "\"." . $perfdata . "\n";

}
else {
	print
"Cannot reach nagios webinterface. Please check url, user and password.| green=0 yellow=0 red=1\n\n";
	exit 2; # CRITICAL;
}

sub print_help {
	printf "\nusage: \n";
	printf
"$PROGNAME --url <url> [--user <user>] [--passwd <passwd>] [--hostgroup <hostgroup>] [--servicegroup <servicegroup>] \n\n";
	printf "   --url          url to nagios\n";
	printf "   --user         nagios user for the webinterface\n";
	printf "   --passwd       password for the nagios user\n";
	printf "   --hostgroup    nagios hostgroup\n";
	printf "   --servicegroup nagios servicegroup\n";
	printf "   --debug        show debugging\n";
#	printf "   --force        ignore current state of bulbs and force on/off (may cause flickering)\n";
	printf "\n";
	printf "Requires clewarecontrol v2.5 from http://www.vanheusden.com/clewarecontrol\n";
	printf "DO NOT USE Version 1.0 (it's too slow!)\n";
	printf "Copyright (C) 2004, 2005 Gerd Mueller / Netways GmbH\n";
	printf "Modified for USB traffic light by Birger Schmidt / Netways GmbH\n";
	printf "Modified again by Davey Jones / Netways GmbH\n";
	printf "Modified for HTTPS and clewarecontrol 2.5 support by Rene Koch / ovido gmbh\n";
	printf "$PROGNAME comes with ABSOLUTELY NO WARRANTY\n";
	printf "This program is licensed under the terms of the ";
	printf "GNU General Public License\n(check source code for details)\n";
	printf "\n\n";
	exit 0;

}

sub switch_bulb {
    # avoid flicker by only switching when we change state
	my ($colour, $device) = @_;
	my $sysoutput = "ERROR clewarecontrol not found";

    # go through each bulb
    # red=0, yellow=1, green=2
    for ( my $i=0; $i < 3; $i++ )
    {
        $sysoutput = `clewarecontrol -c 1 -d $device -rs $i 2>&1`;
        chomp($sysoutput);
        print $COLOURSREV{$i}." is $sysoutput\n" if (defined($debug));
        if ((($sysoutput eq 'On') or $force) and ($i != $colour))
        {
            # switch off
            print "Switching ".$COLOURSREV{$i}." off\n" if (defined($debug));
            $sysoutput = `clewarecontrol -c 1 -d $device -as $i 0 2>&1`;
        }
        elsif ((($sysoutput eq 'Off') or $force) and ($i == $colour))
        {
            # switch on
            print "Switching ".$COLOURSREV{$i}." on\n" if (defined($debug));
            $sysoutput = `clewarecontrol -c 1 -d $device -as $i 1 2>&1`;
        }
    }
}


sub find_light
{
    my $sysoutput = "";
    $sysoutput = `clewarecontrol -l`;
    if (!defined($sysoutput))
    {
	    print "ERROR clewarecontrol not found\n";
        exit 2;
    }
        
    $sysoutput =~ s/.*.*Switch1.*serial number: ([0-9]*).*/$1/s;
    print "serial $sysoutput\n" if (defined($debug));
    return $sysoutput unless (!defined($sysoutput) or $sysoutput eq '');
    print "USB Light not found\n";
    exit 2;
}
