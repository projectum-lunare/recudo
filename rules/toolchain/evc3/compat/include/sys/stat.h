#ifndef _RECUDO_WINCE_SYS_STAT_H
#define _RECUDO_WINCE_SYS_STAT_H

#include <sys/types.h>

#ifdef __cplusplus
extern "C" {
#endif

#define S_IFMT   0170000
#define S_IFDIR  0040000
#define S_IFCHR  0020000
#define S_IFREG  0100000

#define S_IREAD  0000400
#define S_IWRITE 0000200
#define S_IEXEC  0000100

#define S_ISDIR(m)  (((m) & S_IFMT) == S_IFDIR)
#define S_ISREG(m)  (((m) & S_IFMT) == S_IFREG)

struct stat {
    dev_t         st_dev;
    ino_t         st_ino;
    mode_t        st_mode;
    nlink_t       st_nlink;
    uid_t         st_uid;
    gid_t         st_gid;
    dev_t         st_rdev;
    off_t         st_size;
    time_t        st_atime;
    time_t        st_mtime;
    time_t        st_ctime;
};

int stat(const char *path, struct stat *buf);
int fstat(int fd, struct stat *buf);

#ifdef __cplusplus
}
#endif

#endif /* _RECUDO_WINCE_SYS_STAT_H */
