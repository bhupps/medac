#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;

BEGIN {
	my $script_path = __FILE__;
	$script_path =~ s/\/[^\/]+$//gi;
	unshift @INC, $script_path;
}

use Medac::Config;
use Medac::API;
use Medac::Queue;

my $rsync_tag = 'MEDAC_RSYNC_ACTIVE';

my $ps = `ps aux`;

sub logMsg {
	my $msg = shift @_ || 'no message';
	my $status = shift @_ || 'stat';
	
	print "[$status] $msg\n";
}

sub errMsg {
	my $msg = shift @_;
	
	logMsg($msg, 'error');
	exit(0);
}

sub warnMsg {
	my $msg = shift @_;
	
	logMsg($msg, 'warn');
}

if ($ps =~ m/$rsync_tag/g) {
	print "instance in progress, exiting.\n";
	exit 0;
} else {
	my $cfg = new Medac::Config();
	my $api = new Medac::API();
	my $queue = new Medac::Queue();
	
	#print Dumper($cfg->settings); exit;
	my $dl_root = $api->drill($cfg->settings, ['paths','downloads']);
	if (! -d $dl_root) {
		errMsg("DL root missing: $dl_root");
	}
	
	opendir (DFH, $dl_root) or errMsg("Can't read from DL root: $!");
	my @FILES = readdir DFH;
	closedir DFH;
	foreach my $d (@FILES) {
		if ($d !~ m/[^-_A-Za-z0-9]/gi) {
			if ($d !~ m/^\.{1,2}/gi) {
				my $provider = $d;
				my $prov_queue_dir = $dl_root . $provider;
				#my $prov_queue_path = $prov_queue_dir . '/queue.json';
				my $prov_queue_path = $queue->ensureQueueExists($provider);
				logMsg("Checking provider $provider");
				
				$queue->readQueue($provider);
					
				foreach my $qfile (@{$queue->queued}) {
					my $qfile_path = $prov_queue_dir . $qfile->{path};
					my $exists = -f $qfile_path ? ' Y ' : ' N ';
					logMsg($exists . ' --- ' . $qfile_path);
				}

			}
		}
	}
	
	
	
	my $cmd = 'echo "' . $rsync_tag . '" > /dev/null && rsync -avz --progress --partial --append --files-from /home/don/code/theraccoonshare.com/public_html/medac-dev/cgi-bin/queue/theraccoonbearcity/queue.txt -e "ssh -p 22" guest@medac-dev.snm.com:/home/don/Desktop/Video/ /home/don/Desktop/MedacDownloads/theraccoonbearcity';
	#`$cmd`;
	print "$cmd\n";
	print "\n\nrsync completed.\n";
	exit 0;
}
