#include <windows.h>

/**
 * Loads OpenCL source from disk using Win32 API (no CRT).
 * Returns a null-terminated buffer. Caller must call HeapFree.
 */
char* load_kernel_source_win32(const char* filename) {
    HANDLE hFile = CreateFileA(filename, GENERIC_READ, FILE_SHARE_READ, NULL, 
                               OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    if (hFile == INVALID_HANDLE_VALUE) return NULL;

    DWORD fileSize = GetFileSize(hFile, NULL);
    if (fileSize == INVALID_FILE_SIZE) {
        CloseHandle(hFile);
        return NULL;
    }

    // Allocate from process heap (no malloc)
    char* buffer = (char*)HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, (size_t)fileSize + 1);
    if (buffer) {
        DWORD bytesRead;
        if (!ReadFile(hFile, buffer, fileSize, &bytesRead, NULL)) {
            HeapFree(GetProcessHeap(), 0, buffer);
            buffer = NULL;
        } else {
            buffer[fileSize] = '\0';
        }
    }

    CloseHandle(hFile);
    return buffer;
}
