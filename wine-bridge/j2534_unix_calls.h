#ifndef J2534_UNIX_CALLS_H
#define J2534_UNIX_CALLS_H

#include <stdint.h>

enum j2534_unix_call
{
    unix_PassThruOpen,
    unix_PassThruClose,
    unix_PassThruConnect,
    unix_PassThruDisconnect,
    unix_PassThruReadMsgs,
    unix_PassThruWriteMsgs,
    unix_PassThruStartPeriodicMsg,
    unix_PassThruStopPeriodicMsg,
    unix_PassThruStartMsgFilter,
    unix_PassThruStopMsgFilter,
    unix_PassThruSetProgrammingVoltage,
    unix_PassThruReadVersion,
    unix_PassThruGetLastError,
    unix_PassThruIoctl,
    unix_funcs_count
};

struct open_params { uint32_t name; uint32_t device_id; };
struct close_params { uint32_t device_id; };
struct connect_params
{
    uint32_t device_id, protocol_id, flags, baudrate, channel_id;
};
struct disconnect_params { uint32_t channel_id; };
struct messages_params { uint32_t channel_id, messages, count, timeout; };
struct periodic_start_params { uint32_t channel_id, message, message_id, interval; };
struct periodic_stop_params { uint32_t channel_id, message_id; };
struct filter_start_params
{
    uint32_t channel_id, filter_type, mask, pattern, flow_control, message_id;
};
struct filter_stop_params { uint32_t channel_id, message_id; };
struct voltage_params { uint32_t device_id, pin, voltage; };
struct version_params
{
    uint32_t device_id;
    uint32_t firmware_version;
    uint32_t dll_version;
    uint32_t api_version;
};
struct error_params { uint32_t description; };
struct ioctl_params { uint32_t channel_id, ioctl_id, input, output; };

#endif
