package Medac::API::Default;
#use lib '../../../medac/Medac';

use Moose;

with 'Medac';

#extends 'Medac::API';

use strict;
use warnings;
use JSON::XS;
use File::Slurp;
use Data::Dumper;
use Slurp;
use CGI;
use POSIX;
use CGI::Carp qw(warningsToBrowser fatalsToBrowser);
use Cwd qw(abs_path cwd);

has 'exposed' => (
	is => 'ro',
	isa => 'ArrayRef',
	default => sub { return ['who']; }
);

has 'resource' => (
	is => 'rw',
	isa => 'HashRef',
	default => sub { return {}; }
);

# useful for debugging file permissions
sub who {
	my $self = shift @_;
	
	my @groups = split '\s', $(;
	my $gr = ();
	my %used = {};
	foreach my $g (@groups) {
		if (!$used{$g}) {
			my ($name,$passwd,$gid,$members) = getgrgid $g;
			push @{$gr}, {name => $name, id => $g};
		}
		$used{$g} = 1;
	}
	
	my $uinfo = {
		'root' => $< == 0 ? JSON::XS::true : JSON::XS::false,
		'user' => (getpwuid($<))[0],
		'groups' => $gr,
		'whoami' => `whoami`
	};
	
	$self->json_pr($uinfo, "Running as...");
}


sub exposedAction {
	my $self = shift @_;
	my $action = shift @_;
	
	foreach my $act (@{$self->exposed}) {
		if ($act eq $action) {
			return 1;
		}
	}
	
	return 0;
}

sub init {
	my $self = shift @_;
	
	my $prm = $self->drill($self->req,['params','posted']);
	
	if (!$prm) {
		$self->error("Invalid parameters.  No posted data.");
	}
	
	my $provider = $self->drill($prm, ['provider','name']); #,'name']);
	
	#$self->error('Error', $provider);
	
	my $resource = $self->drill($prm, ['resource']);
	
	if ($provider) {
		$self->provider($provider);
	}
	
	if ($resource) {
		$self->resource($resource);
	}
	
}

sub action {
  my $self = shift @_;
  my $action = shift @_;
  my $params = shift @_;
  
	$action =~ s/-/_/gi;
	
	
	if ($action =~ m/[^A-Za-z_]/gi) {
		$self->error("Invalid action: $action");
	}
	
	if ($self->can($action)) {
		if ($self->exposedAction($action)) {
			$self->init();
			$self->$action(@{$params->{numerical}});
		} else {
			$self->error("Unexposed action: $action");
		}
  } else {
    $self->error("Unimplemented action: $action");
  }
}

1;