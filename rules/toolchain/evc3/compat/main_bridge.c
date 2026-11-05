/*
 * Projectum Lunare Recudo
 * Windows CE 3.0 CLI Entry Point Bridge (WinMain -> main)
 */

#include <stddef.h>
#include <ctype.h>

typedef unsigned short WCHAR;
typedef int BOOL;
typedef unsigned long DWORD;

#define CP_ACP 0

#ifdef __cplusplus
extern "C" {
#endif

__declspec(dllimport) int __stdcall WideCharToMultiByte(unsigned int CodePage, DWORD dwFlags, const WCHAR *lpWideCharStr, int cchWideChar, char *lpMultiByteStr, int cbMultiByte, const char *lpDefaultChar, BOOL *lpUsedDefaultChar);

extern int main(int argc, char **argv);

int __stdcall WinMain(void *hInstance, void *hPrevInstance, unsigned short *lpCmdLine, int nCmdShow) {
    int argc = 0;
    static char *argv[64];
    static char arg_buffer[1024];
    char *p;
    (void)hInstance; (void)hPrevInstance; (void)nCmdShow;

    argv[argc++] = "app.exe";
    if (lpCmdLine && *lpCmdLine) {
        WideCharToMultiByte(CP_ACP, 0, (const WCHAR *)lpCmdLine, -1, arg_buffer, sizeof(arg_buffer), NULL, NULL);
        p = arg_buffer;
        while (*p && argc < 63) {
            while (*p && isspace((unsigned char)*p)) p++;
            if (!*p) break;
            argv[argc++] = p;
            while (*p && !isspace((unsigned char)*p)) p++;
            if (*p) { *p = '\0'; p++; }
        }
    }
    argv[argc] = 0;
    return main(argc, argv);
}

#ifdef __cplusplus
}
#endif
