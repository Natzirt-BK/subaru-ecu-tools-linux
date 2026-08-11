#include <ddk/ntddk.h>
#include <stdint.h>
#include "openport_unix_calls.h"

typedef uint64_t unixlib_handle_t;
extern unixlib_handle_t __wine_unixlib_handle;
extern NTSTATUS (WINAPI *__wine_unix_call_dispatcher)(unixlib_handle_t, unsigned int, void *);
extern NTSTATUS WINAPI __wine_init_unix_call(void);
#define WINE_UNIX_CALL(code, args) __wine_unix_call_dispatcher(__wine_unixlib_handle, (code), (args))

static DEVICE_OBJECT *openport_device;
static UNICODE_STRING openport_symbolic_link;
static BOOLEAN openport_symbolic_link_created;

struct device_extension
{
    DEVICE_OBJECT *lower_device;
    UNICODE_STRING interface_name;
};

static const GUID openport_interface_guid =
    {0x6d1781b7, 0xc987, 0x4f6c, {0x8d, 0x4f, 0x1e, 0xfc, 0x09, 0x8b, 0xea, 0x67}};

static NTSTATUS complete_irp(IRP *irp, NTSTATUS status, ULONG_PTR information);

static NTSTATUS WINAPI dispatch_passthrough(DEVICE_OBJECT *device, IRP *irp)
{
    struct device_extension *extension = device->DeviceExtension;
    if (!extension || !extension->lower_device)
        return complete_irp(irp, STATUS_NOT_SUPPORTED, 0);
    IoSkipCurrentIrpStackLocation(irp);
    return IoCallDriver(extension->lower_device, irp);
}

static NTSTATUS WINAPI dispatch_transfer(DEVICE_OBJECT *device, IRP *irp)
{
    IO_STACK_LOCATION *stack = IoGetCurrentIrpStackLocation(irp);
    struct openport_transfer transfer;
    NTSTATUS status;
    unsigned int call;
    if (device != openport_device) return complete_irp(irp, STATUS_NOT_SUPPORTED, 0);
    transfer.buffer = (UINT_PTR)irp->AssociatedIrp.SystemBuffer;
    if (stack->MajorFunction == IRP_MJ_READ)
    {
        transfer.length = stack->Parameters.Read.Length;
        call = unix_read;
    }
    else
    {
        transfer.length = stack->Parameters.Write.Length;
        call = unix_write;
    }
    transfer.transferred = 0;
    transfer.timeout_ms = 100;
    status = WINE_UNIX_CALL(call, &transfer);
    return complete_irp(irp, status, transfer.transferred);
}

static NTSTATUS complete_irp(IRP *irp, NTSTATUS status, ULONG_PTR information)
{
    irp->IoStatus.Status = status;
    irp->IoStatus.Information = information;
    IoCompleteRequest(irp, IO_NO_INCREMENT);
    return status;
}

static NTSTATUS WINAPI dispatch_create_close(DEVICE_OBJECT *device, IRP *irp)
{
    NTSTATUS status;
    if (device != openport_device) return complete_irp(irp, STATUS_NOT_SUPPORTED, 0);
    status = WINE_UNIX_CALL(IoGetCurrentIrpStackLocation(irp)->MajorFunction == IRP_MJ_CREATE ?
                            unix_open : unix_close, NULL);
    return complete_irp(irp, status, 0);
}

static NTSTATUS WINAPI dispatch_ioctl(DEVICE_OBJECT *device, IRP *irp)
{
    IO_STACK_LOCATION *stack = IoGetCurrentIrpStackLocation(irp);
    struct openport_ioctl request;
    NTSTATUS status;
    if (device != openport_device) return complete_irp(irp, STATUS_NOT_SUPPORTED, 0);
    request.buffer = (UINT_PTR)irp->AssociatedIrp.SystemBuffer;
    request.code = stack->Parameters.DeviceIoControl.IoControlCode;
    request.input_length = stack->Parameters.DeviceIoControl.InputBufferLength;
    request.output_length = stack->Parameters.DeviceIoControl.OutputBufferLength;
    status = WINE_UNIX_CALL(unix_ioctl, &request);
    return complete_irp(irp, status, status == STATUS_SUCCESS ? request.output_length : 0);
}

static void WINAPI driver_unload(DRIVER_OBJECT *driver)
{
    if (openport_device)
    {
        struct device_extension *extension = openport_device->DeviceExtension;
        if (openport_symbolic_link_created)
        {
            IoDeleteSymbolicLink(&openport_symbolic_link);
            openport_symbolic_link_created = FALSE;
        }
        if (extension && extension->interface_name.Buffer)
        {
            IoSetDeviceInterfaceState(&extension->interface_name, FALSE);
            RtlFreeUnicodeString(&extension->interface_name);
        }
        if (extension && extension->lower_device) IoDetachDevice(extension->lower_device);
        IoDeleteDevice(openport_device);
        openport_device = NULL;
    }
}

