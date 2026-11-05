/*
 * Projectum Lunare Recudo
 * Windows CE 3.0 / eVC 3.0 ANSI C89 Compatibility Polyfill CRT
 */

#include "wince_c89.h"
#include <time.h>
#include <errno.h>
#include <locale.h>
#include <signal.h>
#include <assert.h>
#include <ctype.h>
#include <sys/stat.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Windows CE SDK Definitions */
typedef unsigned long DWORD;
typedef int BOOL;
typedef unsigned short WORD;
typedef void *HANDLE;
typedef unsigned short WCHAR;

typedef struct _SYSTEMTIME {
    WORD wYear;
    WORD wMonth;
    WORD wDayOfWeek;
    WORD wDay;
    WORD wHour;
    WORD wMinute;
    WORD wSecond;
    WORD wMilliseconds;
} SYSTEMTIME;

typedef struct _TIME_ZONE_INFORMATION {
    long Bias;
    WCHAR StandardName[32];
    SYSTEMTIME StandardDate;
    long StandardBias;
    WCHAR DaylightName[32];
    SYSTEMTIME DaylightDate;
    long DaylightBias;
} TIME_ZONE_INFORMATION;

typedef struct _FILETIME {
    DWORD dwLowDateTime;
    DWORD dwHighDateTime;
} FILETIME;

typedef struct _WIN32_FIND_DATAW {
    DWORD dwFileAttributes;
    FILETIME ftCreationTime;
    FILETIME ftLastAccessTime;
    FILETIME ftLastWriteTime;
    DWORD nFileSizeHigh;
    DWORD nFileSizeLow;
    DWORD dwOID;
    WCHAR cFileName[260];
} WIN32_FIND_DATAW;

#define FILE_ATTRIBUTE_READONLY  0x00000001
#define FILE_ATTRIBUTE_DIRECTORY 0x00000010
#define CP_ACP 0

#ifdef __cplusplus
extern "C" {
#endif

__declspec(dllimport) void __stdcall GetSystemTime(SYSTEMTIME *lpSystemTime);
__declspec(dllimport) DWORD __stdcall GetTickCount(void);
__declspec(dllimport) DWORD __stdcall GetTimeZoneInformation(TIME_ZONE_INFORMATION *lpTimeZoneInformation);
__declspec(dllimport) BOOL __stdcall DeleteFileW(const WCHAR *lpFileName);
__declspec(dllimport) BOOL __stdcall MoveFileW(const WCHAR *lpExistingFileName, const WCHAR *lpNewFileName);
__declspec(dllimport) DWORD __stdcall GetTempPathW(DWORD nBufferLength, WCHAR *lpBuffer);
__declspec(dllimport) DWORD __stdcall GetFileAttributesW(const WCHAR *lpFileName);
__declspec(dllimport) HANDLE __stdcall FindFirstFileW(const WCHAR *lpFileName, WIN32_FIND_DATAW *lpFindFileData);
__declspec(dllimport) BOOL __stdcall FindClose(HANDLE hFindFile);
__declspec(dllimport) BOOL __stdcall CreateDirectoryW(const WCHAR *lpPathName, void *lpSecurityAttributes);
__declspec(dllimport) BOOL __stdcall RemoveDirectoryW(const WCHAR *lpPathName);
__declspec(dllimport) DWORD __stdcall GetModuleFileNameW(HANDLE hModule, WCHAR *lpFilename, DWORD nSize);
__declspec(dllimport) int __stdcall MultiByteToWideChar(unsigned int CodePage, DWORD dwFlags, const char *lpMultiByteStr, int cbMultiByte, WCHAR *lpWideCharStr, int cchWideChar);
__declspec(dllimport) int __stdcall WideCharToMultiByte(unsigned int CodePage, DWORD dwFlags, const WCHAR *lpWideCharStr, int cchWideChar, char *lpMultiByteStr, int cbMultiByte, const char *lpDefaultChar, BOOL *lpUsedDefaultChar);
__declspec(dllimport) BOOL __stdcall TerminateProcess(HANDLE hProcess, unsigned int uExitCode);
__declspec(dllimport) void __stdcall Sleep(DWORD dwMilliseconds);

#ifdef __cplusplus
}
#endif

