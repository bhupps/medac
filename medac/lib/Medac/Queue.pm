package Medac::Queue;

use Moose;

with 'Medac::Config';
with 'Medac::Response';
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

has queued => (
	is => 'rw',
	isa => 'ArrayRef',
	default => sub { return []; }
); 

sub ensureQueueExists {
	my $self = shift @_;
	my $provider = shift @_;
	
	my $dl_dir = $self->drill(['paths','downloads']);
	
	if (!$dl_dir) {
		$self->error("No download path specified in config");
	}
	
	my $pr_name = $provider;
	if (defined $provider->{name}) {
		$pr_name = $provider->{name};
	} elsif (defined $provider->info) {
		$pr_name = $provider->info->{name};
	} 
	
	
	$self->error("dl_dir = '$dl_dir', pr_nname = '$pr_name'");
	
	my $pr_dl_dir = $dl_dir . $pr_name . '/';
	if (! -d $pr_dl_dir) {
		mkdir $pr_dl_dir or $self->error("Can't create DL path \"$pr_dl_dir\": $!");
		chmod(0775, $pr_dl_dir);
	}
	
	
	my $provider_file = $pr_dl_dir . 'provider.json';
	if (! -f $provider_file) {
		write_file($provider_file, encode_json($provider));
	}
	
	my $queue_file = $pr_dl_dir . 'queue.json';
	my $queue = [];
	
	if (! -f $queue_file) {
		$self->writeQueue($provider, $queue);
		chmod(0775, $queue_file);
	}
	
	return $queue_file;
	
}

sub readQueue {
	my $self = shift @_;
	my $provider = shift @_;
	
	$self->provider($self->providerName($provider));
	
	my $queue_file = $self->queueFile($provider); #$self->ensureQueueExists($provider);
	my $queue = [];
	
	if (-f $queue_file) {
		$queue = decode_json(read_file($queue_file) || encode_json($queue));
	} else {
		$self->error("Missing queue file; cannot create: $queue_file");
	}
	
	eval {
		$self->queued($queue);
	};
}

sub writeQueue {
	my $self = shift @_;
	
	my $provider = shift @_ || $self->provider;
	my $queue_data = shift @_ || $self->queued;
	
	my $queue_file = $self->queueFile($provider); #$self->ensureQueueExists($provider);
	my $dl_dir = $self->drill(['paths','downloads']);
	
	if (!$dl_dir) {
		$self->error("No download path specified in config");
	}
	
	#$self->provider($provider);
	
	my $pr_dl_dir = $dl_dir . $self->providerName($provider) . '/';
	
	if (! -d $pr_dl_dir) {
		mkdir $pr_dl_dir, 0775 or $self->error("Can't create DL path \"$pr_dl_dir\": $!");
	}
	
	my $provider_file = $pr_dl_dir . 'provider.json';
	if (! -f $provider_file) {
		write_file($provider_file, encode_json($provider));
	}
	
	
	
	write_file($queue_file, encode_json($queue_data));
}

sub enqueue {
	my $self = shift @_;
	my $resource = shift @_;
	
	my $in_queue = $self->inQueue($resource);
	
	#$self->error('Whoops!', $self->provider);
	
	if (defined $in_queue) {
		$self->json_pr({already_queued => JSON::XS::true}, "File already queued");
	} else {
		push @{$self->queued()}, $resource;
		$self->writeQueue();
		$in_queue = $self->inQueue($resource);
		if (defined $in_queue) {
			$self->json_pr({already_queued => JSON::XS::false, queue => $self->queued}, "File enqueued");
		} else {
			$self->error("Enqueue failed", {queue => $self->queued, resource => $resource});
		}
	}
}

sub dequeue {
	my $self = shift @_;
	my $resource = shift @_;
	
	my $idx = $self->inQueue($resource);
	
	my $message = "Not in queue";
	if (defined $idx) {
		splice(@{$self->queued}, $idx, 1);
		$self->writeQueue();
		$message = "Removed";
	}
	
	$self->json_pr({removed => defined $idx}, $message);
	
}

sub queueRoot {
	my $self = shift @_;
	my $provider = shift @_; # || $self->provider;
	
	#$self->error("Debug", $self->config);
	
	my $dl_dir = $self->drill(['paths','downloads']);
	
	if (!$dl_dir) {
		$self->error("No download path specified in config");
	}
	
	my $pr_dl_dir = $dl_dir . $self->providerName($provider) . '/';
	
	return $pr_dl_dir;
}

sub queueFile {
	my $self = shift @_;
	my $provider = shift @_;
	
	return $self->queueRoot($self->providerName($provider)) . 'queue.json';
	
}



sub inQueue {
	my $self = shift @_;
	my $file = shift @_;
	
	my $md5 = defined $file->{md5} ? $file->{md5} : $file;
	
	my $found = 0;
	my $pos = 0;
	foreach my $q_file(@{$self->queued}) {
		if ($q_file->{md5} eq $file->{md5}) {
			$found = 1;
			last;
		}
		$pos++;
	}
	
	return $found == 1 ? $pos : undef;
}

sub loadProviderQueue {
	my $self = shift @_;
	my $pr_name = shift @_;
	
	my $dl_dir = $self->drill(['paths','downloads']);
	
	if (!$dl_dir) {
		$self->error("No download path specified in config");
	}
	
	my $pr_dl_dir = $dl_dir . $pr_name . '/';
	if (! -d $pr_dl_dir) {
		$self->error("Provider download directory doesn't exist: $pr_dl_dir");
	}
	
	my $provider_file = $pr_dl_dir . 'provider.json';
	if (! -f $provider_file) {
		$self->error("Provider metadata doesn't exist: $provider_file");
	}
	
	my $provider = decode_json(read_file($provider_file));
	#print Dumper($json); exit;
	
	#$self->provider($json);
	$self->readQueue($provider);
}


1;