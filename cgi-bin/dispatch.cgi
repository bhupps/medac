#!/usr/bin/perl
use lib '../medac';
use strict;
use warnings;
use Data::Dumper;
use Medac::API;

my $api = new Medac::API();

eval {
	$api->dispatch();
};

if ($@) {
	$api->error("Error", $@);
}