/* Double-click launcher for uxplay on Windows: starts build-fit\uxplay.exe with the MSYS2 libraries.
 * Closing this console window (or the video window) stops uxplay.
 *
 * Build with: gcc -O2 -static -o UxPlay.exe launcher/uxplay-launcher.c
 */

#include <windows.h>
#include <stdio.h>
#include <string.h>

#define MSYS2_BIN "C:\\msys64\\ucrt64\\bin"
#define UXPLAY_ARGS "uxplay -n Notebook -vs d3d12videosink -s 1920x1080@60 -fps 60"

static BOOL WINAPI ignore_ctrl(DWORD signal) {
    /* uxplay handles ctrl-c itself: keep waiting until it has finished */
    return signal == CTRL_C_EVENT;
}

static int fail(const char *message) {
    printf("\n%s\nPress Enter to close.\n", message);
    getchar();
    return 1;
}

int main(void) {
    char dir[MAX_PATH];
    char exe[MAX_PATH + 32];
    char cwd[MAX_PATH + 32];
    char path[32768];
    char args[] = UXPLAY_ARGS;

    SetConsoleTitleA("UxPlay");
    if (!GetModuleFileNameA(NULL, dir, sizeof(dir))) {
        return fail("Could not find the UxPlay folder.");
    }
    char *slash = strrchr(dir, '\\');
    if (slash) {
        *slash = '\0';
    }
    snprintf(cwd, sizeof(cwd), "%s\\build-fit", dir);
    snprintf(exe, sizeof(exe), "%s\\uxplay.exe", cwd);
    if (GetFileAttributesA(exe) == INVALID_FILE_ATTRIBUTES) {
        return fail("build-fit\\uxplay.exe was not found.");
    }
    if (GetFileAttributesA(MSYS2_BIN) == INVALID_FILE_ATTRIBUTES) {
        return fail("MSYS2 was not found at C:\\msys64.");
    }

    char old_path[32000] = "";
    GetEnvironmentVariableA("PATH", old_path, sizeof(old_path));
    snprintf(path, sizeof(path), "%s;%s", MSYS2_BIN, old_path);
    SetEnvironmentVariableA("PATH", path);

    printf("UxPlay is starting. Keep this window open.\n\n");
    printf("On iPhone: Control Center > Screen Mirroring > Notebook\n");
    printf("To stop: close this window.\n\n");

    STARTUPINFOA startup = {0};
    PROCESS_INFORMATION process = {0};
    startup.cb = sizeof(startup);
    SetConsoleCtrlHandler(ignore_ctrl, TRUE);
    if (!CreateProcessA(exe, args, NULL, NULL, FALSE, 0, NULL, cwd, &startup, &process)) {
        return fail("Could not start uxplay.exe.");
    }
    WaitForSingleObject(process.hProcess, INFINITE);
    CloseHandle(process.hProcess);
    CloseHandle(process.hThread);
    return 0;
}
