package XMail::Ctrl;

use IO::Socket;
use vars qw($VERSION $AUTOLOAD);
use Carp;
use strict;

$VERSION = 1.5;

=head1 NAME

XMail::Ctrl - Crtl access to XMail server

=head1 VERISON

version 1.5 of XMail::Ctrl

released 08/21/2002

=head1 SYNOPSIS

	use XMail::Ctrl;
	my $XMail_admin      = "aaron.johnson";
	my $XMail_pass       = "mypass";
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
	
	# setting the mailproc.tab

    my $proc = $xmail->usersetmproc(
            {
                username       => "$test_user",
			    domain         => "$test_domain",
			    output_to_file => "command for mailproc.tab",

			}
			 );
	
	$xmail->quit;

=head1 DESCRIPTION

This module allows for access to the Crtl functions for XMail.
It operates over TCP/IP. It can be used to communicate with either
Windows or Linux based XMail based servers.

The code was written on a Win32 machine and has been tested on
Mandrake and Red Hat Linux as well with Perl version 5.6 and 5.8

=head2 Overview

All commands take the same arguments as outlined in the XMail
(http://www.xmailserver.com) documentation.  All commands are
processed by name and arguments can be sent in the any order.

Example command from manual (is one line):
"useradd"[TAB]"domain"[TAB]"username"[TAB]"password"[TAB]"usertype"<CR><LF>

This turns into:
	
	$xmail->useradd( {
		domain => "domain.com",
		username => "username",
		password => "password",
		usertype => "U"
		}
		);

You can put the command parts in any order, they are put in the
correct order by the modules internals.

The command structure for XMail allows a fairly easy interface
to the command set.  This module has NO hardcoded xmail methods.
As long as the current ordering of commands is followed in the
XMail core the module should work to any new commands unchanged.

Any command that accepts vars can be used
by doing the following:

To send uservarsset (user.tab) add a vars anonymous hash,
such as:

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

If you are having problems you might want to turn on debugging
(new in 1.5)

	$xmail->debug(1);
	
to help you track down the cause.

=head2 Lists

Lists are now (as of 1.3) returned as an array reference unless
you set the raw_list method to true.

    $xmail->raw_list(1);

To print the lists you can use a loop like this:
    
    my $list = $xmail->userlist( { domain => 'yourdomin.net' } );
    foreach my $row (@{$list}) {
	print join("\t",@{$row}) . "\n";	
    }

Refer to the XMail documentation for each command for information
on which columns will be returned for a particular command.

You can send a noop (keeps the connection alive) with:

    $xmail->noop();

As of version 1.5 you can perform any froz command:
	
	$froz = $xmail->frozlist();

	foreach my $frozinfo (@{$froz}) {
        s/\"//g foreach @{$frozinfo};
        $res = $xmail->frozdel( {
                        lev0 => $frozinfo->[1] || '0',
                        lev1 => $frozinfo->[2] || '0',
                        msgfile => $frozinfo->[0],
                        });
        print $res , "\n";
	}

=head1 BUGS

Possible problems dealing with wild card requests.  I have
not tested this fully.  Please send information on what you
are attempting if you feel the module is not providing the
correct function.

=head1 AUTHOR

Aaron Johnson
solution@gina.net

=head1 THANKS

Thanks to Davide Libenzi for a sane mail server with
an incredibly consistent interface for external control.

Thanks to Mark-Jason Dominus for his wonderful classes at
the 2000 Perl University in Atlanta, GA where the power of
AUTOLOAD was revealed to me.

Thanks to my Dad for buying that TRS-80 in 1981 and getting
me addicted to computers.

Thanks to my wife for leaving me alone while I write my code
:^)

Thanks to Oscar Sosa for spotting the lack of support for
editing the 'tab' files

=head1 CHANGES

Changes file included in distro

=head1 COPYRIGHT

Copyright (c) 2000,2001,2002 Aaron Johnson.  All rights Reserved.
This module is free software.  It may be used,  redistributed
and/or modified under the same terms as Perl itself.

=cut

# Perl interface to crtl for XMail
# Written by Aaron Johnson solution@gina.net

# Once you create a new xmail connection don't
# let it sit around too long or it will time out!

sub new {

    my ($class,%args) = @_;

    my $s = IO::Socket::INET->new( 
			PeerAddr => "$args{host}",
			PeerPort => "$args{port}",
			Proto => 'tcp'
	    );
    die "Can't connect: $@" unless $s;
    # clear the connect string from the buffer

    my $outmail = {
	_ctrlid   => $args{ctrlid},
	_ctrlpass => $args{ctrlpass},
	_port     => $args{port},
	_host     => $args{host},
	debug     => $args{debug} || 0,
	};
		
	
    my ($ctest,$buf);
    while (1) {
		sysread $s, $buf, 100;
		if ($buf =~ /\n$/) {
			last;
		}
    }
    $s->flush;
    $buf = '';
    $s->print("$args{ctrlid}\t$args{ctrlpass}\r\n");

    # clear the buffer and test for successful connect
    while (1) {
		sysread $s, $buf, 100;
		$ctest .= $buf;
		print "LOGIN BUFFER: $buf\n" if $args{debug};
		if ($ctest =~ /\n$/) {
			last;
		}
    }
    $s->flush;
    if ($ctest !~ m/^\+/) {
	    die "Error: $ctest";
    }

	$outmail->{_io} = $s;

    bless ($outmail , $class);
}

sub debug {
	my ($self,$val) = @_;
	if ($val || ord($val) == 48) {
		$self->{debug} = $val;
	} else {
		return $self->{debug};
	}
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
    relative-file-path
    vars
	lev0
	lev1
	msgfile
	);
    
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

    my ($test,$list,$proc);
    while (1) {
		my $buf;
		sysread $s, $buf, 1000;
		# stop reading if we have a newline unless we expect
		# a list
		print "BUFFER: $buf\n" if $self->debug();
		$test .= $buf;
		last if !$buf;
		if ($test =~ /\+00100/) { $list = 1 }
		if ($test =~ /\+00101/) { $proc = 1 }
	
		if ($buf =~ /\n$/ && !$list && !$proc) {
			last;
		}
	
		
	
		if ($buf =~ /\n$/ && $proc) {
			$s->print($args->{output_to_file} . "\n.\r\n");
			$proc = '';
			last;
		}
		
		# stop reading if the string ends with
		# . return newline
		if ($test =~ /\.\r\n$/ && $list) {
			last;
		}
		
    }
    
    if ($list && !$self->raw_list()) {
		my $array_ref;
		my @rows = split(/\r\n/,$test);
		pop @rows;
		shift @rows;
		my $count = 0;
		foreach my $row (@rows) {
			$array_ref->[$count] = [ split(/\t/,$row) ];
			$count++;
		}
		$test = $array_ref if $array_ref;    
    }

    $list = '';
	    
    if ($test !~ m/^\+/ && ref($test) ne "ARRAY") {
		return "Error: $command $test"
    }

    $s->flush;
    return $test;
}

sub raw_list {
    my ($self,$value) = @_;
    if ($value) {
	$self->{raw_list} = $value;
    }
    else {
	return $self->{raw_list};
    }
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
