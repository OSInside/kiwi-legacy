#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>

int main(int argc, char **argv) {
	int i, percent = -1;
	unsigned cnt = 0, blk_size = 1024*1024, blk_cnt = 0, size = 0;
	ssize_t r, w, p;
	char buf[1024*1024];
	argv++; argc--;
	if (argc > 1 && !strcmp(*argv, "-s")) {
		i = atoi(argv[1]);
		if (i) {
			size = i;
		}
		argv += 2;
		argc -= 2;
	}
	if (!size) {
		fprintf(stderr, "no size in MB set\n");
		return 1;
	}
	fprintf(stderr, "      ");
	while((r = read(0, buf, sizeof buf)) > 0) {
		p = 0;
		while((w = write(1, buf + p, r - p)) >= 0) {
			p += w;
			if(p >= r) {
				break;
			}
		}
		if(p < r) {
			fprintf(stderr, "write error\n");
			return 1;
		}
		cnt += r;
		if(cnt >= blk_size) {
			blk_cnt += cnt / blk_size;
			cnt %= blk_size;
			i = percent;
			percent = (blk_cnt * 100) / size;
			if(percent != i) {
				fprintf(stderr, "\x08\x08\x08\x08\x08\x08(%3d%%)", percent);
			}
		}
	}
	fflush(stdout);
	return 0;
}
