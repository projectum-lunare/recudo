#ifndef _RECUDO_WINCE_TIME_H
#define _RECUDO_WINCE_TIME_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#ifndef _TIME_T_DEFINED
#define _TIME_T_DEFINED
typedef long time_t;
#endif

#ifndef _CLOCK_T_DEFINED
#define _CLOCK_T_DEFINED
typedef long clock_t;
#endif

#ifndef CLOCKS_PER_SEC
#define CLOCKS_PER_SEC 1000
#endif

#ifndef _TM_DEFINED
#define _TM_DEFINED
struct tm {
    int tm_sec;   /* 0-59 */
    int tm_min;   /* 0-59 */
    int tm_hour;  /* 0-23 */
    int tm_mday;  /* 1-31 */
    int tm_mon;   /* 0-11 */
    int tm_year;  /* years since 1900 */
    int tm_wday;  /* 0-6 (Sunday = 0) */
    int tm_yday;  /* 0-365 */
    int tm_isdst; /* daylight saving time flag */
};
#endif

time_t time(time_t *timer);
clock_t clock(void);
struct tm *localtime(const time_t *timer);
struct tm *gmtime(const time_t *timer);
time_t mktime(struct tm *timeptr);
double difftime(time_t time1, time_t time0);
size_t strftime(char *s, size_t max, const char *format, const struct tm *tm);
char *asctime(const struct tm *timeptr);
char *ctime(const time_t *timer);

#ifdef __cplusplus
}
#endif

#endif /* _RECUDO_WINCE_TIME_H */
