#!/usr/bin/perl -w
package NetMon;
use DBI;
use HTML::Template;

use warnings;
use strict;

sub start 
{
	my $self = shift;
	my $configFile = shift || '../conf/config.sh';
	if ( ! -e $configFile )
	{
		my $retStr = sprintf("Config file '%s' not found or not readable.\n", 
			$configFile);
		return $retStr;
	}
	my %CFG;
	open(FH_CONFIG, '<', $configFile) or die("Unable to open '$!' for reading.");
	while (my $cfgLine = <FH_CONFIG>)
	{
		chomp($cfgLine);
		$cfgLine =~ s/^\s+//g;
		$cfgLine =~ s/\s+$//g;
		if (!$cfgLine)
		{
			next;
		} # if ! $cfgLine
		if ($cfgLine =~ /^#/)
		{
			next;
		} # if $cfgLine
		my $pos = index($cfgLine, '=');
		my $key = substr($cfgLine, 0, $pos);
		my $val = substr($cfgLine, $pos+1);
	#	my ($key, $val) = split(/=/, $cfgLine);
		$CFG{$key} = $val;
	} # while $line
	close(FH_CONFIG) or die("Unable to close '$!'; already closed?");

	my $dbh = DBI->connect($CFG{'dbiDSN'}, $CFG{'dbiUser'}, $CFG{'dbiPswd'});
	if (!$dbh) 
	{
			my $msg = "Unable to connect do DB";
			return $msg;
	} # if !$dbh

	my $sqlSMaxTime = "SELECT MAX(log_time) AS max_log_time \
	FROM net_mon;";
	my $dbMaxTime = $dbh->selectrow_array($sqlSMaxTime) || undef;

	my $sqlSNodes = sprintf("SELECT * FROM net_mon WHERE \
	log_time = '%s' ORDER BY dn;", $dbMaxTime);
	my $resultNodes = $dbh->selectall_arrayref($sqlSNodes, 
		{ Slice => {} });
	my @nodes = qw();
	foreach my $node (@$resultNodes) 
	{
		my $name = $node->{dn};
		my $cutoff = index($name, ',');
		if (($cutoff - 3) > 0) 
		{
			$cutoff = $cutoff - 3;
		}
		$name = substr($name, 3, $cutoff);
		my $state = 'chyba';
		my $stateClass = 'state-fail';
		my $downTime = '';
		if ($node->{state} == 1) 
		{
			$state = 'ok';
			$stateClass = 'state-ok';
		} else
		{
			my $sqlSLastUp = sprintf("SELECT MAX(log_time) FROM net_mon WHERE \
				dn = '%s' AND state = '1';", $name);
			my $lastUp = $dbh->selectrow_array($sqlSLastUp);
			my $sqlSChangeSt = sprintf("SELECT MIN(log_time) FROM net_mon WHERE \
				dn = '%s' AND state = '0' AND log_time > '%s' LIMIT 1;", $name, 
				$lastUp);
				$downTime = sprintf("[%s]", $dbh->selectrow_array($sqlSChangeSt));
		} # if node->{state}
		my %item = ( NODE => $name,
			STATECLASS => $stateClass,
			STATE => $state,
			DOWNTIME => $downTime,
		);
		push(@nodes, \%item);
	} # foreach $node
	my $tmplFile = sprintf("%s/net-mon.tmpl", $CFG{'tmplPath'});
	my $template = HTML::Template->new(filename => $tmplFile);
	$template->param('LASTCHECK', $dbMaxTime);
	$template->param(NODES => \@nodes);

	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$year = $year + 1900;
	$mon = $mon + 1;
	my $date = sprintf("%.4i-%.2i-%.2i %.2i:%.2i:%.2i\n", $year, $mon, $mday, 
		$hour, $min, $sec);

	$template->param('DATECURR', $date);
	return $template->output;
} # sub start

1;
