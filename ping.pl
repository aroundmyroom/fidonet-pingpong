#
# Ping-pong robot for HPT. Designed accordingly FTS-5001.002
# (c) 2006 Gremlin
# (c) 2006 Grumbler
# (c) 2010 Grumbler
#
# Modified by Jay Harris (1:229/664) with thanks to
# Deon George (3:633/509).
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# Insert into config:
# hptperlfile /home/fido/lib/filter.pl
# and place to filter.pl some like this:
# BEGIN { require "pong.pl"; }
# sub filter{
#   &pong;
# }
#
# What do you need for fidian?
#
# touch /var/log/husky/ping.log
# chown ftn:ftn /var/log/husky/ping.log
#
# add to your /etc/husky/areas file a local folder PING
# like:
# localarea   PING          /var/spool/ftn/msgbase/ping          -b Jam
#
#
# with this you can use this script
# to check if script is valid: perl /etc/husky/filter.pl
# it should not generate any output or error. If so, the script is not ok.
#
# Note: this script allows the from address also to be PING
# but do not reply with PING
#
use POSIX qw(strftime);
use Time::Piece;

sub w_log {
    my ($type, $message) = @_;
    my $logfile = '/var/log/husky/ping.log';  # Path to the log file

    # Check if the directory exists; create it if it doesn’t
    my $logdir = '/var/log/husky';
    unless (-d $logdir) {
        mkdir $logdir or die "Could not create directory '$logdir': $!";
    }

    # Format the current date and time
    my $timestamp = strftime("%Y-%m-%d %H:%M:%S", localtime);


    # Open the log file in append mode; create it if it doesn’t exist
    open my $fh, '>>', $logfile or die "Could not open log file '$logfile': $!";

    # Add timestamp to the log message
    print $fh "[$timestamp] [$type] $message\n";
    close $fh;
}

my ($file)   = __FILE__ =~ /([^\/]+)$/; # Get filename of script without path
my $flagfile = '/var/spool/ftn/flags/netscan'; # Flag file for indicating new netmail
my $myname   = 'AroundMyRooms Ping Robot'; # From: name in PONG reply. DO NOT use PING as reply name
my $origline = 'You sent a ping! That did hurt, I will tell mamma!'; # Origin Line
my @myaddr   = @{ $config{addr} };
my $myaddr   = $myaddr[0];


sub pong {
    if ( length($area) == 0 && uc($toname) eq "PING" ) {
        if ( grep { $_ eq $toaddr } @myaddr ) {
            # Respond from the address ping was sent to
            $myaddr = $toaddr;
            $pngtr = "Your PING request has been received at its final destination:";
            $pngsub = "PONG";
        }
        else {
            $pngtr  = "Your in transit PING was received and routed onward:";
            $pngsub = "TRACE";

            # Get zone of sender
            ($fromzone) = $fromaddr =~ /^(.*?)(?=:)/;
        }

        # If othernet, match sender's zone with an address on this system
        if ( $fromzone !~ /^[1234]$/ ) {
            foreach (@myaddr) {
                ($myzone) = $_ =~ /^(.*?)(?=:)/;
                if ( $myzone == $fromzone ) {
                    $myaddr = $_;
                    last;
                }
            }
        }

        my $msgtext = "";

        # Check if message is netmail & addressed to PING (case insensitive)
        w_log('C', "$file: Make $pngsub to PING request: area=".((length($area)==0)? "netmail":$area)."; toname=$toname; toaddr=$toaddr fromname=$fromname; fromaddr=$fromaddr" );

        # Kill ping netmails addressed to this system also copy the mail to area PING before killing it.
        if ( uc($toname) eq "PING" && grep { $_ eq $toaddr } @myaddr ) {
            # If you want to keep the original message before the netmail is killed, add this line
            putMsgInArea('PING', $fromname, $toname, $fromaddr, $toaddr, $subject, $date, $attr, $text, 0);
            # Below setting will set the kill to the message
            $kill = 1;

            # Set tearline to current uptime
            $report_tearline = `uptime -p | tr -d "\n"`;

            # $text contains original message and must be left as is
            $msgtext = $text;

            # Get MSGID (if any) for REPLY: kludge
            if ( $msgtext =~ /\r\x01MSGID:\s*(.*?)\r/ ) {
                $RPLY = $1;
            }

            # Invalidate control stuff
            $msgtext =~ s/\x01/@/g;
            $msgtext =~ s/\n/\\x0A/g;
            $msgtext =~ s/\r--- /\r-=- /g;
            $msgtext =~ s/\r\ \* Origin: /\r + Origin: /g;

            $msgtext =
                "$pngtr\r\r"
              . "==== Begin of request body ====\r\r"
              . "From: $fromname ($fromaddr)\r"
              . "  To: $toname ($toaddr)\r"
              . "Subj: $subject\r"
              . "Date: " . Time::Piece->strptime($date, "%d %b %y %H:%M:%S")->strftime("%Y-%m-%d %H:%M:%S") . "\r"
              . "==== Message text including kludges ====\r\r"
              . "$msgtext\r"
              . "===== end of request body =====\r\r"
              . "--- $report_tearline\r"
              . " * Origin: $origline ($myaddr)\r";

            # Get current timezone
            $TZ = strftime( "%z", localtime() );
            $TZ =~ s/^\+//;

            # Generate MSGID for PONG reply
            $MID = `gnmsgid`;

            # Prepend kludge lines
            if ( $RPLY eq "" ) {
                $msgtext = "\x01MSGID: $myaddr $MID\r\x01TZUTC: $TZ\r".$msgtext;
            }
            else {
                $msgtext = "\x01MSGID: $myaddr $MID\r\x01REPLY: $RPLY\r\x01TZUTC: $TZ\r".$msgtext;
            }

            # Post message
            my $err = putMsgInArea($area,$myname,$fromname,$myaddr,$fromaddr,"$pngsub: ".$subject,"","Uns Loc Pvt K/s",$msgtext,3);
            if( defined($err) ){ w_log('A',"$file: Unable to make a PONG reply: $err"); }
            else{ open( FLAG, ">>$flagfile" ) && close(FLAG); }
        }
    }
    return "";
}

1;
