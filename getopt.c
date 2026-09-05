#include "getopt.h"
#include <stdio.h>
#include <string.h>

char *optarg;
int optind = 1;

static int optpos;

int
getopt(int argc, char * const argv[], const char *optstring)
{
	const char *oi;
	char *arg, c;

	optarg = 0;
	if (optind >= argc)
		return -1;
	arg = argv[optind];
	if (arg[0] != '-' || arg[1] == '\0')
		return -1;
	if (arg[1] == '-' && arg[2] == '\0') {
		optind++;
		return -1;
	}
	if (optpos == 0)
		optpos = 1;
	c = arg[optpos++];
	oi = strchr(optstring, c);
	if (!oi || c == ':') {
		fprintf(stderr, "%s: unknown option -- %c\n", argv[0], c);
		if (arg[optpos] == '\0') {
			optind++;
			optpos = 0;
		}
		return '?';
	}
	if (oi[1] == ':') {
		if (arg[optpos] != '\0')
			optarg = arg + optpos;
		else if (++optind < argc)
			optarg = argv[optind];
		else {
			fprintf(stderr, "%s: option requires an argument -- %c\n",
			        argv[0], c);
			optpos = 0;
			return '?';
		}
		optind++;
		optpos = 0;
	} else if (arg[optpos] == '\0') {
		optind++;
		optpos = 0;
	}
	return c;
}
