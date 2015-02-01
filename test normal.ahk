#Include <_Struct>
#singleinstance force
#Include CHID.ahk

Gui, Add, Listview, w785 h400 ,#|Type|VID|PID|UsagePage|Usage
Gui, Show, w800 h600

HID := new CHID()
NumDevices := HID.GetRawInputDeviceList()
HID.GetRawInputDeviceList(DeviceList,NumDevices)
DevSize := HID.GetRawInputDeviceInfo(DeviceList[1].Device)

Loop % NumDevices {
	dev := DeviceList[A_Index]
	handle := DeviceList[A_Index].Device
	HID.GetRawInputDeviceInfo(handle, ,Data, DevSize)
	LV_Add(,A_INDEX, CHID.RIM_TYPE[dev.Type], Data.hid.VendorID, Data.hid.ProductId, Data.hid.UsagePage, Data.hid.Usage )
}

LV_Modifycol()
return

Esc::
GuiClose:
	ExitApp