/* --------------------------------------------------------------------------
 * Errno & Assert
 * -------------------------------------------------------------------------- */
int _wince_errno = 0;

char *strerror(int errnum) {
    switch (errnum) {
        case 0:       return "No error";
        case ENOENT:  return "No such file or directory";
        case EACCES:  return "Permission denied";
        case ENOMEM:  return "Not enough memory";
        case EINVAL:  return "Invalid argument";
        case ERANGE:  return "Result too large";
        case EDOM:    return "Domain error";
        case EEXIST:  return "File exists";
        case EBADF:   return "Bad file descriptor";
        default:      return "Unknown error";
    }
}

void perror(const char *s) {
    if (s && *s) {
        fprintf(stderr, "%s: %s\n", s, strerror(_wince_errno));
    } else {
        fprintf(stderr, "%s\n", strerror(_wince_errno));
    }
}

void _wince_assert(const char *expr, const char *file, int line) {
    fprintf(stderr, "Assertion failed: %s, file %s, line %d\n", expr, file, line);
    abort();
}

/* --------------------------------------------------------------------------
 * Time & Date
 * -------------------------------------------------------------------------- */
static int _is_leap(int year) {
    return (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0));
}

static const int _days_before_month[12] = {
    0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334
};

time_t mktime(struct tm *tm) {
    int y, m, d;
    long days;
    if (!tm) return (time_t)-1;
    y = tm->tm_year + 1900;
    m = tm->tm_mon;
    d = tm->tm_mday - 1;
    if (m > 11) { y += m / 12; m %= 12; }
    else if (m < 0) { int adj = (-m + 11) / 12; y -= adj; m += adj * 12; }
    days = (long)(y - 1970) * 365 + (y - 1969) / 4 - (y - 1901) / 100 + (y - 1601) / 400;
    days += _days_before_month[m];
    if (m >= 2 && _is_leap(y)) days++;
    days += d;
    return (time_t)(days * 86400L + tm->tm_hour * 3600L + tm->tm_min * 60L + tm->tm_sec);
}

time_t time(time_t *timer) {
    SYSTEMTIME st;
    struct tm tm_buf;
    time_t t;
    GetSystemTime(&st);
    tm_buf.tm_year = st.wYear - 1900;
    tm_buf.tm_mon  = st.wMonth - 1;
    tm_buf.tm_mday = st.wDay;
    tm_buf.tm_hour = st.wHour;
    tm_buf.tm_min  = st.wMinute;
    tm_buf.tm_sec  = st.wSecond;
    tm_buf.tm_isdst = 0;
    t = mktime(&tm_buf);
    if (timer) *timer = t;
    return t;
}

clock_t clock(void) {
    return (clock_t)GetTickCount();
}

double difftime(time_t time1, time_t time0) {
    return (double)(time1 - time0);
}

struct tm *gmtime(const time_t *timer) {
    static struct tm res;
    long t, days, secs;
    int y, m;
    if (!timer) return NULL;
    t = (long)*timer;
    days = t / 86400L;
    secs = t % 86400L;
    if (secs < 0) { secs += 86400L; days--; }
    res.tm_hour = secs / 3600;
    res.tm_min  = (secs % 3600) / 60;
    res.tm_sec  = secs % 60;
    res.tm_wday = (int)((days + 4) % 7);
    if (res.tm_wday < 0) res.tm_wday += 7;
    y = 1970;
    while (1) {
        int yd = _is_leap(y) ? 366 : 365;
        if (days < yd) break;
        days -= yd;
        y++;
    }
    while (days < 0) {
        y--;
        days += _is_leap(y) ? 366 : 365;
    }
    res.tm_year = y - 1900;
    res.tm_yday = (int)days;
    for (m = 11; m >= 0; m--) {
        int d = _days_before_month[m] + (m >= 2 && _is_leap(y) ? 1 : 0);
        if (days >= d) {
            res.tm_mon = m;
            res.tm_mday = (int)(days - d + 1);
            break;
        }
    }
    res.tm_isdst = 0;
    return &res;
}

