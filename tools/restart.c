#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/reboot.h>
#include <linux/reboot.h>

int main (void) {
	reboot (LINUX_REBOOT_CMD_RESTART);
	exit (0);
}
