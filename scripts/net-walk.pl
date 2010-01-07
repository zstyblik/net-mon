#!/usr/bin/perl -w
# Simple Node availability monitor
# run from cron one per some period
# uses % mailto; command
# 2009/07/22 @ Zdenek Styblik
# 2009/07/29 @ last update
use strict;
use Net::LDAP;
use Net::LDAP::Constant;
use Net::Ping;
use DBI;
use Socket; 

# LDAP options;
my $ldapHost = 'ldaps://';
my $ldapPort = 636;
my $ldapVersion = 3;
my $ldapBindDN = 'cn=foo,dc=turnovfree,dc=net';
my $ldapPswd = '';
my $ldapTLS = 0;
my $ldapBaseDN = 'ou=net-mon,dc=turnovfree,dc=net';
my $ldapFilter = '(&(objectClass=ipHost)(objectClass=ipService))';
# DBI options;
my $dbiDSN = 'dbi:PgPP:dbname=net-mon;host=localhost;port=5432';
my $dbiUser = '';
my $dbiPswd = '';

# desc: ripped-off from 'http://korenofer.blogspot.com/2009/02/\
# simple-udp-port-scanner-in-perl-icmp_14.html' on 2009/22/07
# desc: thanks!!!
# desc: check node via ping
# desc: requires root privilege!
# $ip: string [ipv4];
# @return: bit;
sub checkICMP {
	my $ip = shift;
	my $p = Net::Ping->new( "icmp", 1, 64 );
	if ( $p->ping($ip) ) {
		return 1;
	} else {
		return 0;
	}
}

# desc: check if the node is alive via TCP
# $ipaddr: string [ipv4 addr];
# $proto: integer;
# @return: bit;
# ToDo: add validation for $ipaddr and $proto;
sub checkTCP {
	my ($ipaddr, $port) = @_;
	my $sock = IO::Socket::INET->new(
		PeerAddr => $ipaddr, 
		PeerPort => $port,
		Proto => 'tcp', 
	);
	return 0 unless $sock;
# sending data over TCP seems to be like waste...like whole TCP check.
#	my $ip = inet_aton($ipaddr);
#	my $portaddr = sockaddr_in(0, $ip);
#	my $bytes;
#	$bytes = $sock->send("Ping!\n", 0, $portaddr);
#	if ($bytes !~ length("Ping!\n")) {
#		close($sock);
#		return 0;
#	}
#	my ($datagram, $flags);
#	$sock->recv($datagram, 4, $flags);
#	close($sock);
#	return 0 unless $datagram;
	return 1;
}

# ToDo: this sh*t is broken;
# ToDo: this function doesn't actually work;
# ToDo: server doesn't reply to our UDP packets;
# ToDo: if somebody knows how to fix this/make it work, let me know;
# ToDo: time-out;
# desc: check if the node is alive via UDP;
# desc: unreliable because of nature of UDP;
# $ipaddr: string [ipv4 addr];
# $proto: integer;
# @return: bit;
sub checkUDP {
	my ($ipaddr, $port) = @_;
	my $message = IO::Socket::INET->new(
		PeerAddr=> $ipaddr,
		PeerPort => $port,
		Proto => 'udp',
	);
	die("Unable to create socket $@\n") unless $message;
	my $ip = inet_aton($ipaddr);
	my $portaddr = sockaddr_in($port, $ip);
	my $bytes = $message->send(0, 0, $portaddr);
	my ($datagram,$flags);
	$message->recv($datagram, 4, 0) or die("Mr.Foo");
	close($message);
	return 0 unless $datagram;
	return 1;
}

# connect to the LDAP server;
my $ldap = Net::LDAP->new($ldapHost, port=> $ldapPort, 
	version => $ldapVersion) 
	or die("Unable to connect LDAP server\n");
# send start_tls, eventually;
if ($ldapTLS =~ 1) {
 	my $msg = $ldap->start_tls;
	if (!$msg) {
 		die("Unable to LDAP start_tls\n");
	}
}
# bind to the LDAP server;
my $msg = $ldap->bind($ldapBindDN, password => $ldapPswd);
if (!$msg) {
 	die("Unable to bind to LDAP - wrong credentials?\n");
}
# search for the entries;
my $searchNodes = $ldap->search(base => $ldapBaseDN, 
	filter => $ldapFilter, scope => 'sub', attrs => ['*']);
