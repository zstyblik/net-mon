#!/usr/bin/perl -w
use strict;
use lib '../perl/';
use NetMon;
my $webapp = NetMon->start();
print "Content-type: text/html; charset=utf-8\n\n";
print $webapp;
