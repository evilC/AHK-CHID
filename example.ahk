#singleinstance force
#Include <CHID>

Gui, Add, Listview, w785 h400 ,#|Type|VID|PID|UsagePage|Usage
Gui, Show, w800 h600

CHID := new _CHID()

; Use NumDevices straight away, class will automatically make the needed calls to discover value.
Loop % CHID.DeviceList.NumDevices {
	dev := CHID.DeviceList.Device[A_Index]
	LV_Add(,A_INDEX, _CHID.RIM_TYPE[dev.Type])
}

LV_Modifycol()
return

Esc::
GuiClose:
	ExitApp