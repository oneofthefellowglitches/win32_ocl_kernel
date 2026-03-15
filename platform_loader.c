#include <windows.h>

typedef struct {
    char* data;
    size_t size;
} PlatformFile;

// Global "Free" to handle the specific allocator used
void platform_file_free(PlatformFile* file);
PlatformFile platform_file_load(const char* path);

PlatformFile platform_file_load(const char* path) {
    PlatformFile pf = {0, 0};
    
    HANDLE hFile = CreateFileA(path, GENERIC_READ, FILE_SHARE_READ, NULL, 
                               OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    if (hFile == INVALID_HANDLE_VALUE) return pf;

    DWORD size = GetFileSize(hFile, NULL);
    if (size != INVALID_FILE_SIZE) {
        // Using Process Heap instead of CRT malloc
        pf.data = (char*)HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, (size_t)size + 1);
        if (pf.data) {
            DWORD read;
            if (ReadFile(hFile, pf.data, size, &read, NULL)) {
                pf.size = (size_t)size;
                pf.data[size] = '\0'; // Null terminate for OpenCL
            } else {
                HeapFree(GetProcessHeap(), 0, pf.data);
                pf.data = NULL;
            }
        }
    }
    
    CloseHandle(hFile);
    return pf;
}

void platform_file_free(PlatformFile* file) {
    if (file && file->data) {
        HeapFree(GetProcessHeap(), 0, file->data);
        file->data = NULL;
        file->size = 0;
    }
}

// Somewhere in the main
PlatformFile kernel_file = platform_file_load("julia_fixed.cl");

if (kernel_file.data) {
    cl_int err;
    const char* sources[] = { kernel_file.data };
    const size_t lengths[] = { kernel_file.size };
    
    cl_program program = clCreateProgramWithSource(context, 1, sources, lengths, &err);
    
    // Clean up immediately after creating the program object
    platform_file_free(&kernel_file);
}
