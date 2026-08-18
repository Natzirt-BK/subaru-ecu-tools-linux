#include <stdint.h>
#include <windows.h>
#include <winternl.h>
#include "wine_unixlib_compat.h"

#include "j2534_unix_calls.h"

static int32_t unix_call(unsigned int code, void *params)
{
    return (int32_t)WINE_UNIX_CALL(code, params);
}

int32_t PassThruOpen(const void *name, uint32_t *device_id)
{
    struct open_params params = {(uint32_t)(uintptr_t)name, (uint32_t)(uintptr_t)device_id};
    return unix_call(unix_PassThruOpen, &params);
}

int32_t PassThruClose(uint32_t device_id)
{
    struct close_params params = {device_id};
    return unix_call(unix_PassThruClose, &params);
}

int32_t PassThruConnect(uint32_t device_id, uint32_t protocol_id, uint32_t flags,
                        uint32_t baudrate, uint32_t *channel_id)
{
    struct connect_params params = {device_id, protocol_id, flags, baudrate,
                                     (uint32_t)(uintptr_t)channel_id};
    return unix_call(unix_PassThruConnect, &params);
}

int32_t PassThruDisconnect(uint32_t channel_id)
{
    struct disconnect_params params = {channel_id};
    return unix_call(unix_PassThruDisconnect, &params);
}

int32_t PassThruReadMsgs(uint32_t channel_id, void *messages, uint32_t *count, uint32_t timeout)
{
    struct messages_params params = {channel_id, (uint32_t)(uintptr_t)messages,
                                     (uint32_t)(uintptr_t)count, timeout};
    return unix_call(unix_PassThruReadMsgs, &params);
}

int32_t PassThruWriteMsgs(uint32_t channel_id, const void *messages, uint32_t *count, uint32_t timeout)
{
    struct messages_params params = {channel_id, (uint32_t)(uintptr_t)messages,
                                     (uint32_t)(uintptr_t)count, timeout};
    return unix_call(unix_PassThruWriteMsgs, &params);
}

int32_t PassThruStartPeriodicMsg(uint32_t channel_id, const void *message,
                                 uint32_t *message_id, uint32_t interval)
{
    struct periodic_start_params params = {channel_id, (uint32_t)(uintptr_t)message,
                                           (uint32_t)(uintptr_t)message_id, interval};
    return unix_call(unix_PassThruStartPeriodicMsg, &params);
}

int32_t PassThruStopPeriodicMsg(uint32_t channel_id, uint32_t message_id)
{
    struct periodic_stop_params params = {channel_id, message_id};
    return unix_call(unix_PassThruStopPeriodicMsg, &params);
}

int32_t PassThruStartMsgFilter(uint32_t channel_id, uint32_t filter_type,
                               const void *mask, const void *pattern,
                               const void *flow_control, uint32_t *message_id)
{
    struct filter_start_params params = {
        channel_id, filter_type, (uint32_t)(uintptr_t)mask,
        (uint32_t)(uintptr_t)pattern, (uint32_t)(uintptr_t)flow_control,
        (uint32_t)(uintptr_t)message_id
    };
    return unix_call(unix_PassThruStartMsgFilter, &params);
}

int32_t PassThruStopMsgFilter(uint32_t channel_id, uint32_t message_id)
{
    struct filter_stop_params params = {channel_id, message_id};
    return unix_call(unix_PassThruStopMsgFilter, &params);
}

int32_t PassThruSetProgrammingVoltage(uint32_t device_id, uint32_t pin, uint32_t voltage)
{
    struct voltage_params params = {device_id, pin, voltage};
    return unix_call(unix_PassThruSetProgrammingVoltage, &params);
}

int32_t PassThruReadVersion(uint32_t device_id, char *firmware, char *dll, char *api)
{
    struct version_params params = {
        device_id, (uint32_t)(uintptr_t)firmware,
        (uint32_t)(uintptr_t)dll, (uint32_t)(uintptr_t)api
    };
    return unix_call(unix_PassThruReadVersion, &params);
}

int32_t PassThruGetLastError(char *description)
{
    struct error_params params = {(uint32_t)(uintptr_t)description};
    return unix_call(unix_PassThruGetLastError, &params);
}

int32_t PassThruIoctl(uint32_t channel_id, uint32_t ioctl_id, const void *input, void *output)
{
    struct ioctl_params params = {channel_id, ioctl_id, (uint32_t)(uintptr_t)input,
                                  (uint32_t)(uintptr_t)output};
    return unix_call(unix_PassThruIoctl, &params);
}

BOOL WINAPI DllMain(HINSTANCE instance, DWORD reason, void *reserved)
{
    if (reason == DLL_PROCESS_ATTACH)
    {
        DisableThreadLibraryCalls(instance);
        if (__wine_init_unix_call()) return FALSE;
    }
    return TRUE;
}
