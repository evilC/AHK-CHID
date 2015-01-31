#singleinstance force
#Include CHID.ahk

Gui, Add, Listview, w785 h400 ,#|Type|VID|PID|UsagePage|Usage
Gui, Show, w800 h600

HID := new CHID()
NumDevices := HID.GetRawInputDeviceList()
HID.GetRawInputDeviceList(DeviceList,NumDevices)

handle := DeviceList[1].Device
DevSize := HID.GetRawInputDeviceInfo(handle)
HID.GetRawInputDeviceInfo(handle, ,Data, DevSize)

;msgbox % Data.Type


Loop % NumDevices {
	dev := DeviceList[A_Index]
	LV_Add(,A_INDEX, CHID.RIM_TYPE[dev.Type])
}

LV_Modifycol()
return

Esc::
GuiClose:
	ExitApp