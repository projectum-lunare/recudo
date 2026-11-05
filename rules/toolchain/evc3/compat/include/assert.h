#ifndef _RECUDO_WINCE_ASSERT_H
#define _RECUDO_WINCE_ASSERT_H

#ifdef NDEBUG
#define assert(expr) ((void)0)
#else
#ifdef __cplusplus
extern "C" {
#endif
void _wince_assert(const char *expr, const char *file, int line);
#ifdef __cplusplus
}
#endif
#define assert(expr) ((expr) ? (void)0 : _wince_assert(#expr, __FILE__, __LINE__))
#endif

#endif /* _RECUDO_WINCE_ASSERT_H */
