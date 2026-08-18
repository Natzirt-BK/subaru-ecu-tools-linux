#ifndef SUBARU_WINE_UNIXLIB_COMPAT_H
#define SUBARU_WINE_UNIXLIB_COMPAT_H

/*
 * Wine's unixlib ABI declarations are installed by Arch Wine but are private
 * in Debian's Wine packages.  Keep the small, stable ABI surface used by this
 * bridge local so both distributions compile the same sources.
 */
#include <winternl.h>

typedef UINT64 unixlib_handle_t;

#ifdef WINE_UNIX_LIB

typedef NTSTATUS (*unixlib_entry_t)(void *args);

#else

extern unixlib_handle_t __wine_unixlib_handle;
extern NTSTATUS (WINAPI *__wine_unix_call_dispatcher)(
    unixlib_handle_t handle, unsigned int code, void *args);
extern NTSTATUS WINAPI __wine_init_unix_call(void);

static inline NTSTATUS __wine_unix_call(
    unixlib_handle_t handle, unsigned int code, void *args)
{
    return __wine_unix_call_dispatcher(handle, code, args);
}

#define WINE_UNIX_CALL(code, args) \
    __wine_unix_call(__wine_unixlib_handle, (code), (args))

#endif

#endif
