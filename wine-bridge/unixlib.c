#define WINE_UNIX_LIB

#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "wine_unixlib_compat.h"

#include "j2534_unix_calls.h"

#define PM_DATA_LEN 4128
#define ERR_NULL_PARAMETER 4
#define ERR_EXCEEDED_LIMIT 12
#define IOCTL_GET_CONFIG 1
#define IOCTL_SET_CONFIG 2
#define IOCTL_READ_VBATT 3
#define IOCTL_FAST_INIT 5

typedef struct
{
    unsigned long ProtocolID, RxStatus, TxFlags, Timestamp, DataSize, ExtraDataIndex;
    unsigned char Data[PM_DATA_LEN];
} native_msg;

typedef struct
{
    uint32_t ProtocolID, RxStatus, TxFlags, Timestamp, DataSize, ExtraDataIndex;
    unsigned char Data[PM_DATA_LEN];
} win32_msg;

typedef struct { unsigned long Parameter, Value; } native_config;
typedef struct { unsigned long NumOfParams; native_config *ConfigPtr; } native_config_list;
typedef struct { uint32_t Parameter, Value; } win32_config;
typedef struct { uint32_t NumOfParams, ConfigPtr; } win32_config_list;

int32_t PassThruOpen(const void *, unsigned long *);
int32_t PassThruClose(unsigned long);
int32_t PassThruConnect(unsigned long, unsigned long, unsigned long, unsigned long, unsigned long *);
int32_t PassThruDisconnect(unsigned long);
int32_t PassThruReadMsgs(unsigned long, native_msg *, unsigned long *, unsigned long);
int32_t PassThruWriteMsgs(unsigned long, const native_msg *, unsigned long *, unsigned long);
int32_t PassThruStartPeriodicMsg(unsigned long, const native_msg *, const unsigned long *, unsigned long);
int32_t PassThruStopPeriodicMsg(unsigned long, unsigned long);
int32_t PassThruStartMsgFilter(unsigned long, unsigned long, const native_msg *, const native_msg *,
                               const native_msg *, unsigned long *);
int32_t PassThruStopMsgFilter(unsigned long, unsigned long);
int32_t PassThruSetProgrammingVoltage(unsigned long, unsigned long, unsigned long);
int32_t PassThruReadVersion(unsigned long, char *, char *, char *);
int32_t PassThruIoctl(unsigned long, unsigned long, const void *, void *);
extern int8_t LAST_ERROR[80];

static void *ptr32(uint32_t value) { return (void *)(uintptr_t)value; }

static void msg_to_native(native_msg *dst, const win32_msg *src)
{
    dst->ProtocolID = src->ProtocolID;
    dst->RxStatus = src->RxStatus;
    dst->TxFlags = src->TxFlags;
    dst->Timestamp = src->Timestamp;
    dst->DataSize = src->DataSize;
    dst->ExtraDataIndex = src->ExtraDataIndex;
    memcpy(dst->Data, src->Data, PM_DATA_LEN);
}

static void msg_to_win32(win32_msg *dst, const native_msg *src)
{
    dst->ProtocolID = (uint32_t)src->ProtocolID;
    dst->RxStatus = (uint32_t)src->RxStatus;
    dst->TxFlags = (uint32_t)src->TxFlags;
    dst->Timestamp = (uint32_t)src->Timestamp;
    dst->DataSize = (uint32_t)src->DataSize;
    dst->ExtraDataIndex = (uint32_t)src->ExtraDataIndex;
    memcpy(dst->Data, src->Data, PM_DATA_LEN);
}

static NTSTATUS wrap_open(void *args)
{
    const struct open_params *p = args;
    unsigned long id = 0;
    int32_t ret = PassThruOpen(ptr32(p->name), &id);
    if (!ret && p->device_id) *(uint32_t *)ptr32(p->device_id) = (uint32_t)id;
    return ret;
}

