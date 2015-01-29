#singleinstance force
#Include <CHID>

CHID := new _CHID()

DevCount := CHID.GetRawInputDeviceList(DeviceList, CHID.GetRawInputDeviceList())
Loop % DevCount {
	s .= "#" A_Index " - Handle: " DeviceList[A_Index].hDevice ", Type: " _CHID.TYPE_RIM[DeviceList[A_Index].dwType] "`n"
}

msgbox % s
return
