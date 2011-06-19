#!/usr/bin/perl -w
package NetMon;
use DBI;
use HTML::Template;

use warnings;
use strict;

sub start 
{
	# DBI params;
	my $dbiDSN = 'dbi:PgPP:dbname=net-mon;host=10.117.0.1;port=5432';
	my $dbiUser = '';
	my $dbiPswd = '';
	# Other params;
	my $tmplPath = "./net-mon/";

	my $dbh = DBI->connect($dbiDSN, $dbiUser, $dbiPswd);
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
		if ($node->{state} == 1) 
		{
			$state = 'ok';
			$stateClass = 'state-ok';
		} # if node->{state}
		my %item = ( NODE => $name,
			STATECLASS => $stateClass,
			STATE => $state,
		);
		push(@nodes, \%item);
	} # foreach $node
	my $tmplFile = sprintf("%s/net-mon.tmpl", $tmplPath);
	my $template = HTML::Template->new(filename => $tmplFile);
	$template->param('LASTCHECK', $dbMaxTime);
	$template->param(NODES => \@nodes);
	my $date = `/usr/bin/date +'%Y-%m-%d %H:%M:%S'`;
	$template->param('DATECURR', $date);
	return $template->output;
} # sub start

1;
