#!/usr/bin/perl
use FindBin;
use JSON::XS;
use strict;
use warnings;
use Data::Dumper;
use File::Basename;
use POSIX;
use Config::Auto;
use Medac::Metadata::Source::IMDB;
use Medac::Metadata::Source::Plex;
use Medac::Cache;
use Getopt::Long;


# Config

my $config = {};
my $host_name = 0;
my $port = 32400;
my $username = 0;
my $password = 0;
my $config_file = 0;

#my $image_base = 0;
#my $from_email = 0;
#my $to_email = 0;
#my $subject = 0;
#my $email_pass;

my $script_started = time();
my $action_started;

GetOptions(
	'config=s' => \$config_file
);

if ($config_file && -f $config_file) {
	my $file_data = read_file($config_file);
	$config = decode_json($file_data);
	
	$host_name = $config->{hostname} || $host_name;
	$port =  $config->{port} || $port;
	$username = $config->{username} || $username;
	$password = $config->{password} || $password;
} else {
	GetOptions(
		'm|max|maxdays=i' => \$max_days,
		'h|host|hostname=s' => \$host_name,
		'p|port' => \$port,
		'u|user|username=s' => \$username,
		'pass|password=s' => \$password,
	);
}

# End Config


my $imdb = new Medac::Metadata::Source::IMDB();


my $plex = new Medac::Metadata::Source::Plex(
	hostname => $host_name,
	port => $port,
	username => $username,
	password => $password,
	maxage => $max_days * 60 * 60 * 24
);

