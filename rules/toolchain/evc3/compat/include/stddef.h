#ifndef _RECUDO_WINCE_STDDEF_H
#define _RECUDO_WINCE_STDDEF_H

#ifndef _PTRDIFF_T_DEFINED
#define _PTRDIFF_T_DEFINED
typedef int ptrdiff_t;
#endif

#ifndef _SIZE_T_DEFINED
#define _SIZE_T_DEFINED
typedef unsigned int size_t;
#endif

#ifndef _WCHAR_T_DEFINED
#define _WCHAR_T_DEFINED
typedef unsigned short wchar_t;
#endif

#ifndef NULL
#ifdef __cplusplus
#define NULL 0
#else
#define NULL ((void *)0)
#endif
#endif

#ifndef offsetof
#define offsetof(s,m) ((size_t)&(((s *)0)->m))
#endif

#endif /* _RECUDO_WINCE_STDDEF_H */
