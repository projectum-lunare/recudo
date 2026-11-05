#ifndef _RECUDO_WINCE_UNISTD_H
#define _RECUDO_WINCE_UNISTD_H

#include <sys/types.h>

#ifdef __cplusplus
extern "C" {
#endif

#define F_OK 0
#define X_OK 1
#define W_OK 2
#define R_OK 4

#define SEEK_SET 0
#define SEEK_CUR 1
#define SEEK_END 2

int access(const char *path, int mode);
int unlink(const char *path);
int rmdir(const char *path);
int chdir(const char *path);
char *getcwd(char *buf, size_t size);
int isatty(int fd);
unsigned int sleep(unsigned int seconds);

#ifdef __cplusplus
}
#endif

#endif /* _RECUDO_WINCE_UNISTD_H */
