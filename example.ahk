#singleinstance force
#Include <CHID>

Gui, Add, Listview, w785 h400 ,#|Type|VID|PID|UsagePage|Usage
Gui, Show, w800 h600


CHID := new _CHID()

DevCount := CHID.GetRawInputDeviceList()
CHID.GetRawInputDeviceList(DeviceList, DevCount)

Loop % DevCount {
	if (DeviceList[A_Index].dwType = 2){
		pcbSize := CHID.GetRawInputDeviceInfo(DeviceList[A_Index].hDevice, , pData, pcbSize)
		CHID.GetRawInputDeviceInfo(DeviceList[A_Index].hDevice, , pData, pcbSize)
		
		LV_Add(,A_INDEX, _CHID.RIM_TYPE[DeviceList[A_Index].dwType], pData.hid.dwVendorId)

	}
	;s .= "#" A_Index " - Handle: " DeviceList[A_Index].hDevice ", Type: " _CHID.RIM_TYPE[DeviceList[A_Index].dwType] "`n"
}
LV_Modifycol()
;msgbox % s
return

Esc::
GuiClose:
	ExitApp