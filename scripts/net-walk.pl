#!/usr/bin/perl -w
# Desc: Simple Node availability monitor; run via cron once per some period
# 2009/07/22 @ Zdenek Styblik
use strict;
use warnings;

use DBI;
use Mail::Sendmail;
use Net::LDAP::Constant;
use Net::LDAP;
use Net::Ping;
use Socket;
### CONFIG
my $configFile = "../conf/config.sh";
my $debug = 0;

# desc: check node via Ping ICMP which requires *root* privilege!
# $ip: string [ipv4];
# $localAddress: string [ipv4];
# @return: bit;
sub checkICMP 
{
	my $ip = shift;
	my $localAddress = shift || undef;
	my $timeout = 1;
	my $p = Net::Ping->new("icmp", $timeout, 64);
	if ($localAddress)
	{
		$p->bind($localAddress);
	}
	my $retVal = 0;
	my $counter = 0;
	while ($counter < 3)
	{
		if ($p->ping($ip, $timeout) && $retVal == 0) 
		{
			$retVal = 1;
		} # if $p->ping
		$counter++;
	}
	$p->close();
	return $retVal;
} # sub checkICMP
# desc: check if the node is alive via TCP
# $ipaddr: string [ipv4 addr];
# $proto: integer;
# @return: bit;
sub checkTCP 
{
	my $ipaddr = shift || undef;
	my $port = shift || undef;
	unless ($ipaddr || $port)
	{
		return 0;
	} # unless $ipaddr || $port
	if ($port !~ /^[0-9]+$/)
	{
		return 0;
	} # if $port
	my $sock = IO::Socket::INET->new(
		PeerAddr => $ipaddr, 
		PeerPort => $port,
		Proto => 'tcp', 
	);
	my $retVal = 0;
	if ($sock)
	{
		$retVal = 1;
		$sock->close();
	}
	return $retVal;
} # sub checkTCP
# NOTE: Untested/no-worky!
# desc: check if the node is alive via UDP; unreliable because of UDP
# $ipaddr: string [ipv4 addr];
# $proto: integer;
# @return: bit;
sub checkUDP 
{
	my $ipaddr = shift || undef;
	my $port = shift || undef;
	unless ($ipaddr || $port)
	{
		return 0;
	} # unless $ipaddr || $port
	if ($port !~ /^[0-9]+$/)
	{
		return 0;
	} # if $port
	my $message = IO::Socket::INET->new(
		PeerAddr=> $ipaddr,
		PeerPort => $port,
		Proto => 'udp',
		Timeout => 2,
	);
	unless ($message)
	{
		return 0;
	} # unless $message
	my $ip = inet_aton($ipaddr);
	my $portaddr = sockaddr_in($port, $ip);
	my $bytes = $message->send(0, 0, $portaddr);
	my ($datagram, $flags);
	my $retVal = 0;
	if ( $message->recv($datagram, 4, 0) )
	{
		$retVal = 1;
	} else
	{
		$retVal = 0;
	} # if $message->recv
	close($message);
	if ($datagram)
	{
		$retVal = 1;
	} else
	{
		$retVal = 0;
	} # if $datagram
	return $retVal;
} # sub checkUDP

### MAIN ###
if ( ! -e $configFile )
{
	die("Config file '$configFile' doesn't exist or not readable.");
} # if ! -e $configFile

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

# connect to the LDAP server;
my $ldap = Net::LDAP->new(
	$CFG{'ldapHost'}, 
	port=> $CFG{'ldapPort'}, 
	version => $CFG{'ldapVersion'},
)	or die("Unable to connect LDAP server\n");
# send start_tls, eventually;
if ($CFG{'ldapTLS'} =~ 1) 
{
 	my $msg = $ldap->start_tls;
	if (!$msg) 
	{
 		die("Unable to LDAP start_tls\n");
	} # if !$msg
} # if $ldapTLS

# bind to the LDAP server;
my $ldapBindDN = sprintf("%s,%s", $CFG{'ldapBindDN'}, $CFG{'ldapDN'});
my $msg = $ldap->bind($ldapBindDN, password => $CFG{'ldapPswd'});
if (!$msg) 
{
 	die("Unable to bind to LDAP - wrong credentials?\n");
} # if !$msg

# search for the entries;
my $searchNodes = $ldap->search(
	base => $CFG{'ldapBaseDN'}, 
	filter => $CFG{'ldapFilter'}, 
	scope => 'sub', 
	attrs => ['*']
);
if (!$searchNodes) 
{
	die("Found 0 entries, or failed search.\n");
} # if !$searchNodes
my $entryCount = $searchNodes->count;
if ($debug != 0)
{
	printf("Search has returned %i entries.\n", $entryCount);
} # if $debug
if ($entryCount < 1) 
{
	$ldap->unbind;
	$ldap->disconnect;
	exit 0
}
my $dbh = DBI->connect($CFG{'dbiDSN'}, $CFG{'dbiUser'}, $CFG{'dbiPswd'}) 
	or die("Unable to connect do DB");

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
$year = $year + 1900;
$mon = $mon + 1;
my $date = sprintf("%.4i-%.2i-%.2i %.2i:%.2i:%.2i\n", $year, $mon, $mday, 
	$hour, $min, $sec);