static NTSTATUS create_standalone_device(DRIVER_OBJECT *driver)
{
    struct device_extension *extension;
    DEVICE_OBJECT *device;
    UNICODE_STRING device_name;
    NTSTATUS status;

    RtlInitUnicodeString(&device_name, L"\\Device\\OpenPortWine");
    status = IoCreateDevice(driver, sizeof(*extension), &device_name, FILE_DEVICE_UNKNOWN,
                            0, FALSE, &device);
    if (status) return status;
    extension = device->DeviceExtension;
    extension->lower_device = NULL;
    extension->interface_name.Buffer = NULL;
    extension->interface_name.Length = 0;
    extension->interface_name.MaximumLength = 0;
    RtlInitUnicodeString(&openport_symbolic_link,
        L"\\??\\USB#VID_0403&PID_CC4D#272&256&1&4#{6D1781B7-C987-4F6C-8D4F-1EFC098BEA67}");
    status = IoCreateSymbolicLink(&openport_symbolic_link, &device_name);
    if (status)
    {
        IoDeleteDevice(device);
        return status;
    }
    openport_symbolic_link_created = TRUE;
    device->Flags |= DO_BUFFERED_IO;
    device->Flags &= ~DO_DEVICE_INITIALIZING;
    openport_device = device;
    return STATUS_SUCCESS;
}

static NTSTATUS WINAPI add_device(DRIVER_OBJECT *driver, DEVICE_OBJECT *physical_device)
{
    struct device_extension *extension;
    DEVICE_OBJECT *device;
    UNICODE_STRING device_name;
    NTSTATUS status;

    if (openport_device) return STATUS_SUCCESS;
    RtlInitUnicodeString(&device_name, L"\\Device\\OpenPortWinePnP");
    status = IoCreateDevice(driver, sizeof(*extension), &device_name, FILE_DEVICE_UNKNOWN,
                            0, FALSE, &device);
    if (status) return status;
    extension = device->DeviceExtension;
    extension->interface_name.Buffer = NULL;
    extension->interface_name.Length = 0;
    extension->interface_name.MaximumLength = 0;
    extension->lower_device = IoAttachDeviceToDeviceStack(device, physical_device);
    if (!extension->lower_device)
    {
        IoDeleteDevice(device);
        return STATUS_NO_SUCH_DEVICE;
    }
    status = IoRegisterDeviceInterface(physical_device, &openport_interface_guid,
                                       NULL, &extension->interface_name);
    if (!status) status = IoSetDeviceInterfaceState(&extension->interface_name, TRUE);
    if (status)
    {
        if (extension->interface_name.Buffer) RtlFreeUnicodeString(&extension->interface_name);
        IoDetachDevice(extension->lower_device);
        IoDeleteDevice(device);
        return status;
    }
    device->Flags |= DO_BUFFERED_IO;
    device->Flags &= ~DO_DEVICE_INITIALIZING;
    openport_device = device;
    return STATUS_SUCCESS;
}

NTSTATUS WINAPI DriverEntry(DRIVER_OBJECT *driver, UNICODE_STRING *registry_path)
{
    unsigned int i;
    NTSTATUS status;

    status = __wine_init_unix_call();
    if (status) return status;
    for (i = 0; i <= IRP_MJ_MAXIMUM_FUNCTION; i++) driver->MajorFunction[i] = dispatch_passthrough;
    driver->MajorFunction[IRP_MJ_CREATE] = dispatch_create_close;
    driver->MajorFunction[IRP_MJ_CLOSE] = dispatch_create_close;
    driver->MajorFunction[IRP_MJ_READ] = dispatch_transfer;
    driver->MajorFunction[IRP_MJ_WRITE] = dispatch_transfer;
    driver->MajorFunction[IRP_MJ_DEVICE_CONTROL] = dispatch_ioctl;
    driver->MajorFunction[IRP_MJ_PNP] = dispatch_passthrough;
    driver->MajorFunction[IRP_MJ_POWER] = dispatch_passthrough;
    driver->DriverExtension->AddDevice = add_device;
    driver->DriverUnload = driver_unload;
    /* Wine may enumerate the registry interface without ever delivering the
     * PnP AddDevice callback.  The bridge transports USB through libusb and
     * does not need the Wine USB PDO, so publish the expected device link as
     * soon as the service starts.  AddDevice remains for older Wine behavior. */
    return create_standalone_device(driver);
}