if (!$searchNodes) {
	die("Found 0 entries, or failed search.\n");
}
my $entryCount = $searchNodes->count;
### DEBUG ###
#print "Search has returned $entryCount entries.\n";
# do only, if there are some entries;
if ($entryCount > 0) {
	my $dbh = DBI->connect($dbiDSN, $dbiUser, $dbiPswd)
		or die("Unable to connect do DB");
	my $date = `/usr/bin/date +'%Y-%m-%d %H:%M:%S'`;
	# presume all nodes have been updated at once and the last time 
	# they've been scanned is united. this can be, however, wrong.
	my $sqlSMaxTime = "SELECT MAX(log_time) AS max_log_time \
	FROM net_mon;";
	my $dbMaxTime = $dbh->selectrow_array($sqlSMaxTime) || undef;

	while (my $entry = $searchNodes->shift_entry()) {
		my $cn = $entry->get_value('cn');
		my $ipaddr = $entry->get_value('ipHostNumber');
		my $port = $entry->get_value('ipServicePort');
		my $proto = $entry->get_value('ipServiceProtocol');
		my $state;
		### DEBUG ###
#		print "### Checking: $ipaddr:$port\n";
		
		($state = &checkTCP($ipaddr, $port)) if $proto =~ 'tcp';
		($state = &checkUDP($ipaddr, $port)) if $proto =~ 'udp';
		($state = &checkICMP($ipaddr)) if $proto =~ 'icmp';

		my $stateStr = 'down';
		$stateStr = 'up' unless $state == 0;
		
		# in case DB is empty, or whatever.
		my $resultPrev = undef;
		if ($dbMaxTime) {
			my $sqlSPrev = "SELECT state FROM net_mon \
				WHERE dn = '".$entry->dn."' AND log_time = '$dbMaxTime';";
			$resultPrev = $dbh->selectrow_hashref($sqlSPrev);
		}
		# state is different than the last time. this should eliminate 
		# constant e-mailing about down [especially]. the question is, 
		# do we want to be notified about down->up ?
		my $subject;
		my $msg;
		my $doMail = 0;
		if (($resultPrev) && ($state != $resultPrev->{state})) {
			$doMail = 1;
			### DEBUG ###
#			print "Mailing changes!\n";
			my $statePrev = 'down';
			$statePrev = 'up' unless $resultPrev->{state} == 0;
			$subject = "[net-mon] $cn - '$stateStr'";
			$msg = "Stav zarizeni *$cn* ($ipaddr) se od posledni \
			kontroly '$dbMaxTime' zmenil z *$statePrev* na *$stateStr*. \
			Scan provedeny pres $proto.
			
			
			Webove rozhrani na http://www.turnovfree.net/net-mon/";
		}
		# we couldn't find previous evidence in db about this node.
		# strange huh?
		if (!$resultPrev) {
			$doMail = 1;
			### DEBUG ###
#			print "Mailing for the 1st time!\n";
			$msg = "Zarizeni $cn ($ipaddr) bylo scanovano prvne (?). \
			Scanovano pres '$proto'; stav: '$stateStr';
			
			
			Webove rozhrani na http://www.turnovfree.net/net-mon/";
			$subject = "[net-mon] $cn";
		}
		if ($doMail == 1) {
			my $managers = $entry->get_value('manager', asref => 1);
	 		foreach my $manager (@$managers) {
				my $mngrSearch = $ldap->search(base => $manager, 
					filter => '(objectClass=*)', scope => 'base', 
					attrs => '*');
				if ($mngrSearch->count == 1) {
					my $mngrEntry = $mngrSearch->entry(0);
					my $mngrMails = $mngrEntry->get_value('mail', asref => 1);
					foreach my $mngrEmail (@$mngrMails) {
						`echo '$msg' | mailto -s '$subject' $mngrEmail`;
					}
				}
			}
		}
		my $sqlInsert = "INSERT INTO net_mon (dn, log_time, state) \
		VALUES ('".$entry->dn."', '$date', '$state');";
		$dbh->do($sqlInsert);
	}
	$ldap->unbind;
	$ldap->disconnect;
	$dbh->disconnect;
}