struct tm *localtime(const time_t *timer) {
    TIME_ZONE_INFORMATION tzi;
    DWORD res;
    time_t local_t;
    if (!timer) return NULL;
    local_t = *timer;
    res = GetTimeZoneInformation(&tzi);
    if (res != 0xFFFFFFFF) {
        long bias = tzi.Bias;
        if (res == 2) bias += tzi.DaylightBias;
        else if (res == 1) bias += tzi.StandardBias;
        local_t -= (bias * 60);
    }
    return gmtime(&local_t);
}

size_t strftime(char *s, size_t max, const char *format, const struct tm *tm) {
    int written = 0;
    if (!s || max == 0 || !format || !tm) return 0;
    written = sprintf(s, "%04d-%02d-%02d %02d:%02d:%02d",
        tm->tm_year + 1900, tm->tm_mon + 1, tm->tm_mday,
        tm->tm_hour, tm->tm_min, tm->tm_sec);
    if (written < 0 || (size_t)written >= max) return 0;
    return (size_t)written;
}

char *asctime(const struct tm *timeptr) {
    static char buf[32];
    if (!timeptr) return NULL;
    strftime(buf, sizeof(buf), "%Y-%m-%d %H:%M:%S\n", timeptr);
    return buf;
}

char *ctime(const time_t *timer) {
    return asctime(localtime(timer));
}

/* --------------------------------------------------------------------------
 * Path Conversion Helper
 * -------------------------------------------------------------------------- */
static void _to_wide_path(const char *src, WCHAR *dst, int max_len) {
    MultiByteToWideChar(CP_ACP, 0, src, -1, dst, max_len);
}

/* --------------------------------------------------------------------------
 * Filesystem & Stdio Polyfills
 * -------------------------------------------------------------------------- */
int remove(const char *pathname) {
    WCHAR wpath[260];
    if (!pathname) { _wince_errno = EINVAL; return -1; }
    _to_wide_path(pathname, wpath, 260);
    if (DeleteFileW(wpath)) return 0;
    if (RemoveDirectoryW(wpath)) return 0;
    _wince_errno = ENOENT;
    return -1;
}

int rename(const char *oldpath, const char *newpath) {
    WCHAR wold[260], wnew[260];
    if (!oldpath || !newpath) { _wince_errno = EINVAL; return -1; }
    _to_wide_path(oldpath, wold, 260);
    _to_wide_path(newpath, wnew, 260);
    if (MoveFileW(wold, wnew)) return 0;
    _wince_errno = EACCES;
    return -1;
}

char *tmpnam(char *s) {
    static char buf[260];
    static unsigned int counter = 0;
    WCHAR wtemp[260];
    char *out = s ? s : buf;
    GetTempPathW(260, wtemp);
    WideCharToMultiByte(CP_ACP, 0, wtemp, -1, out, 260, NULL, NULL);
    sprintf(out + strlen(out), "t%04x%04x.tmp", (unsigned int)GetTickCount() & 0xFFFF, ++counter);
    return out;
}

void *tmpfile(void) {
    char name[260];
    if (tmpnam(name)) {
        return (void *)fopen(name, "w+b");
    }
    return NULL;
}

FILE *freopen(const char *path, const char *mode, FILE *stream) {
    if (stream) fclose(stream);
    return fopen(path, mode);
}

int setvbuf(FILE *stream, char *buf, int mode, size_t size) {
    (void)stream; (void)buf; (void)mode; (void)size;
    return 0;
}

