#ifndef CINOTIFY_H
#define CINOTIFY_H

#include <stdlib.h>
#include <sys/inotify.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>

static inline int cinotify_deinit(int fd) {
	return close(fd);
}

static inline int cinotify_get_errno(void) {
	return errno;
}

static inline char* cinotify_error_message(int error_number) {
	return strerror(error_number);
}

#endif
