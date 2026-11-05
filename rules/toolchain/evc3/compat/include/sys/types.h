#ifndef _RECUDO_WINCE_SYS_TYPES_H
#define _RECUDO_WINCE_SYS_TYPES_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef long off_t;
typedef int dev_t;
typedef unsigned short ino_t;
typedef unsigned short mode_t;
typedef short nlink_t;
typedef int pid_t;
typedef int uid_t;
typedef int gid_t;

#ifndef _TIME_T_DEFINED
#define _TIME_T_DEFINED
typedef long time_t;
#endif

#ifdef __cplusplus
}
#endif

#endif /* _RECUDO_WINCE_SYS_TYPES_H */
