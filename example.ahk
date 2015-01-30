#singleinstance force
#Include <CHID>

Gui, Add, Listview, w785 h400 ,#|Type|VID|PID|UsagePage|Usage
Gui, Show, w800 h600


CHID := new _CHID()

DevCount := CHID.GetRawInputDeviceList()
CHID.GetRawInputDeviceList(DeviceList, DevCount)

Loop % DevCount {
	if (DeviceList[A_Index].Type = 2){
		Size := CHID.GetRawInputDeviceInfo(DeviceList[A_Index].Device, , Data, Size)
		CHID.GetRawInputDeviceInfo(DeviceList[A_Index].Device, , Data, Size)
		
		LV_Add(,A_INDEX, _CHID.RIM_TYPE[DeviceList[A_Index].Type], Data.hid.VendorId)

	}
	;s .= "#" A_Index " - Handle: " DeviceList[A_Index].hDevice ", Type: " _CHID.RIM_TYPE[DeviceList[A_Index].dwType] "`n"
}
LV_Modifycol()
;msgbox % s
return

Esc::
GuiClose:
	ExitApp