int stat(const char *path, struct stat *buf) {
    WCHAR wpath[260];
    WIN32_FIND_DATAW fd;
    HANDLE hFind;
    if (!path || !buf) { _wince_errno = EINVAL; return -1; }
    _to_wide_path(path, wpath, 260);
    hFind = FindFirstFileW(wpath, &fd);
    if (hFind == (HANDLE)-1 || hFind == NULL) {
        DWORD attr = GetFileAttributesW(wpath);
        if (attr == 0xFFFFFFFF) {
            _wince_errno = ENOENT;
            return -1;
        }
        memset(buf, 0, sizeof(struct stat));
        buf->st_mode = (attr & FILE_ATTRIBUTE_DIRECTORY) ? (S_IFDIR | 0755) : (S_IFREG | 0644);
        return 0;
    }
    FindClose(hFind);
    memset(buf, 0, sizeof(struct stat));
    buf->st_mode = (fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) ? (S_IFDIR | 0755) : (S_IFREG | 0644);
    buf->st_size = (off_t)fd.nFileSizeLow;
    buf->st_mtime = (time_t)fd.ftLastWriteTime.dwLowDateTime;
    return 0;
}

int fstat(int fd, struct stat *buf) {
    if (!buf) { _wince_errno = EINVAL; return -1; }
    memset(buf, 0, sizeof(struct stat));
    buf->st_mode = S_IFCHR;
    return 0;
}

int access(const char *path, int mode) {
    WCHAR wpath[260];
    DWORD attr;
    if (!path) { _wince_errno = EINVAL; return -1; }
    _to_wide_path(path, wpath, 260);
    attr = GetFileAttributesW(wpath);
    if (attr == 0xFFFFFFFF) { _wince_errno = ENOENT; return -1; }
    if ((mode & W_OK) && (attr & FILE_ATTRIBUTE_READONLY)) {
        _wince_errno = EACCES;
        return -1;
    }
    return 0;
}

int unlink(const char *path) {
    return remove(path);
}

int mkdir(const char *path) {
    WCHAR wpath[260];
    if (!path) { _wince_errno = EINVAL; return -1; }
    _to_wide_path(path, wpath, 260);
    if (CreateDirectoryW(wpath, NULL)) return 0;
    _wince_errno = EACCES;
    return -1;
}

int rmdir(const char *path) {
    WCHAR wpath[260];
    if (!path) { _wince_errno = EINVAL; return -1; }
    _to_wide_path(path, wpath, 260);
    if (RemoveDirectoryW(wpath)) return 0;
    _wince_errno = EACCES;
    return -1;
}

static char _wince_cwd[260] = "\\";

char *getcwd(char *buf, size_t size) {
    if (!buf || size == 0) return NULL;
    strncpy(buf, _wince_cwd, size);
    buf[size - 1] = '\0';
    return buf;
}

int chdir(const char *path) {
    if (!path) { _wince_errno = EINVAL; return -1; }
    strncpy(_wince_cwd, path, sizeof(_wince_cwd));
    _wince_cwd[sizeof(_wince_cwd) - 1] = '\0';
    return 0;
}

int isatty(int fd) {
    return (fd >= 0 && fd <= 2) ? 1 : 0;
}

unsigned int sleep(unsigned int seconds) {
    Sleep(seconds * 1000);
    return 0;
}

/* --------------------------------------------------------------------------
 * Ctype implementations (lookup table / ASCII)
 * -------------------------------------------------------------------------- */
