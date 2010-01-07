#!/usr/bin/perl
use strict;
use lib '/home/stybla/work/turnovfree/net-mon/';
use NetMon;
my $webapp = NetMon->start;
print "Content-type: text/html; charset=utf-8\n\n";
print $webapp;
