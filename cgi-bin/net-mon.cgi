#!/usr/bin/perl -w
use strict;
use warnings;

use lib '../perl/';
use NetMon;

my $configFile = '../conf/config.sh';
my $webapp = NetMon->start($configFile);
print "Content-type: text/html; charset=utf-8\n\n";
print $webapp;