# presume all nodes have been updated at once and the last time 
# they've been scanned is united. this can be, however, wrong.
my $sqlSMaxTime = "SELECT MAX(log_time) AS max_log_time \
	FROM net_mon;";
my $dbMaxTime = $dbh->selectrow_array($sqlSMaxTime) || undef;

while ( my $entry = $searchNodes->shift_entry() ) 
{
	my $cn = $entry->get_value('cn');
	my $ipaddr = $entry->get_value('ipHostNumber');
	my $port = $entry->get_value('ipServicePort');
	my $proto = $entry->get_value('ipServiceProtocol');
	my $state = 0;
	if ($debug != 0)
	{
		printf("### Checking: %s:%i\n", $ipaddr, $port);
	} # if $debug
	if ($proto eq 'tcp') 
	{
		$state = &checkTCP($ipaddr, $port);
	} elsif ($proto eq 'udp')
	{
		$state = &checkUDP($ipaddr, $port);
	} elsif ($proto eq 'icmp')
	{
		$state = &checkICMP($ipaddr, $CFG{'localAddress'});
	} else
	{
		printf("Unsupported/unknown proto '%s'\n", $proto);
		next;
	}# if $proto
	my $stateStr = 'down';
	if ($state != 0)
	{
		$stateStr = 'up';
	} # if $state != 0
	# in case DB is empty, or whatever.
	my $resultPrev = undef;
	if ($dbMaxTime) 
	{
		my $sqlSPrev = sprintf("SELECT state FROM net_mon WHERE \
			dn = '%s' AND log_time = '%s';", $entry->dn, $dbMaxTime);
		$resultPrev = $dbh->selectrow_hashref($sqlSPrev);
	} # if $dbMaxTime
	# state is different than the last time. this should eliminate 
	# constant e-mailing about down [especially]. the question is, 
	# do we want to be notified about down->up ?
	my $subject;
	my $msg;
	my $doMail = 0;
	if (($resultPrev) && ($state != $resultPrev->{state})) 
	{
		$doMail = 1;
		if ($debug != 1)
		{
			printf("The state of node has changed -> mail.\n");
		} # if $debug
		my $statePrev = 'down';
		if ($resultPrev->{state} != 0)
		{
			$statePrev = 'up';
		} # if $resultPrev
		$subject = sprintf("[net-mon] %s - '%s'", $cn, $stateStr);
		$msg = "Stav zarizeni *$cn* ($ipaddr) se od posledni \
		kontroly '$dbMaxTime' zmenil z *$statePrev* na *$stateStr*. \
		Scan provedeny pres $proto.
		
		
		Webove rozhrani na http://www.turnovfree.net/net-mon/";
	} # if $resultPrev
	# we couldn't find previous evidence in db about this node.
	# strange huh?
	if (!$resultPrev) 
	{
		$doMail = 1;
		if ($debug != 0)
		{
			printf("Node not found in DB -> scanned for the 1st time -> mail.\n");
		} # if $debug
		$msg = "Zarizeni $cn ($ipaddr) bylo scanovano prvne (?). \
		Scanovano pres '$proto'; stav: '$stateStr';
		
		
		Webove rozhrani na http://www.turnovfree.net/net-mon/";
		$subject = sprintf("[net-mon] %s", $cn);
	} # if !$resultPrev
	if ($doMail == 1) 
	{
		my $managers = $entry->get_value('manager', asref => 1);
 		foreach my $manager (@$managers) 
		{
			my $mngrSearch = $ldap->search(
				base => $manager, 
				filter => '(objectClass=*)', 
				scope => 'base', 
				attrs => '*'
			);
			if ($mngrSearch->count == 1) 
			{
				my $mngrEntry = $mngrSearch->entry(0);
				my $mngrMails = $mngrEntry->get_value('mail', asref => 1);
				foreach my $mngrEmail (@$mngrMails) 
				{
					my %mail = (
						From => $CFG{'mailSender'},
						Subject => $subject,
						'X-Mailer' => "Mail::Sendmail version $Mail::Sendmail::VERSION",
					);
					$mail{'Content-Type'} = 'text/plain; charset=UTF-8';
					$mail{'smtp'} = $CFG{'smtpServer'};
					$mail{'message :'} = $msg;
					$mail{'To :'} = $mngrEmail;
				} # foreach $mngrEmail
			} # if $mngrSearch
		} # foreach $manager
	} # if $doMail
	my $sqlInsert = sprintf("INSERT INTO net_mon (dn, log_time, state) \
		VALUES ('%s', '%s', '%s');", $entry->dn, $date, $state);
	$dbh->do($sqlInsert);
} # while $entry

$ldap->unbind;
$ldap->disconnect;
$dbh->disconnect;

