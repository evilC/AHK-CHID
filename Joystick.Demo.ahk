; REQUIRES FUCNTION BINDING AHK TEST BUILD >= v1.1.19.03-37+gd7b054a from HERE: http://ahkscript.org/boards/viewtopic.php?f=24&t=5802

#include CHID.ahk

#singleinstance force
SetBatchLines -1
OutputDebug, DBGVIEWCLEAR

jt := new JoystickTester()
return

class JoystickTester extends CHID {
	GUI_WIDTH := 661
	
	__New(){
		base.__New()
		Gui, Add, Text, % "xm Center w" this.GUI_WIDTH, % "Select a Joystick to subscribe to WM_INPUT messages for that UsagePage/Usage."
		Gui, Add, Listview, % "hwndhLV w" this.GUI_WIDTH " h150 +AltSubmit +Grid",Handle|GUID|Name|Btns|Axes|POVs|VID|PID|UsPage|Usage
		this.hLV := hLV
		LV_Modifycol(1,50)
		LV_Modifycol(2,40)
		LV_Modifycol(3,130)
		LV_Modifycol(4,40)
		LV_Modifycol(5,140)
		LV_Modifycol(6,50)
		LV_Modifycol(7,50)
		LV_Modifycol(8,50)
		LV_Modifycol(9,50)
		LV_Modifycol(10,50)
		
		Gui, Add, Text, % "hwndhAxes w300 h200 xm Section"
		this.hAxes := hAxes
		Gui, Add, Text, % "hwndhButtons w300 h200 x331 ys"
		this.hButtons := hButtons
		
		Gui, Add, Text, xm Section, % "Time to process WM_INPUT message (Including time to assemble debug strings, but not update UI), in seconds: "
		Gui, Add, Text, % "hwndhProcessTime w50 ys"
		this.hProcessTime := hProcessTime
		Gui, Show, y0, CHID Joystick Tester
		fn := this.DeviceSelected.Bind(this)
		
		GuiControl +g, % this.hLV, % fn
		
		for handle, device in this.DevicesByHandle {
			if (!device.NumButtons && !device.NumAxes){
				; Ignore devices with no buttons or axes
				continue
			}
			LV_Add(, handle, device.GUID, device.HumanName, device.NumButtons, device.AxisString, device.NumPOVs, device.VID, device.PID, device.UsagePage, device.Usage )
		}
	}
	
	DeviceSelected(){
		static LastSelected := -1
		; Listviews fire g-labels on down event and up event of click, filter out up event
		LV_GetText(handle, LV_GetNext())
		if (A_GuiEvent = "i"){
			;this.RegisterDevice(this.DevicesByHandle[handle])
			fn := this.DeviceChanged.Bind(this)
			this.DevicesByHandle[handle].RegisterCallback(fn)
		}
		return 1
	}
	
	; A subscribed device changed
	DeviceChanged(device){
		LV_GetText(handle, LV_GetNext())
		if (device.handle = handle){
			; Device is the one currently selected in the LV
			GuiControl, , % this.hButtons, % device.btnstring
			GuiControl, , % this.hAxes, % device.AxisDebug
			GuiControl, , % this.hProcessTime, % device._ProcessTime
		}
	}
}

Esc::
GuiClose:
	ExitApp
