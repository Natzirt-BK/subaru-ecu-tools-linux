#ifndef OPENPORT_UNIX_CALLS_H
#define OPENPORT_UNIX_CALLS_H

#include <stdint.h>

enum openport_unix_call
{
    unix_open,
    unix_close,
    unix_read,
    unix_write,
    unix_ioctl,
    unix_calls_count
};

struct openport_ioctl
{
    uint64_t buffer;
    uint32_t code;
    uint32_t input_length;
    uint32_t output_length;
};

struct openport_transfer
{
    uint64_t buffer;
    uint32_t length;
    uint32_t transferred;
    uint32_t timeout_ms;
};

#endif
