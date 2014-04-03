use base "basetest";
use strict;
use bmwqemu;

sub run {
	my $self = shift;

	# boot
	sleep 6; # skip animation
	sendkey "ret";
	sleep 5;
	sendkey "esc";
	sleep 20;
	waitidle(100);

	# login
	sendkey "ctrl-alt-f2"; # change to tty2 for real black background
	sleep 2;
	sendautotype "$username\n";
	sleep 2;
	sendautotype "$password\n";
	waitidle (10);
	sendautotype "PS1=\$\n"; # set constant shell promt
	sleep 2;
	sendkey "ctrl-l";
	sleep 5;
	$self->take_screenshot;
	sleep 5;

	# zypper repo
	sendautotype "zypper sl\n";
	sleep 2;
	$self->take_screenshot;
	sleep 5;
	
	# shutdown
	sendautotype "halt -p\n";
}

1;
