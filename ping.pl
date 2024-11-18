#!/usr/bin/perl
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
#
# and place to filter.pl some like this:
# BEGIN {
#   require "pong.pl";
# }
#
# sub filter {
#   &pong;
# }
#
my ($file)   = __FILE__ =~ /([^\/]+)$/; # Get filename of script without path
my $flagfile =  '/home/ubuntu/fido/semaphore/mail.out'; # Flag file for indicating new netmail
my $myname   = 'Ping Robot'; # From: name in PONG reply. Cannot be 'PING'
my $origline = 'Northern Realms'; # Origin Line
my @myaddr   = @{ $config{addr} };
my $myaddr   = $myaddr[0];

sub pong() {
    # Do not set $myname to 'PING'
    if ( uc($myname) eq "PING" ) { die "ERROR: \$myname cannot be PING"; }

    # Check if message is netmail & addressed to PING or PINGC (case insensitive)
    if ( length($area) == 0 && ( uc($toname) eq "PING" || uc($toname) eq "PINGC" ) && uc($fromname) ne "PING" ) {
        my $msgtext = "";
        my $rply    = "";

        if ( grep { $_ eq $toaddr } @myaddr ) {
            # Respond from the address ping was sent to
            $myaddr = $toaddr;

            if ( uc($toname) eq "PING" ) {
                $pngtr  = "Your PING request has been received at its final destination:";
                $pngsub = "PONG";
            } elsif ( uc($toname) eq "PINGC" ) {
                $pngtr  = "Your PINGC request has been received at its final destination:";
                $pngsub = "PONGC";
                # If $fromaddr is not a point then send direct
                if ( $fromaddr !~ /\./ || $fromaddr =~ /\.0$/ ) {
                    $direct = "\x01FLAGS DIR IMM\r";
                }
            }
        }
        else {
            $pngtr  = "Your in transit PING was received and routed onward:";
            $pngsub = "TRACE";

            # Get zone of sender
            ($fromzone) = $fromaddr =~ /^(.*?)(?=:)/;

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
        }

        w_log( 'C',"$file: Make $pngsub to PING request: area=".((length($area) == 0) ? "netmail" : $area)."; toname=$toname; toaddr=$toaddr; fromname=$fromname; fromaddr=$fromaddr" );

        # Kill ping netmails addressed to this system
        if ( grep { $_ eq $toaddr } @myaddr ) {
            $kill = 1;
        }

        # $text contains original message and must be left as is
        $msgtext = $text;

        # Get sender's MSGID (if any) for REPLY kludge
        if ( $msgtext =~ /\r\x01MSGID:\s*(.*?)\r/ ) {
            $rply = $1;
        }

        # Set tearline to current uptime
        $report_tearline = `uptime -p | tr -d "\n"`;

        # Invalidate control stuff
        $msgtext =~ s/\x01/@/g;
        $msgtext =~ s/\n/\\x0A/g;
        $msgtext =~ s/\r--- /\r-=- /g;
        $msgtext =~ s/\r\ \* Origin: /\r + Origin: /g;

        $msgtext =
            "$pngtr\r\r"
          . "==== start of request body ====\r\r"
          . "From: $fromname ($fromaddr)\r"
          . "  To: $toname ($toaddr)\r"
          . "Subj: $subject\r"
          . "Date: $date\r\r"
          . "$msgtext\r"
          . "===== end of request body =====\r\r"
          . "--- $report_tearline\r"
          . " * Origin: $origline ($myaddr)\r";

        # Generate MSGID for our PONG reply
        $mid = `gnmsgid`;

        # Get current timezone
        $tz = strftime( "%z", localtime() );
        $tz =~ s/^\+//;

        # Prepend kludge lines
        if ( $rply eq "" ) {
            $msgtext = "\x01MSGID: $myaddr $mid\r\x01TZUTC: $tz\r".$direct.$msgtext;
        }
        else {
            $msgtext = "\x01MSGID: $myaddr $mid\r\x01REPLY: $rply\r\x01TZUTC: $tz\r".$direct.$msgtext;
        }

        # Post message
        my $err = putMsgInArea($area,$myname,$fromname,$myaddr,$fromaddr,"$pngsub: ".$subject,"","Uns Loc Pvt K/s",$msgtext,3);
        if ( defined($err) ) { w_log( 'A', "$file: Unable to make PONG reply: $err" ); }
        else { open( FLAG, ">>$flagfile" ) && close(FLAG); }
    }
    return "";
}

w_log( 'U', "" );
1;
