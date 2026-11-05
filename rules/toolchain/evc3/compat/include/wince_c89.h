#ifndef _RECUDO_WINCE_C89_H
#define _RECUDO_WINCE_C89_H

#ifndef _CRTIMP
#define _CRTIMP
#endif

#include <stddef.h>
#ifndef _PTRDIFF_T_DEFINED
#define _PTRDIFF_T_DEFINED
typedef int ptrdiff_t;
#endif
#include <stdarg.h>
#include <stdio.h>

#ifndef BUFSIZ
#define BUFSIZ 512
#endif

#ifndef L_tmpnam
#define L_tmpnam 16
#endif

#ifndef FILENAME_MAX
#define FILENAME_MAX 260
#endif

#ifndef FOPEN_MAX
#define FOPEN_MAX 20
#endif

#ifndef _IOFBF
#define _IOFBF 0x0000
#endif

#ifndef _IOLBF
#define _IOLBF 0x0040
#endif

#ifndef _IONBF
#define _IONBF 0x0004
#endif

#ifdef __cplusplus
extern "C" {
#endif

/* Missing standard CRT functions in coredll.lib */
int remove(const char *pathname);
int rename(const char *oldpath, const char *newpath);
void *tmpfile(void);
char *tmpnam(char *s);
FILE *freopen(const char *path, const char *mode, FILE *stream);
int setvbuf(FILE *stream, char *buf, int mode, size_t size);

char *getenv(const char *name);
int system(const char *command);
void abort(void);

double strtod(const char *str, char **endptr);
size_t strspn(const char *s, const char *accept);
size_t strcspn(const char *s, const char *reject);
char *strpbrk(const char *s, const char *accept);
int strcoll(const char *s1, const char *s2);
size_t strxfrm(char *dest, const char *src, size_t n);

int snprintf(char *str, size_t size, const char *format, ...);
int vsnprintf(char *str, size_t size, const char *format, va_list ap);

#ifdef __cplusplus
}
#endif

#endif /* _RECUDO_WINCE_C89_H */
