#singleinstance force
#Include <CHID>

Gui, Add, Listview, w785 h400 ,#|Type
Gui, Show, w800 h600


CHID := new _CHID()

DevCount := CHID.GetRawInputDeviceList()
CHID.GetRawInputDeviceList(DeviceList, DevCount)

Loop % DevCount {
	LV_Add(,A_INDEX, _CHID.RIM_TYPE[DeviceList[A_Index].dwType])
	;s .= "#" A_Index " - Handle: " DeviceList[A_Index].hDevice ", Type: " _CHID.RIM_TYPE[DeviceList[A_Index].dwType] "`n"
}

;msgbox % s
return

Esc::
GuiClose:
	ExitApp