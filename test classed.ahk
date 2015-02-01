; TEST CODE
#singleinstance force
#Include CHID Helper.ahk

Gui, Add, Listview, w785 h400 ,#|Type|VID|PID|UsagePage|Usage
Gui, Show, w800 h600

HID := new CHID_Helper()

; Use NumDevices straight away, class will automatically make the needed calls to discover value.
Loop % HID.DeviceList.NumDevices {
	dev := HID.DeviceList[A_Index]
	LV_Add(,A_INDEX, CHID.RIM_TYPE[dev.Type])
	;LV_Add(,A_INDEX, CHID.RIM_TYPE[dev.Type], dev.Info.hid.VendorID, Data.hid.ProductId, Data.hid.UsagePage, Data.hid.Usage )
}
LV_Modifycol()
return

Esc::
GuiClose:
	ExitApp