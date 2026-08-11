#include <stdio.h>
#include <windows.h>
#include <setupapi.h>

static const GUID openport_interface_guid =
    {0x6d1781b7, 0xc987, 0x4f6c, {0x8d, 0x4f, 0x1e, 0xfc, 0x09, 0x8b, 0xea, 0x67}};

static void print_service(void)
{
    HKEY key;
    DWORD start = 0, type = 0, size = sizeof(DWORD);
    LONG status = RegOpenKeyExA(HKEY_LOCAL_MACHINE,
        "SYSTEM\\CurrentControlSet\\Services\\openport", 0, KEY_QUERY_VALUE, &key);
    if (status)
    {
        printf("SERVICE_OPEN=%ld\n", (long)status);
        return;
    }
    status = RegQueryValueExA(key, "Start", NULL, NULL, (BYTE *)&start, &size);
    printf("SERVICE_START_QUERY=%ld START=%lu\n", (long)status, (unsigned long)start);
    size = sizeof(DWORD);
    status = RegQueryValueExA(key, "Type", NULL, NULL, (BYTE *)&type, &size);
    printf("SERVICE_TYPE_QUERY=%ld TYPE=%lu\n", (long)status, (unsigned long)type);
    RegCloseKey(key);
}

int main(void)
{
    HDEVINFO devices;
    SP_DEVICE_INTERFACE_DATA interface_data;
    PSP_DEVICE_INTERFACE_DETAIL_DATA_A detail;
    DWORD required = 0, error;
    HANDLE device;

    print_service();
    devices = SetupDiGetClassDevsA(&openport_interface_guid, NULL, NULL,
                                   DIGCF_PRESENT | DIGCF_DEVICEINTERFACE);
    if (devices == INVALID_HANDLE_VALUE)
    {
        printf("ENUM_SET_FAIL=%lu\n", (unsigned long)GetLastError());
        return 2;
    }
    interface_data.cbSize = sizeof(interface_data);
    if (!SetupDiEnumDeviceInterfaces(devices, NULL, &openport_interface_guid, 0,
                                     &interface_data))
    {
        printf("ENUM_INTERFACE_FAIL=%lu\n", (unsigned long)GetLastError());
        SetupDiDestroyDeviceInfoList(devices);
        return 3;
    }
    SetupDiGetDeviceInterfaceDetailA(devices, &interface_data, NULL, 0, &required, NULL);
    error = GetLastError();
    printf("DETAIL_SIZE=%lu SIZE_ERROR=%lu\n", (unsigned long)required,
           (unsigned long)error);
    detail = HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, required);
    if (!detail)
    {
        SetupDiDestroyDeviceInfoList(devices);
        return 4;
    }
    detail->cbSize = sizeof(*detail);
    if (!SetupDiGetDeviceInterfaceDetailA(devices, &interface_data, detail, required,
                                          NULL, NULL))
    {
        printf("DETAIL_FAIL=%lu\n", (unsigned long)GetLastError());
        HeapFree(GetProcessHeap(), 0, detail);
        SetupDiDestroyDeviceInfoList(devices);
        return 5;
    }
    printf("INTERFACE=%s\n", detail->DevicePath);
    SetLastError(ERROR_SUCCESS);
    device = CreateFileA(detail->DevicePath, GENERIC_READ | GENERIC_WRITE,
                         FILE_SHARE_READ | FILE_SHARE_WRITE, NULL, OPEN_EXISTING, 0, NULL);
    error = GetLastError();
    printf("CREATE_FILE=%s ERROR=%lu\n", device == INVALID_HANDLE_VALUE ? "FAIL" : "OK",
           (unsigned long)error);
    if (device != INVALID_HANDLE_VALUE) CloseHandle(device);
    HeapFree(GetProcessHeap(), 0, detail);
    SetupDiDestroyDeviceInfoList(devices);
    return device == INVALID_HANDLE_VALUE ? 6 : 0;
}
