package Medac::Console::Menu::Item;
use lib '../../..';

use Moose;

use strict;
use warnings;
use Data::Dumper;

use Term::ANSIColor::Markup;


has 'label' => (
	is => 'rw',
	isa => 'Str'
);

has 'key' => (
	is => 'rw',
	isa => 'Str'
);

has 'returns' => (
	is => 'rw',
	isa => 'Str',
	default => ''
);

has 'menu' => (
	is => 'rw',
	isa => 'Medac::Console::Menu',
	default => sub { return new Medac::Console::Menu(); }
);

has 'action' => (
	is => 'rw',
	default => sub { return sub {}; }
);

has 'prefix' => (
	is => 'rw',
	isa => 'Str',
	default => ''
);

has 'action' => (
	is => 'rw',
	isa => 'Any',
	default => sub {
		my $s = sub {
			#print STDERR "action!\n";
		};
		return $s;
	}
);

sub colorize {
	my $self = shift @_;
	my $text = shift @_;
	return Term::ANSIColor::Markup->colorize($text);
}

sub getEntry {
	my $self = shift @_;
	my $indent = shift @_ || $self->menu->indent;
	my $max_len = $self->menu->maxLen() ;
	my $max = (length($max_len) > 0 ? $max_len : 1) + $indent - length($self->prefix);
	my $fmt = '%' . $max . 's';
	return $self->prefix . $self->colorize('<yellow>' . sprintf($fmt, $self->key) . '</yellow><cyan>)</cyan> ') . $self->label;
}



1;