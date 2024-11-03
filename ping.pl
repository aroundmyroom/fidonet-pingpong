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
# and place to filter.pl some like this:
# BEGIN { require "pong.pl"; }
# sub filter{
#   &pong;
# }
#

sub w_log {
    my ($type, $message) = @_;
    print "[$type] $message\n";  # Adjust as needed
}


my $flagfile = '/var/spool/ftn/flags/netscan'; # Flag file for indicating new netmail
my $myname   = 'AroundMyRooms Ping Robot'; # From: name in PONG reply
my $origline = 'You sent a ping! That did hurt, I will tell mamma!'; # Origin Line
my @myaddr   = @{ $config{addr} };
my $myaddr   = $myaddr[0];

sub pong() {
    if ( grep { $_ eq $toaddr } @myaddr ) {
        #Respond from the address ping was sent to
        $myaddr = $toaddr;
        $pngtr = "Your PING request has been received at its final destination:";
        $pngsub = "PONG:";
    }
    else {
        $pngtr  = "Your in transit PING was received and routed onward:";
        $pngsub = "TRACE:";

        #Get zone of sender
        ($fromzone) = $fromaddr =~ /^(.*?)(?=:)/;
        }
        #If othernet, match sender's zone with an address on this system
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
     if ((length($area)==0) && (uc $toname eq "PING") && (uc $fromname ne "PING")) {

        w_log('C',"Perl(): Make PONG to PING request: area=".((length($area)==0)? "netmail":$area)."; toname=$toname; toaddr=$toaddr fromname=$fromname; fromaddr=$fromaddr" );

        # Kill ping netmails addressed to this system
        if ( grep { $_ eq $toaddr } @myaddr ) {
        #if you want to keep the original message before the netmail is killed, add this line, make sure the LOCAL area exist
        putMsgInArea('PING', $fromname, $toname, $fromaddr, $toaddr, $subject, $date, $attr, $text, 0);
        # below setting will set the kill to the message

            $kill = 1;
        }

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
          . "==== begin of request body ====\r\r"
          . "From: $fromname ($fromaddr)\r"
          . "  To: $toname ($toaddr)\r"
          . "Subj: $subject\r"
          . "Date: $date\r\r"
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
        my $err = putMsgInArea($area,$myname,$fromname,$myaddr,$fromaddr,"$pngsub ".$subject,"","Uns Loc Pvt K/s",$msgtext,3);
        if( defined($err) ){ w_log('A',"Perl(): Can't make new message: $err"); }
        else{ open( FLAG, ">>$flagfile" ) && close(FLAG); }
    }
    return "";
}

w_log( 'U', "" );
1;
