package XMail::Ctrl;

use IO::Socket;
use vars qw($VERSION $AUTOLOAD);
use Carp;
use strict;

=head1 NAME

XMail::Ctrl - Crtl access to XMail server

www.xmailserver.com

=head1 VERISON

version 1.0 of XMail::Ctrl

released 07/06/2001

=head1 SYNOPSIS

	use XMail::Ctrl;
	my $XMail_admin      = "aaron.johnson";
	my $XMail_pass       = "stickman";
	my $XMail_port       = "6017";
	my $XMail_host       = "aopen.hank.net";
	my $test_domain      = "aopen.hank.net";
	my $test_user        = "rick";
		
	my $xmail = XMail::Ctrl->new( 
	            ctrlid   => "$XMail_admin",
				ctrlpass => "$XMail_pass",
				port     => "$XMail_port",
				host     => "$XMail_host" 
			) or die $!;
	
	my $au = $xmail->useradd( 
	        {
	            username => "$test_user",
			    password => 'test',
			    domain   => "$test_domain",
			    usertype => 'U' 
			}
			);
	
	$xmail->quit;

=head1 DESCRIPTION

This module allows for easy access to the Crtl functions for XMail.
It operates over TCP/IP so it can be used to communicate with either
Windows or Linux based XMail servers.

The code was written on a Win32 machine and has been tested on
Mandrake and Red Hat Linux as well with Perl version 5.6

=head2 Overview

All commands take the same arguments as outlined in the XMail
documentation.  All commands are processed by name and arguments can
be sent in the any order.  As is outlined above in the useradd
statement.

The command structure for XMail allows a fairly easy interface
to the command set.  This module has NO hardcoded xmail methods.
As long as the current ordering of commands is followed in the
XMail core the module should work to any new commands unchanged.

The "method" that you pass is automagicly (AUTOLOAD) turned
into a part of the arguments you are sending into the object.

That is when you call $xmail->useradd( { %args } );

It is passed to the xcommand method as a hash with the "method"
you called added to the %args, so $args{command} would equal
useradd in this case.  You can pass args in any order due to
XMails consistent ordering of ctrl variables.  The commands
are always in the same order.  So we loop through the array of
variables in the order XMail expects them and add them to the
"command" if a corresponding %args value is present.  Please
see the source for more information.

Any command that accepts vars can use the following:

To send uservarsset add a vars anonymous hash, such as:

	$xmail->uservarsset( {
	domain   => 'aopen.hank.net',
	username => 'rick',
	vars     => { 
		RealName      => 'Willey FooFoo',
		RemoteAddress => '300.000.000.3',
		VillageGrid   => '45678934' 
		} 
	} );

The ".|rm" command can used as described in the XMail docs.

=head1 BUGS

There must be some

=head1 AUTHOR

Aaron Johnson
aaron@provillage.com

=head1 THANKS

Thanks to Davide Libenzi for a sane mail server with
an incredibly consistent interface for external control.

Thanks to Mark-Jason Dominus for his wonderful classes at
the 2000 Perl University in Atlanta, GA where the power of
AUTOLOAD was revealed to me.

Thanks to my Dad for buying that TRS-80 in 1981 and getting
me addicted to computers.

Thanks to my wife for leaving me alone while I write me code
:^)

=head1 COPYRIGHT

Copyright (c) 2000, Aaron Johnson.  All rights Reserved.
This module is free software.  It may be used,  redistributed
and/or modified under the same terms as Perl itself.

=cut

# Perl interface to crtl for XMail
# Written by Aaron Johnson aaron@provillage.com

# Once you create a new xmail connection don't
# let it sit around too long or it will time out!

$VERSION = 0.60;

sub new {

	my ($class,%args) = @_;

	my $s = IO::Socket::INET->new( 
	            PeerAddr => "$args{host}",
                PeerPort => "$args{port}",
                Proto => 'tcp'
                );
	die "Can't connect: $@" unless $s;
	# clear the connect string from the buffer
	my ($ctest,$buf);
	while (1) {
		sysread $s, $buf, 1;
		if ($buf =~ /\n$/) {
			last;
		}
	}
	$s->flush;
	$buf = '';
	$s->print("$args{ctrlid}\t$args{ctrlpass}\r\n");

	# clear the buffer and test for successful connect
	while (1) {
		sysread $s, $buf, 1;
		if ($buf =~ /\n$/) {
			last;
		}
		
		$ctest .= $buf;
	}
	$s->flush;
	if ($ctest !~ m/^\+/) {
		die "Error: $ctest";
	}

	my $outmail = {
		_ctrlid   => $args{ctrlid},
		_ctrlpass => $args{ctrlpass},
		_port     => $args{port},
		_host     => $args{host},
		_io       => $s,
	};

	bless ($outmail , $class);
}

sub xcommand {

	my ($self,$args) = @_;

	my $s = $self->{_io};
	
	my @build_command = qw(
	domain
	alias
	mlusername
	username
	password
	mailaddress
	perms
	usertype
	loc-domain
	loc-username
	extrn-domain
	extrn-username
	extrn-password
	authtype
	realitive-file-path
	vars);
	
	my $command = $args->{command};
	delete $args->{command};
	foreach my $step (@build_command) {
	
		if (ref $args->{$step} ne "HASH") {
			$command .= "\t$args->{$step}" if $args->{$step};
		} else {
			foreach my $varname (keys %{$args->{$step}}) {
				$command .= 
				"\t$varname\t$args->{$step}{$varname}";

			}
		}
		
		delete $args->{$step};
	}
	$command .= "\r\n";

	$s->print($command);

	my ($test,$buf,$list);
	while (1) {
		sysread $s, $buf, 1;
		# stop reading if we have a newline unless we expect
		# a list
		if ($buf =~ /\n$/ && !$list) {
			last;
		}
		$test .= $buf;
		# lists have a response of +00100 from the server
		if ($test =~ /\+00100/) { $list = 1 }
		
		# stop reading if the string ends with
		# . return newline
		if ($test =~ /\.\r\n$/ && $list) {
			last;
		}
	
	}
	$list = '';
		
	if ($test !~ m/^\+/) {
		return "Error: $command $test"
	}

	$s->flush;
	return $test;
}

sub quit {
	my $self = shift;
	my $s = $self->{_io};
	$s->print("quit\r\n");
	$s->close();
	undef $self;
}

sub AUTOLOAD {
	my ($self,$args) = @_;
	
	$AUTOLOAD   =~ /.*::(\w+)/;
	my $command = $1;
	if ($command =~ /[A-Z]/) { exit }
	$args->{command} = "$command";
	$self->xcommand($args);
}

1;
