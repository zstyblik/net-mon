#!/usr/bin/perl
use Socket;

open (IN,"@ARGV[0]") || die "Cannot open file\n";
$port = @ARGV[1];
while (<IN>) {
	if ($_ =~ /open/) {
		$_=~ s/ /:/g;
		@server=split(/:/,$_);
		$serv=@server[2];
		$in_addr = (gethostbyname($serv))[4] || die("Error1: $!\n");
		$paddr = sockaddr_in($port, $in_addr) || die ("Error2: $!\n");
		$proto = getprotobyname('tcp') || die("Error: $!\n");
		socket(S, PF_INET, SOCK_STREAM, $proto) || die("Error3: $!\n");
		connect(S, $paddr) || die("Error4: $!\n");
		select(S); $| = 1; 
		select(STDOUT);
		print S "\n\r";
		$res=<S>;
		print "$serv : $res";
	}
}

