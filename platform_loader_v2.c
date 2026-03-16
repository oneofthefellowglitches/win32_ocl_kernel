#include <windows.h>

typedef struct {
    unsigned char* base;
    size_t size;
    size_t offset;
} Arena;

typedef struct {
    char* data;
    size_t size;
} PlatformFile;

/*
The "One Big Alloc" Strategy
Init Phase: Load kernels, textures, and palettes into the Arena.
Frame Phase: If you need temporary memory per frame, use a second FrameArena 
that you reset to offset = 0 every loop.
*/
Arena global_arena;

void init_global_memory(size_t total_size) {
    global_arena.base = (unsigned char*)VirtualAlloc(NULL, total_size, 
                                                     MEM_COMMIT | MEM_RESERVE, 
                                                     PAGE_READWRITE);
    global_arena.size = total_size;
    global_arena.offset = 0;
}

/*
Why this is better for CRT-free:
Speed: arena->offset += size is effectively zero-cost compared to HeapAlloc.
No Fragmentation: You don't have to worry about holes in memory.
No "Free" Logic: You don't call platform_file_free. Instead, you "reset" the arena (offset = 0) 
at the start of a frame or after your initialization phase is done.
*/
PlatformFile platform_file_load(Arena* arena, const char* path) {
    PlatformFile pf = {0, 0};
    HANDLE hFile = CreateFileA(path, GENERIC_READ, FILE_SHARE_READ, NULL, 
                               OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    
    if (hFile != INVALID_HANDLE_VALUE) {
        DWORD fileSize = GetFileSize(hFile, NULL);
        
        if (arena->offset + fileSize + 1 <= arena->size) {
            pf.data = (char*)(arena->base + arena->offset);
            DWORD bytesRead;
            if (ReadFile(hFile, pf.data, fileSize, &bytesRead, NULL)) {
                pf.data[fileSize] = '\0';
                pf.size = (size_t)fileSize;
                arena->offset += (fileSize + 1);
            }
        }
        CloseHandle(hFile);
    }
    return pf;
}