static NTSTATUS wrap_close(void *args)
{
    const struct close_params *p = args;
    return PassThruClose(p->device_id);
}

static NTSTATUS wrap_connect(void *args)
{
    const struct connect_params *p = args;
    unsigned long channel = 0;
    int32_t ret;
    if (!p->channel_id) return ERR_NULL_PARAMETER;
    ret = PassThruConnect(p->device_id, p->protocol_id, p->flags, p->baudrate, &channel);
    if (!ret) *(uint32_t *)ptr32(p->channel_id) = (uint32_t)channel;
    return ret;
}

static NTSTATUS wrap_disconnect(void *args)
{
    const struct disconnect_params *p = args;
    return PassThruDisconnect(p->channel_id);
}

static NTSTATUS wrap_messages(void *args, int writing)
{
    const struct messages_params *p = args;
    win32_msg *win_msgs = ptr32(p->messages);
    uint32_t *win_count = ptr32(p->count);
    native_msg *native_msgs;
    unsigned long count;
    uint32_t requested, i;
    int32_t ret;

    if (!win_msgs || !win_count) return ERR_NULL_PARAMETER;
    requested = *win_count;
    if (requested > 256) return ERR_EXCEEDED_LIMIT;
    if (!requested) return 0;
    native_msgs = calloc(requested, sizeof(*native_msgs));
    if (!native_msgs) return 7;
    if (writing) for (i = 0; i < requested; i++) msg_to_native(&native_msgs[i], &win_msgs[i]);
    count = requested;
    if (writing) ret = PassThruWriteMsgs(p->channel_id, native_msgs, &count, p->timeout);
    else ret = PassThruReadMsgs(p->channel_id, native_msgs, &count, p->timeout);
    *win_count = (uint32_t)count;
    if (!writing) for (i = 0; i < count && i < requested; i++) msg_to_win32(&win_msgs[i], &native_msgs[i]);
    free(native_msgs);
    return ret;
}

static NTSTATUS wrap_read(void *args) { return wrap_messages(args, 0); }
static NTSTATUS wrap_write(void *args) { return wrap_messages(args, 1); }

static NTSTATUS wrap_periodic_start(void *args)
{
    const struct periodic_start_params *p = args;
    win32_msg *win_msg = ptr32(p->message);
    native_msg msg;
    unsigned long id = 0;
    int32_t ret;
    if (!win_msg || !p->message_id) return ERR_NULL_PARAMETER;
    msg_to_native(&msg, win_msg);
    ret = PassThruStartPeriodicMsg(p->channel_id, &msg, &id, p->interval);
    if (!ret) *(uint32_t *)ptr32(p->message_id) = (uint32_t)id;
    return ret;
}

static NTSTATUS wrap_periodic_stop(void *args)
{
    const struct periodic_stop_params *p = args;
    return PassThruStopPeriodicMsg(p->channel_id, p->message_id);
}

static NTSTATUS wrap_filter_start(void *args)
{
    const struct filter_start_params *p = args;
    win32_msg *win_mask = ptr32(p->mask), *win_pattern = ptr32(p->pattern), *win_flow = ptr32(p->flow_control);
    native_msg mask, pattern, flow;
    unsigned long id = 0;
    int32_t ret;
    if (!win_mask || !win_pattern || !p->message_id) return ERR_NULL_PARAMETER;
    msg_to_native(&mask, win_mask);
    msg_to_native(&pattern, win_pattern);
    if (win_flow) msg_to_native(&flow, win_flow);
    ret = PassThruStartMsgFilter(p->channel_id, p->filter_type, &mask, &pattern,
                                 win_flow ? &flow : NULL, &id);
    if (!ret) *(uint32_t *)ptr32(p->message_id) = (uint32_t)id;
    return ret;
}

static NTSTATUS wrap_filter_stop(void *args)
{
    const struct filter_stop_params *p = args;
    return PassThruStopMsgFilter(p->channel_id, p->message_id);
}

