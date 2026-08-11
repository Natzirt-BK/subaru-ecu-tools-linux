/* Derived from Wine libs/winecrt0/unix_lib.c (LGPL-2.1-or-later). */
#include <stdarg.h>
#include <ntstatus.h>
#include <windef.h>
#include <winbase.h>
#include <winternl.h>
#include <stdint.h>

typedef uint64_t unixlib_handle_t;
typedef NTSTATUS (WINAPI *unix_dispatcher_t)(unixlib_handle_t, unsigned int, void *);
#ifdef OPENPORT_KERNEL_BUILD
extern NTSTATUS WINAPI NtQueryVirtualMemory(HANDLE, const void *, int,
                                            void *, SIZE_T, SIZE_T *);
extern NTSTATUS WINAPI LdrGetDllHandle(const WCHAR *, ULONG, const UNICODE_STRING *, HMODULE *);
extern void *WINAPI RtlFindExportedRoutineByName(HMODULE, const char *);
#endif
extern IMAGE_DOS_HEADER __ImageBase;
extern unix_dispatcher_t __wine_unix_call_dispatcher;

static NTSTATUS WINAPI fallback(unixlib_handle_t handle, unsigned int code, void *args)
{
    return STATUS_DLL_NOT_FOUND;
}

static NTSTATUS WINAPI init_dispatcher(unixlib_handle_t handle, unsigned int code, void *args)
{
    UNICODE_STRING name;
    HMODULE module;
    void **address;
    RtlInitUnicodeString(&name, L"ntdll.dll");
    LdrGetDllHandle(NULL, 0, &name, &module);
    address = RtlFindExportedRoutineByName(module, "__wine_unix_call_dispatcher");
    InterlockedExchangePointer((void **)&__wine_unix_call_dispatcher,
                               address ? *address : (void *)fallback);
    return __wine_unix_call_dispatcher(handle, code, args);
}

unixlib_handle_t __wine_unixlib_handle;
unix_dispatcher_t __wine_unix_call_dispatcher = init_dispatcher;

NTSTATUS WINAPI __wine_init_unix_call(void)
{
    return NtQueryVirtualMemory((HANDLE)(LONG_PTR)-1, &__ImageBase,
#ifdef OPENPORT_KERNEL_BUILD
                                1000,
#else
                                (MEMORY_INFORMATION_CLASS)1000,
#endif
                                &__wine_unixlib_handle, sizeof(__wine_unixlib_handle), NULL);
}
