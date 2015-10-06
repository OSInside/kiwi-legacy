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

    # log into text console
    sendkey "ctrl-alt-f2";
    waitforneedle( "text-login", 10 );
    sendautotype "$username\n";
    sleep 2;
    sendautotype "$password\n";
    sleep 3;
    sendautotype "PS1=\$\n";    # set constant shell promt
    sleep 1;

    script_run("echo 010_consoletest_setup OK > /dev/$serialdev");

    # it is only a waste of time, if this does not work
    alarm 3 unless waitserial( "010_consoletest_setup OK", 10 );
}

sub test_flags() {
    return { 'important' => 1 };
}

1;
