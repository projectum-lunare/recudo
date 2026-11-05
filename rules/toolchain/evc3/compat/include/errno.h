#ifndef _RECUDO_WINCE_ERRNO_H
#define _RECUDO_WINCE_ERRNO_H

#ifdef __cplusplus
extern "C" {
#endif

extern int _wince_errno;
#define errno _wince_errno

#ifndef EDOM
#define EDOM        33
#endif
#ifndef ERANGE
#define ERANGE      34
#endif
#ifndef ENOENT
#define ENOENT       2
#endif
#ifndef EIO
#define EIO          5
#endif
#ifndef EBADF
#define EBADF        9
#endif
#ifndef ENOMEM
#define ENOMEM      12
#endif
#ifndef EACCES
#define EACCES      13
#endif
#ifndef EEXIST
#define EEXIST      17
#endif
#ifndef EXDEV
#define EXDEV       18
#endif
#ifndef EINVAL
#define EINVAL      22
#endif
#ifndef EMFILE
#define EMFILE      24
#endif
#ifndef ENOSPC
#define ENOSPC      28
#endif
#ifndef EAGAIN
#define EAGAIN      11
#endif
#ifndef EBUSY
#define EBUSY       16
#endif
#ifndef ENOTDIR
#define ENOTDIR     20
#endif
#ifndef EISDIR
#define EISDIR      21
#endif

char *strerror(int errnum);
void perror(const char *s);

#ifdef __cplusplus
}
#endif

#endif /* _RECUDO_WINCE_ERRNO_H */
