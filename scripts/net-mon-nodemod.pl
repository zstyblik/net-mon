#!/usr/bin/perl
# Net-mon Add Node LDIF Generator
# part of the Net-mon
#
# See help for usage
#
# 2009/Sep/25 @ Zdenek Styblik
#
use Switch;

my $dn = 'dc=turnovfree,dc=net';
my $dnPeople = 'ou=people'.$dn;

sub addNode {
## CN
	my $cn = undef;
	while ($cn !~ /^[A-Za-z0-9].+$/) {
		print "Enter node name [foo]: ";
		$cn = <STDIN>;
		chomp($cn);
		print "\n";
	}
## LOCATION
	print "Enter location of node [moon]: ";
	my $l = <STDIN>;
	chomp($l);
	print "\n";
## PORT
	my $port = undef;
	while ($port !~ /^[0-9].+$/) {
		print "Port on node to poke at [80]: ";
		$port = <STDIN>;
		chomp($port);
		print "\n";
	}
## IP
	print "IP address of node [192.168.1.1]: ";
	my $ip = <STDIN>;
	chomp($ip);
	print "\n";
## PROTOCOL
	my $proto = undef;
	my $go = 0;
	while ($go == 0) {
		print "Protocol to use [icmp/udp/tcp]: ";
		$proto = <STDIN>;
		chomp($proto);
		print "\n";
		switch ($proto) {
			case 'icmp'	{ $go = 1 }
			case 'udp'	{ $go = 1 }
			case 'tcp'	{ $go = 1 }
			else				{ $go = 0 }
		}
	}
## MANAGER
	my $managerUid = undef;
	while ($managerUid !~ /^[A-Za-z0-9]{1,}+$/) {
		print "Manager of device\n";
		print "0 - disable\n";
		print "Manager UID [admin]: ";
		$managerUid = <STDIN>;
		chomp($managerUid);
		print "\n";
	}
## WRITE FILE
	my $file = '>'.$cn.'.add.ldif';
	open(FILE, $file);
	print FILE "# cn=$cn,ou=net-mon,$dn\n";
	print FILE "dn: cn=$cn,ou=net-mon,$dn\n";
	print FILE "objectClass: ipHost\n";
	print FILE "objectClass: top\n";
	print FILE "objectClass: ipService\n";
	print FILE "l: $l\n";
	print FILE "ipServicePort: $port\n";
	print FILE "ipHostNumber: $ip\n";
	print FILE "cn: $cn\n";
	print FILE "ipServiceProtocol: $proto\n";
	if ($managerUid !~ /^[0]{1}$/) {
		print FILE "manager: uid=$managerUid,$dnPeople\n";
	}
	close FILE;
	return 0;
}

sub help {
	print "Net-mon Add node LDIF generator\n";
	print "Help:\n";
	print "	-a	add node\n";
	print "	-h	print this help\n";
	print "\n";
	return 0;
}

## MAIN
switch ($ARGV[0]) {
	case '-a'	{ addNode }
	case '-h'	{ help }
	else			{ help }
}

