#include <CHID>
#singleinstance force

HID := new _HID()

iCount := HID.GetRawInputDeviceList(0,iCount)
DeviceList := new _Struct("HID.STRUCT_RAWINPUTDEVICELIST[" iCount "]")
HID.GetRawInputDeviceList(DeviceList, iCount)

Loop %  iCount {
	s .= "#" A_Index " - Handle: " DeviceList[A_Index].hDevice ", Type: " HID.TYPE_RIM[DeviceList[A_Index].dwType] "`n"
}

msgbox % s
return
