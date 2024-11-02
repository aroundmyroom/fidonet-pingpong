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
# 1st November 2024:
# Slightly modified by Dennis Slagers (2:280/2060) after Jay Harris
# made his script available to me.
# Adjusted information about filter.pl and example due to @INC issues.
# Improved zone matching logic and regular expressions for zone format matching.
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
# Ensure correct user:group permissions (ftn:ftn).
#
# Insert into config (for Fidian setup: /etc/husky/config):
# hptperlfile /etc/husky/filter.pl
# Place filter.pl in /etc/husky and set the @PATH with `use lib`.
#
# --- filter.pl example ---
# use lib '/etc/husky';
# BEGIN { require "pong.pl"; }
# sub filter {
#   &pong;
# }
# --- end example ---

sub w_log {
    my ($type, $message) = @_;
    print "[$type] $message\n";  # Adjust logging as needed
}

my $flagfile = '/var/spool/ftn/flags/netscan'; # Flag file for new netmail
my $myname   = 'Ping Robot'; # From: name in PONG reply
my $origline = 'You sent a ping! That did hurt, I will tell mamma!'; # Origin Line
my @myaddr   = @{ $config{addr} };
my $myaddr   = $myaddr[0];

sub pong() {
    if ( grep { $_ eq $toaddr } @myaddr ) {
        # Respond from the address ping was sent to
        $myaddr = $toaddr;
        $pngtr  = "Your PING request has been received at its final destination:";
        $pngsub = "PONG:";
    } else {
        $pngtr  = "Your in-transit PING was received and routed onward:";
        $pngsub = "TRACE:";

        # Improved zone matching logic
        ($fromzone) = $fromaddr =~ /^(\d+):/;
        if ( defined $fromzone && $fromzone !~ /^[1234]$/ ) {
            # Iterate over system addresses to find matching zone
            foreach (@myaddr) {
                ($myzone) = $_ =~ /^(\d+):/;
                if ( defined $myzone && $myzone == $fromzone ) {
                    $myaddr = $_;
                    last;
                }
            }
        }
    }

    my $msgtext = "";

    # Check if message is netmail & addressed to PING (case insensitive)
    if ((length($area) == 0) && (uc $toname eq "PING") && (uc $fromname ne "PING")) {

        w_log('C', "Perl(): Make PONG to PING request: area=" . ((length($area) == 0) ? "netmail" : $area) . "; toname=$toname; toaddr=$toaddr fromname=$fromname; fromaddr=$fromaddr");

        # Kill ping netmails addressed to this system
        if ( grep { $_ eq $toaddr } @myaddr ) {
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
            $msgtext = "\x01MSGID: $myaddr $MID\r\x01TZUTC: $TZ\r" . $msgtext;
        } else {
            $msgtext = "\x01MSGID: $myaddr $MID\r\x01REPLY: $RPLY\r\x01TZUTC: $TZ\r" . $msgtext;
        }

        # Post message
        my $err = putMsgInArea($area, $myname, $fromname, $myaddr, $fromaddr, "$pngsub " . $subject, "", "Uns Loc Pvt K/s", $msgtext, 3);
        if ( defined($err) ) { 
            w_log('A', "Perl(): Can't make new message: $err"); 
        } else { 
            open( FLAG, ">>$flagfile" ) && close(FLAG); 
        }
    }
    return "";
}

w_log('U', "");
1;
