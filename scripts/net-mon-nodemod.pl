#!/usr/bin/perl
# Net-mon Add Node LDIF Generator
# part of the Net-mon
#
# 2009/Sep/25 @ Zdenek Styblik
#
my $dn = 'dc=turnovfree,dc=net';
my $dnPeople = sprintf("ou=people,%s", $dn);

sub addNode 
{
	## CN
	my $cn = undef;
	while ($cn !~ /^[A-Za-z0-9].+$/) 
	{
		printf "Enter node name [foo]: ";
		$cn = <STDIN>;
		chomp($cn);
		printf "\n";
	} # while $cn
	## LOCATION
	printf "Enter location of node [moon]: ";
	my $l = <STDIN>;
	chomp($l);
	printf "\n";
	## IP
	printf "IP address of node [192.168.1.1]: ";
	my $ip = <STDIN>;
	chomp($ip);
	printf "\n";
	## PORT
	my $port = undef;
	while ($port !~ /^[0-9].+$/) 
	{
		printf "Port on node to poke at [80]: ";
		$port = <STDIN>;
		chomp($port);
		printf "\n";
	} # while $port
	## PROTOCOL
	my $proto = undef;
	while (1 > 0) 
	{
		printf "Protocol to use [icmp/udp/tcp]: ";
		$proto = <STDIN>;
		chomp($proto);
		printf "\n";
		if ($proto eq 'icmp')
		{
			last;
		} elsif ($proto eq 'udp')
		{
			last;
		} elsif ($proto eq 'tcp')
		{
			last;
		} # if $proto
	} # while $go
	## MANAGER
	my $managerUid = undef;
	while ($managerUid !~ /^[A-Za-z0-9]{1,}+$/) 
	{
		printf "Manager of device\n";
		printf "0 - disable\n";
		printf "Manager UID [admin]: ";
		$managerUid = <STDIN>;
		chomp($managerUid);
		printf "\n";
	} # while $managerUid
	## WRITE FILE
	my $file = sprintf("%s.add.ldif", $cn);
	open(FILE, '>', $file) or die("Unable to open '$0' for writing.");
	printf FILE "# cn=%s,ou=net-mon,%s\n", $cn, $dn;
	printf FILE "dn: cn=%s,ou=net-mon,%s\n", $cn, $dn;
	printf FILE "objectClass: ipHost\n";
	printf FILE "objectClass: top\n";
	printf FILE "objectClass: ipService\n";
	printf FILE "l: %s\n", $l;
	printf FILE "ipServicePort: %s\n", $port;
	printf FILE "ipHostNumber: %s\n", $ip;
	printf FILE "cn: %s\n", $cn;
	printf FILE "ipServiceProtocol: %s\n", $proto;
	if ($managerUid ne "0") 
	{
		printf FILE "manager: uid=%s,%s\n", $managerUid, $dnPeople;
	} # if $managerUid
	close(FILE) or die("Unable to close '$0', already closed?");
	return 0;
} # sub addNode

sub help 
{
	printf "Net-mon Add node LDIF generator\n";
	printf "Usage:\n";
	printf "  -a\tadd node\n";
	printf "  -h\tprint this help\n";
	printf "\n";
	return 0;
} # sub help

## MAIN
my $argNo = $#ARGV;

if ($argNo != 1)
{
	&help;
	exit 1;
} # if $argNo

my $argument = $ARGV[0]; 

if ($argument eq '-a')
{
	&addNode();
} elsif ($argument eq '-h')
{
	&help();
} else
{
	&help();
} # if $argument

