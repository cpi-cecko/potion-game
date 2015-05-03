#!/usr/bin/perl

use v5.12;
use strict;
use warnings;

use AnyEvent;
use AnyEvent::Handle;
use AnyEvent::Socket;

use List::MoreUtils;


#my %clients = {
#    id => {
#        name => "myName",
#        token => "ownedToken",
#        guess => "",
#        handle => <sock_handle>,
#    }
#}

my %clients;
my $currentName;

sub client_register($ $ $) {
    my ($handle, $line, $eol) = @_;

    for my $cl (values %clients) {
        if ($cl->{handle} eq $handle) {
		if( &isHere ( \%clients , $line )){

			$handle->push_write("Username already taken$eol" . " Choose anothe one: ");
			$handle->push_read( line => sub { client_register( $_[0] , $_[1] , $_[2] )} ) ;	
		}
		else{
			$cl->{name} = $line;
    			$handle->push_write("Registered!$eol" . "Another feature coming soon.. ");
		}
		last;
        }
    }

}

sub isHere ( $ $ ) { 
	my ($hashRef , $name ) = @_;

	for my $value ( values %$hashRef ) {
		if ( defined($value->{name}) && $value->{name} eq $name) {
			return 1;
		}
	}
	
	return 0;
}

sub client_play($ $ $) {
    my ($handle, $line, $eol) = @_;

    for my $cl (values %clients) {
        if ($cl->{handle} eq $handle) {
            say "$cl->{name} sent $line";
            last;
        }
    }

    $handle->push_write("Please send sth$eol");
    $handle->push_read(line => sub { client_play($_[0], $_[1], $_[2]); });
}

MAIN:
{
    my $cv = AnyEvent->condvar();

    my $clientId = 0;
   
    tcp_server "127.0.0.1", 3082, sub {
        my ($fh, $host, $port) = @_;

        say "A connection from $host:$port";

        my $id = $clientId++;
        my $w = AnyEvent::Handle->new(fh => $fh,
            on_error => sub {
                say "Something bad happened with client at ($host:$port)";
                delete $clients{$id};
            },
            on_eof => sub {
                say "Client ($host:$port) went away";
                delete $clients{$id};
            },
        );
        $clients{$id}->{handle} = $w;

        $w->push_write("Hello there!\r\nName, please: ");
        $w->push_read(line => sub { client_register($_[0], $_[1], $_[2]) });
    };

    $cv->recv();
}
