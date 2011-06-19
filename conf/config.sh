#!/bin/false
ldapHost=ldapi://
ldapPort=389
ldapVersion=3
ldapDN=dc=turnovfree,dc=net
ldapBindDN=cn=foo
ldapPswd=
ldapTLS=0
ldapBaseDN=ou=net-mon
ldapFilter=(&(objectClass=ipHost)(objectClass=ipService))

dbiDSN=dbi:PgPP:dbname=net-mon;host=localhost;port=5432
dbiUser=
dbiPswd=

tmplPath=../template/
localAddress=
smtpServer=localhost
mailSender=root@localhost
