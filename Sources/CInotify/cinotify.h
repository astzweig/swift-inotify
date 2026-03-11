#ifndef CINOTIFY_H
#define CINOTIFY_H

#include <stdlib.h>
#include <sys/inotify.h>
#include <errno.h>

static inline int cinotify_deinit(int fd) {
	return close(fd);
}

static inline int cinotify_get_errno(void) {
	return errno;
}

static inline char* get_error_message() {
	int error_number = errno;
	errno = 0;
	char* error_message = strerror(error_number);
	if (errno > 0) return NULL;
	return error_message;
}

#endif
