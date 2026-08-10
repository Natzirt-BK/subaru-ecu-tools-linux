#define WINE_UNIX_LIB

#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <libusb.h>
#include <unixlib.h>

#include "openport_unix_calls.h"

#define STATUS_SUCCESS          ((NTSTATUS)0x00000000)
#define STATUS_DEVICE_NOT_READY ((NTSTATUS)0xc00000a3)
#define STATUS_IO_TIMEOUT       ((NTSTATUS)0xc00000b5)
#define STATUS_UNSUCCESSFUL     ((NTSTATUS)0xc0000001)

static libusb_context *usb_context;
static libusb_device_handle *usb_device;
static uint8_t endpoint_in, endpoint_out;
static int data_interface = -1;
static unsigned int open_count;
static pthread_mutex_t state_lock = PTHREAD_MUTEX_INITIALIZER;
static pthread_mutex_t read_lock = PTHREAD_MUTEX_INITIALIZER;
static pthread_mutex_t write_lock = PTHREAD_MUTEX_INITIALIZER;

static NTSTATUS usb_status(int status)
{
    if (!status) return STATUS_SUCCESS;
    if (status == LIBUSB_ERROR_TIMEOUT) return STATUS_IO_TIMEOUT;
    if (status == LIBUSB_ERROR_NO_DEVICE) return STATUS_DEVICE_NOT_READY;
    return STATUS_UNSUCCESSFUL;
}

static int discover_endpoints(libusb_device_handle *handle)
{
    struct libusb_config_descriptor *config = NULL;
    int i, j, k, result;

    result = libusb_get_active_config_descriptor(libusb_get_device(handle), &config);
    if (result || !config || !config->bNumInterfaces) return result ? result : LIBUSB_ERROR_NOT_FOUND;
    endpoint_in = endpoint_out = 0;
    data_interface = -1;
    for (i = 0; i < config->bNumInterfaces; ++i)
    {
        const struct libusb_interface *usb_interface = &config->interface[i];
        for (j = 0; j < usb_interface->num_altsetting; ++j)
        {
            const struct libusb_interface_descriptor *descriptor = &usb_interface->altsetting[j];
            uint8_t candidate_in = 0, candidate_out = 0;
            for (k = 0; k < descriptor->bNumEndpoints; ++k)
            {
                const struct libusb_endpoint_descriptor *ep = &descriptor->endpoint[k];
                if ((ep->bmAttributes & LIBUSB_TRANSFER_TYPE_MASK) != LIBUSB_TRANSFER_TYPE_BULK) continue;
                if (ep->bEndpointAddress & LIBUSB_ENDPOINT_IN) candidate_in = ep->bEndpointAddress;
                else candidate_out = ep->bEndpointAddress;
            }
            if (candidate_in && candidate_out)
            {
                endpoint_in = candidate_in;
                endpoint_out = candidate_out;
                data_interface = descriptor->bInterfaceNumber;
                break;
            }
        }
        if (data_interface >= 0) break;
    }
    libusb_free_config_descriptor(config);
    return data_interface >= 0 ? 0 : LIBUSB_ERROR_NOT_FOUND;
}

static NTSTATUS wrap_open(void *args)
{
    int result = 0;
    (void)args;
    pthread_mutex_lock(&state_lock);
    if (open_count++) { fprintf(stderr, "openport: reuse handle count=%u\n", open_count); goto done; }
    result = libusb_init(&usb_context);
    if (result) goto fail;
    usb_device = libusb_open_device_with_vid_pid(usb_context, 0x0403, 0xcc4d);
    if (!usb_device) { result = LIBUSB_ERROR_NO_DEVICE; goto fail; }
    libusb_set_auto_detach_kernel_driver(usb_device, 1);
    result = discover_endpoints(usb_device);
    if (!result) result = libusb_claim_interface(usb_device, data_interface);
    if (!result)
    {
        fprintf(stderr, "openport: opened 0403:cc4d interface=%d ep-in=%02x ep-out=%02x\n",
                data_interface, endpoint_in, endpoint_out);
        goto done;
    }
fail:
    fprintf(stderr, "openport: open failed libusb=%d (%s)\n", result, libusb_error_name(result));
    if (usb_device) libusb_close(usb_device);
    if (usb_context) libusb_exit(usb_context);
    usb_device = NULL;
    usb_context = NULL;
    open_count = 0;
done:
    pthread_mutex_unlock(&state_lock);
    return usb_status(result);
}

static NTSTATUS wrap_close(void *args)
{
    (void)args;
    pthread_mutex_lock(&state_lock);
    if (open_count && !--open_count)
    {
        libusb_release_interface(usb_device, data_interface);
        libusb_close(usb_device);
        libusb_exit(usb_context);
        usb_device = NULL;
        usb_context = NULL;
    }
    pthread_mutex_unlock(&state_lock);
    return STATUS_SUCCESS;
}

static NTSTATUS transfer(void *args, int reading)
{
    struct openport_transfer *p = args;
    pthread_mutex_t *lock = reading ? &read_lock : &write_lock;
    int actual = 0, result;
    if (!p || !p->buffer || !p->length) return STATUS_SUCCESS;
    pthread_mutex_lock(lock);
    if (!usb_device) result = LIBUSB_ERROR_NO_DEVICE;
    else result = libusb_bulk_transfer(usb_device, reading ? endpoint_in : endpoint_out,
                                       (unsigned char *)(uintptr_t)p->buffer, p->length,
                                       &actual, p->timeout_ms ? p->timeout_ms : 100);
    pthread_mutex_unlock(lock);
    p->transferred = actual > 0 ? (uint32_t)actual : 0;
    fprintf(stderr, "openport: %s requested=%u actual=%d result=%d (%s)\n",
            reading ? "read" : "write", p->length, actual, result,
            result ? libusb_error_name(result) : "success");
    return usb_status(result);
}

static NTSTATUS wrap_read(void *args) { return transfer(args, 1); }
static NTSTATUS wrap_write(void *args) { return transfer(args, 0); }

static NTSTATUS wrap_ioctl(void *args)
{
    const struct openport_ioctl *p = args;
    const unsigned char *buffer = (const unsigned char *)(uintptr_t)p->buffer;
    uint32_t i, count = p->input_length < 96 ? p->input_length : 96;
    fprintf(stderr, "openport: ioctl=%08x in=%u out=%u data=",
            p->code, p->input_length, p->output_length);
    for (i = 0; buffer && i < count; ++i) fprintf(stderr, "%02x", buffer[i]);
    fputc('\n', stderr);
    /* The OpenPort 2.0 driver only dispatches 0x220000, 0x220004 and
       0x220008.  Do not claim FTDI/libusb compatibility IOCTLs succeeded. */
    return STATUS_UNSUCCESSFUL;
}

const unixlib_entry_t __wine_unix_call_funcs[] =
{
    wrap_open, wrap_close, wrap_read, wrap_write, wrap_ioctl
};

const unixlib_entry_t __wine_unix_call_wow64_funcs[] =
{
    wrap_open, wrap_close, wrap_read, wrap_write, wrap_ioctl
};
