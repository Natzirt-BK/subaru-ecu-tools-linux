/* Loader diagnostic only: no device, USB, or vehicle access. */
typedef long NTSTATUS;
#define STATUS_SUCCESS ((NTSTATUS)0)
#define WINAPI __attribute__((stdcall))

NTSTATUS WINAPI DriverEntry(void *driver, void *registry_path)
{
    (void)driver;
    (void)registry_path;
    return STATUS_SUCCESS;
}