static NTSTATUS wrap_voltage(void *args)
{
    const struct voltage_params *p = args;
    return PassThruSetProgrammingVoltage(p->device_id, p->pin, p->voltage);
}

static NTSTATUS wrap_version(void *args)
{
    const struct version_params *p = args;
    return PassThruReadVersion(p->device_id, ptr32(p->firmware_version),
                               ptr32(p->dll_version), ptr32(p->api_version));
}

static NTSTATUS wrap_error(void *args)
{
    const struct error_params *p = args;
    char *description = ptr32(p->description);
    if (!description) return ERR_NULL_PARAMETER;
    memcpy(description, LAST_ERROR, 80);
    description[79] = 0;
    return 0;
}

static NTSTATUS wrap_ioctl(void *args)
{
    const struct ioctl_params *p = args;
    void *input = ptr32(p->input), *output = ptr32(p->output);
    native_config_list list;
    native_config *items = NULL;
    native_msg in_msg, out_msg;
    int32_t ret;
    uint32_t i;

    if (p->ioctl_id == IOCTL_GET_CONFIG || p->ioctl_id == IOCTL_SET_CONFIG)
    {
        win32_config_list *win_list = input;
        win32_config *win_items;
        if (!win_list || !win_list->ConfigPtr) return ERR_NULL_PARAMETER;
        if (win_list->NumOfParams > 256) return ERR_EXCEEDED_LIMIT;
        win_items = ptr32(win_list->ConfigPtr);
        items = calloc(win_list->NumOfParams, sizeof(*items));
        if (!items) return 7;
        list.NumOfParams = win_list->NumOfParams;
        list.ConfigPtr = items;
        for (i = 0; i < win_list->NumOfParams; i++)
        {
            items[i].Parameter = win_items[i].Parameter;
            items[i].Value = win_items[i].Value;
        }
        ret = PassThruIoctl(p->channel_id, p->ioctl_id, &list, NULL);
        if (p->ioctl_id == IOCTL_GET_CONFIG)
            for (i = 0; i < win_list->NumOfParams; i++)
            {
                win_items[i].Parameter = (uint32_t)items[i].Parameter;
                win_items[i].Value = (uint32_t)items[i].Value;
            }
        free(items);
        return ret;
    }
    if (p->ioctl_id == IOCTL_FAST_INIT)
    {
        if (!input || !output) return ERR_NULL_PARAMETER;
        msg_to_native(&in_msg, input);
        memset(&out_msg, 0, sizeof(out_msg));
        ret = PassThruIoctl(p->channel_id, p->ioctl_id, &in_msg, &out_msg);
        if (!ret) msg_to_win32(output, &out_msg);
        return ret;
    }
    if (p->ioctl_id == IOCTL_READ_VBATT)
    {
        uint32_t value = 0;
        if (!output) return ERR_NULL_PARAMETER;
        ret = PassThruIoctl(p->channel_id, p->ioctl_id, NULL, &value);
        if (!ret) *(uint32_t *)output = value;
        return ret;
    }
    return PassThruIoctl(p->channel_id, p->ioctl_id, input, output);
}

const unixlib_entry_t __wine_unix_call_funcs[] =
{
    wrap_open, wrap_close, wrap_connect, wrap_disconnect, wrap_read, wrap_write,
    wrap_periodic_start, wrap_periodic_stop, wrap_filter_start, wrap_filter_stop,
    wrap_voltage, wrap_version, wrap_error, wrap_ioctl,
};

const unixlib_entry_t __wine_unix_call_wow64_funcs[] =
{
    wrap_open, wrap_close, wrap_connect, wrap_disconnect, wrap_read, wrap_write,
    wrap_periodic_start, wrap_periodic_stop, wrap_filter_start, wrap_filter_stop,
    wrap_voltage, wrap_version, wrap_error, wrap_ioctl,
};
