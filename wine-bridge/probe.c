#include <stdint.h>
#include <stdio.h>
#include <windows.h>

typedef int32_t (*open_fn)(const void *, uint32_t *);
typedef int32_t (*close_fn)(uint32_t);
typedef int32_t (*version_fn)(uint32_t, char *, char *, char *);
typedef int32_t (*error_fn)(char *);

int main(void)
{
    HMODULE dll = LoadLibraryA("j2534.dll");
    uint32_t device = 0;
    char firmware[80] = {0}, dll_version[80] = {0}, api[80] = {0}, error[80] = {0};
    open_fn open_device;
    close_fn close_device;
    version_fn read_version;
    error_fn get_error;
    int32_t ret;

    if (!dll)
    {
        printf("LOAD_FAIL=%lu\n", GetLastError());
        return 2;
    }
    open_device = (open_fn)GetProcAddress(dll, "PassThruOpen");
    close_device = (close_fn)GetProcAddress(dll, "PassThruClose");
    read_version = (version_fn)GetProcAddress(dll, "PassThruReadVersion");
    get_error = (error_fn)GetProcAddress(dll, "PassThruGetLastError");
    if (!open_device || !close_device || !read_version || !get_error)
    {
        printf("EXPORT_FAIL\n");
        return 3;
    }
    ret = open_device(NULL, &device);
    get_error(error);
    printf("OPEN=%ld DEVICE=%lu ERROR=%s\n", (long)ret, (unsigned long)device, error);
    if (ret) return 4;
    ret = read_version(device, firmware, dll_version, api);
    printf("VERSION=%ld FW=%s DLL=%s API=%s\n", (long)ret, firmware, dll_version, api);
    ret = close_device(device);
    printf("CLOSE=%ld\n", (long)ret);
    return ret ? 5 : 0;
}
