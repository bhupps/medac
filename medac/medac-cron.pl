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
use Medac::Provider;

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
	errMsg("instance in progress, exiting");
	exit 0;
} else {
	#my $cfg = new Medac::Config();
	my $api = new Medac::API(context => 'local');
	my $cfg = $api->config;
	my $queue = new Medac::Queue();
	
	
	#print Dumper($cfg->settings); exit;
	my $dl_root = $cfg->drill(['paths','downloads']);
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
				my $prov_queue_path = $prov_queue_dir . '/queue.json';
				#my $prov_queue_path = $prov_queue_dir . '/queue.json';
				#my $prov_queue_path = $queue->ensureQueueExists($provider);
				logMsg("Checking provider $provider");
				
				my $pr_obj = new Medac::Provider();
				$pr_obj->readProvider($provider);
				$api->pr($pr_obj);
				
				$queue->readQueue($provider);
					
				foreach my $qfile (@{$queue->queued}) {
					my $qfile_path = $prov_queue_dir . $qfile->{path};
					my $exists = -f $qfile_path ? ' Y ' : ' N ';
					logMsg($exists . ' --- ' . $qfile_path);
					if (! -f $prov_queue_path) {
						warnMsg("No queue for provider $provider: $prov_queue_path");
					} else {
						$queue->loadProviderQueue($provider);
						#$queue->readQueue($provider);
						
						if (scalar @{$queue->queued} > 0) {
							foreach my $qfile (@{$queue->queued}) {
								my $qfile_path = $prov_queue_dir . $qfile->{path};
								my $exists = -f $qfile_path ? ' Y ' : ' N ';
								
								if (-f $qfile_path) {
									my $downloaded = (stat $qfile_path)[7];
									if ($downloaded eq $qfile->{size}) {
										logMsg("  - $qfile_path, downloaded.  Dequeuing");
										$queue->dequeue($qfile);
									} else {
										my $percent = $downloaded / $qfile->{size};
										logMsg("  - $qfile_path partial download $percent\%");
									}
								} else {
									logMsg("  - DOWNLOAD $qfile->{path}");
									
									my $cmd = <<__RSYNC;
	echo "{$rsync_tag}" > /dev/null && rsync -avz --progress --partial --append -e "ssh -p 22" guest\@medac-dev.snm.com:/home/don/Desktop/Video/ /home/don/Desktop/MedacDownloads/theraccoonbearcity
__RSYNC
								}
							}
							
							logMsg("Snoozing...");
							my $x = 0;
							while ($x < 3) {
								sleep 1;
								$x++;
								logMsg($x . ' Zzzzzzz...');
							}
							logMsg("done!");
						} else {
							logMsg("Nothing queued for provider");
						}
						
						#print Dumper($queue);
					}
				}
			}
		}
	}
	
	
	
	my $cmd = 'echo "' . $rsync_tag . '" > /dev/null && rsync -avz --progress --partial --append --files-from /home/don/code/theraccoonshare.com/public_html/medac-dev/cgi-bin/queue/theraccoonbearcity/queue.txt -e "ssh -p 22" guest@medac-dev.snm.com:/home/don/Desktop/Video/ /home/don/Desktop/MedacDownloads/theraccoonbearcity';
	#`$cmd`;
	#print "$cmd\n";
	
	exit 0;
}