int isspace(int c)  { return (c == ' ' || (c >= '\t' && c <= '\r')); }
int isdigit(int c)  { return (c >= '0' && c <= '9'); }
int isalpha(int c)  { return ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')); }
int isalnum(int c)  { return isalpha(c) || isdigit(c); }
int islower(int c)  { return (c >= 'a' && c <= 'z'); }
int isupper(int c)  { return (c >= 'A' && c <= 'Z'); }
int isxdigit(int c) { return isdigit(c) || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F'); }
int iscntrl(int c)  { return ((c >= 0 && c <= 31) || c == 127); }
int isgraph(int c)  { return (c >= 33 && c <= 126); }
int isprint(int c)  { return (c >= 32 && c <= 126); }
int ispunct(int c)  { return isgraph(c) && !isalnum(c); }
int tolower(int c)  { return isupper(c) ? (c + ('a' - 'A')) : c; }
int toupper(int c)  { return islower(c) ? (c - ('a' - 'A')) : c; }

/* --------------------------------------------------------------------------
 * String Functions
 * -------------------------------------------------------------------------- */
double strtod(const char *str, char **endptr) {
    double result = 0.0, factor = 1.0;
    int sign = 1, exp_sign = 1, exp = 0;
    const char *p = str;
    if (!p) return 0.0;
    while (isspace((unsigned char)*p)) p++;
    if (*p == '-') { sign = -1; p++; }
    else if (*p == '+') { p++; }
    while (isdigit((unsigned char)*p)) {
        result = result * 10.0 + (*p - '0');
        p++;
    }
    if (*p == '.') {
        p++;
        while (isdigit((unsigned char)*p)) {
            factor *= 0.1;
            result += (*p - '0') * factor;
            p++;
        }
    }
    if (*p == 'e' || *p == 'E') {
        p++;
        if (*p == '-') { exp_sign = -1; p++; }
        else if (*p == '+') { p++; }
        while (isdigit((unsigned char)*p)) {
            exp = exp * 10 + (*p - '0');
            p++;
        }
        while (exp-- > 0) {
            result = (exp_sign > 0) ? (result * 10.0) : (result * 0.1);
        }
    }
    if (endptr) *endptr = (char *)p;
    return result * sign;
}

size_t strspn(const char *s, const char *accept) {
    size_t count = 0;
    while (*s && strchr(accept, *s)) { s++; count++; }
    return count;
}

size_t strcspn(const char *s, const char *reject) {
    size_t count = 0;
    while (*s && !strchr(reject, *s)) { s++; count++; }
    return count;
}

char *strpbrk(const char *s, const char *accept) {
    while (*s) {
        if (strchr(accept, *s)) return (char *)s;
        s++;
    }
    return NULL;
}

int strcoll(const char *s1, const char *s2) {
    return strcmp(s1, s2);
}

size_t strxfrm(char *dest, const char *src, size_t n) {
    size_t len = strlen(src);
    if (n > 0) {
        strncpy(dest, src, n);
        dest[n - 1] = '\0';
    }
    return len;
}

int snprintf(char *str, size_t size, const char *format, ...) {
    int ret;
    va_list ap;
    va_start(ap, format);
    ret = vsnprintf(str, size, format, ap);
    va_end(ap);
    return ret;
}

int vsnprintf(char *str, size_t size, const char *format, va_list ap) {
    int ret = vsprintf(str, format, ap);
    if (size > 0 && (size_t)ret >= size) {
        str[size - 1] = '\0';
    }
    return ret;
}

/* --------------------------------------------------------------------------
 * Process, Signals, Locale
 * -------------------------------------------------------------------------- */
char *getenv(const char *name) {
    (void)name;
    return NULL;
}

int system(const char *command) {
    (void)command;
    return -1;
}

void abort(void) {
    TerminateProcess((HANDLE)-1, 3);
}

__sighandler_t signal(int sig, __sighandler_t handler) {
    (void)sig; (void)handler;
    return SIG_DFL;
}

int raise(int sig) {
    (void)sig;
    return 0;
}

char *setlocale(int category, const char *locale) {
    (void)category; (void)locale;
    return "C";
}

struct lconv *localeconv(void) {
    static struct lconv c_locale = {
        ".", "", "", "", "", "", "", "", "", "",
        127, 127, 127, 127, 127, 127, 127, 127
    };
    return &c_locale;
}
