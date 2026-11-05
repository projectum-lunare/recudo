#ifndef _RECUDO_WINCE_SIGNAL_H
#define _RECUDO_WINCE_SIGNAL_H

#ifdef __cplusplus
extern "C" {
#endif

typedef void (*__sighandler_t)(int);
typedef __sighandler_t sig_t;
typedef int sig_atomic_t;

#define SIG_DFL ((__sighandler_t)0)
#define SIG_IGN ((__sighandler_t)1)
#define SIG_ERR ((__sighandler_t)-1)

#define SIGINT   2
#define SIGILL   4
#define SIGABRT  6
#define SIGFPE   8
#define SIGSEGV 11
#define SIGTERM 15

__sighandler_t signal(int sig, __sighandler_t handler);
int raise(int sig);

#ifdef __cplusplus
}
#endif

#endif /* _RECUDO_WINCE_SIGNAL_H */
