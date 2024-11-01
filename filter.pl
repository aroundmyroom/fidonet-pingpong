#  --- Example filter.pl ---
#
# it is called from husky's config 
# 
# hptperlfile /etc/husky/filterpong.pl
# I added the @PATH part /etc/husky so that
# filter.pl and pong.pl can work together
#
# --- end Example filter.pl ---

use lib '/etc/husky';
BEGIN { require "pong.pl"; }
  sub filter{
    &pong;
  }


