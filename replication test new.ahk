/*
ToDo: 
Investigate why vJoy stick does not get messages under these circumstances:
1) Speedlink "Generic USB Joystick" is plugged in at startup.
2) Code is executing under x64
In this case, no message for handle of vJoy stick gets sent.
If you unplug the "bad" stick + start up, then plug in bad stick, you can see the messages for the bad stick get ignored.

Intersting facts:
1) The bad stick is always the first in the list.
2) The handle for the stick is abnormally large.
3) The handle for this stick sometimes changes, whereas the others do not.
4) The bad stick is a generic 4-axis psx-style gamepad with an "analog" button. There appear to be two Z axes, though they always read the same. 
*/
#include <CHID>
#Include <_Struct>
#Include <WinStructs>

#singleinstance force
SetBatchLines -1

GUI_WIDTH := 701

Gui +Resize -MaximizeBox -MinimizeBox
Gui, Add, Text, % "xm Center w" GUI_WIDTH, % "Select a Joystick to subscribe to WM_INPUT messages for that stick."
Gui, Add, Listview, % "w" GUI_WIDTH " h200 vlvDL AltSubmit +Grid",#|Name|Btns|Axes|POVs|VID|PID|UsPage|Usage|handle
LV_Modifycol(1,20)
LV_Modifycol(2,180)
LV_Modifycol(3,40)
LV_Modifycol(4,140)
LV_Modifycol(5,50)
LV_Modifycol(6,50)
LV_Modifycol(7,50)
LV_Modifycol(8,50)
LV_Modifycol(9,50)
LV_Modifycol(10,50)

Gui, Add, Text, % "hwndhAxes w300 h200 xm y240"
Gui, Add, Text, % "hwndhButtons w300 h200 x331 y240"
Gui, Add, Text, xm Section, % "Time to process WM_INPUT message (Including time to assemble debug strings, but not update UI), in seconds: "
Gui, Add, Text, % "hwndhProcessTime w50 ys"

Gui, Show,, Joystick Info

BuildDeviceList()
return

class CHIDHelper extends CHID {
	class RAWINPUTDEVICELIST {
		DeviceList := []
		__New(){
			static DeviceSize := 2 * A_PtrSize ; sizeof(RAWINPUTDEVICELIST)
			CHID.GetRawInputDeviceList(0, NumDevices, DeviceSize)
			this.NumDevices := NumDevices
			this.DeviceSize := DeviceSize
			VarSetCapacity(Data, DeviceSize * this.NumDevices)
			CHID.GetRawInputDeviceList(&Data, this.NumDevices, this.DeviceSize)
			Loop % this.NumDevices {
				b := (DeviceSize * (A_Index - 1))
				this.DeviceList[A_Index] := {
				(Join,
					_size: DeviceSize
					hDevice: NumGet(data, b, "Uint")
					dwType: NumGet(data, b + A_PtrSize, "Uint")
				)}
				OutputDebug, % "DeviceList: Adding handle " this.DeviceList[A_Index].hDevice
			}
		}
		
		__Get(aParam){
			if (aParam is Numeric){
				return this.DeviceList[aParam]
			}
		}
	}
	
	class RID_DEVICE_INFO {
		__New(handle){
			static RIM_TYPEMOUSE := 0, RIM_TYPEKEYBOARD := 1, RIM_TYPEHID := 2
			static DevSize := 32
			
			VarSetCapacity(RID_DEVICE_INFO, DevSize)
			NumPut(DevSize, RID_DEVICE_INFO, 0, "unit") ; cbSize must equal sizeof(RID_DEVICE_INFO) = 32
			CHID.GetRawInputDeviceInfo(handle, CHID.RIDI_DEVICEINFO, &RID_DEVICE_INFO, DevSize)
			
			this.Data := {}
			this.Data.cbSize := NumGet(RID_DEVICE_INFO, 0, "Uint")
			this.Data.dwType := NumGet(RID_DEVICE_INFO, 4, "Uint")
			if (this.Data.dwType = RIM_TYPEHID){
				this.Data.hid := {
				(Join,
					dwVendorId: NumGet(RID_DEVICE_INFO, 8, "Uint")
					dwProductId: NumGet(RID_DEVICE_INFO, 12, "Uint")
					dwVersionNumber: NumGet(RID_DEVICE_INFO, 16, "Uint")
					usUsagePage: NumGet(RID_DEVICE_INFO, 20, "UShort")
					usUsage: NumGet(RID_DEVICE_INFO, 22, "UShort")
				)}
			}

		}
	}
}

BuildDeviceList(){
	global HID
	global SelectedDevice, DeviceList, DevData
	global hAxes, hButtons, hProcessTime
	global PreparsedData, ppSize, CapsArray, ButtonCapsArray, ValueCapsArray

	static RIM_TYPEMOUSE := 0, RIM_TYPEKEYBOARD := 1, RIM_TYPEHID := 2

	OutputDebug, DBGVIEWCLEAR
	;HID := new CHID()
	HID := new CHIDHelper()
	
	gosub, SelectvJoyDevice
	;SelectvJoyDevice()
}

return

SelectvJoyDevice:
    ; Register Device
    handle := 131145
    rid := new _struct(WinStructs.RAWINPUTDEVICE)
    rid.usUsagePage := 1
    rid.usUsage := 4
    rid.hwndTarget := WinExist("A") ; A_ScriptHwnd
    rid.dwFlags := 0x00000100 ; RIDEV_INPUTSINK
    
    ret := HID.RegisterRawInputDevices(rid[], 1, sizeof(WinStructs.RAWINPUTDEVICE))
    SelectedDevice := handle
    OnMessage(0x00FF, "InputMsg")
    return

/*
SelectvJoyDevice(){
	global HID, SelectedDevice, DeviceList, DevData
	
    ; Register Device
    handle := 131145
    rid := new _struct(WinStructs.RAWINPUTDEVICE)
    rid.usUsagePage := 1
    rid.usUsage := 4
    rid.hwndTarget := WinExist("A") ; A_ScriptHwnd
    rid.dwFlags := 0x00000100 ; RIDEV_INPUTSINK
    
    ret := HID.RegisterRawInputDevices(rid[], 1, sizeof(WinStructs.RAWINPUTDEVICE))
    SelectedDevice := handle
    OnMessage(0x00FF, "InputMsg")
    return

	
	static DevSize := 8 + A_PtrSize
	;RAWINPUTDEVICE := StaticSetCapacity(RAWINPUTDEVICE, DevSize)
	VarSetCapacity(RAWINPUTDEVICE, DevSize)
	MsgBox % DevSize
	;NumPut(DevData[s].hid.usUsagePage, RAWINPUTDEVICE, 0, "UShort")
	;NumPut(DevData[s].hid.usUsage, RAWINPUTDEVICE, 2, "UShort")
	NumPut(1, RAWINPUTDEVICE, 0, "UShort")
	NumPut(4, RAWINPUTDEVICE, 2, "UShort")
	Flags := 0x00000100 ; RIDEV_INPUTSINK
	NumPut(Flags, RAWINPUTDEVICE, 4, "Uint")
	hwnd := WinExist("A")
	NumPut(hwnd, RAWINPUTDEVICE, 8, "Uint")
	r := HID.RegisterRawInputDevices(&RAWINPUTDEVICE, 1, DevSize)
	;SelectedDevice := DeviceList[s].hDevice
	SelectedDevice := 131145
	;MsgBox % "subscribing to`nDevice: " DeviceList[s].hDevice "`nPage: " DevData[s].hid.usUsagePage "`nUsage: " DevData[s].hid.usUsage
	OnMessage(0x00FF, "InputMsg")
	return
}
*/

; Process WM_INPUT messages ===================================================
InputMsg(wParam, lParam) {
	Critical
	global HID
	global SelectedDevice
	global hAxes, hButtons, hProcessTime
	global CapsArray, ButtonCapsArray, ValueCapsArray
	
	static RIM_TYPEMOUSE := 0, RIM_TYPEKEYBOARD := 1, RIM_TYPEHID := 2
	static cbSizeHeader := 8 + (A_PtrSize * 2)
	static StructRAWINPUT,init:= VarSetCapacity(StructRAWINPUT, 10240)
	static bRawDataOffset := (8 + (A_PtrSize * 2)) + 8
	QPX(true)
	
	HID.GetRawInputData(lParam, HID.RID_INPUT, 0, pcbSize, cbSizeHeader)
	;VarSetCapacity(StructRAWINPUT, pcbSize)
	if (!ret:=HID.GetRawInputData(lParam, HID.RID_INPUT, &StructRAWINPUT, pcbSize, cbSizeHeader))
		MsgBox % HID.ErrMsg() "`n" pcbSize "`n" ret
	
	ObjRAWINPUT := {}
	ObjRAWINPUT.header := {
	(Join,
		_size: 16
		dwType: NumGet(StructRAWINPUT, 0, "Uint")
		dwSize: NumGet(StructRAWINPUT, 4, "Uint")
		hDevice: NumGet(StructRAWINPUT, 8, "Uint")
		wParam: NumGet(StructRAWINPUT, 8 + A_PtrSize, "Uint")
	)}
	b := cbSizeHeader
	if (ObjRAWINPUT.header.dwType = RIM_TYPEHID){
		ObjRAWINPUT.hid := {
		(Join,
			dwSizeHid: NumGet(StructRAWINPUT, b, "Uint")
			dwCount: NumGet(StructRAWINPUT, b + 4, "Uint")
			bRawData: NumGet(StructRAWINPUT, b + 8, "UChar")
		)}
	}

	handle := ObjRAWINPUT.header.hDevice
	if (handle = 0){
		QPX(false)
		MsgBox % "Error: handle is 0"
		return
	}
	
	if (handle != SelectedDevice){
		; Message arrived for diff handle.
		; This is to be expected, as most sticks are UsagePage/Usage 1/4.
		OutputDebug, % "Ignoring Message from " handle
		QPX(false)
		return
	}
	devtype := ObjRAWINPUT.header.dwType
	if (devtype != HID.RIM_TYPEHID){
		MsgBox % "Wrong Device Type: " devtype
		QPX(false)
		return
	}

	OutputDebug, % "Processing message from handle " handle
}

; Shorthand way of formatting something as 0x0 format Hex
FormatHex(val){
	return Format("{:#x}", val+0)
}

StaticSetCapacity(ByRef var, size){
	VarSetCapacity(var, size)
	return var
}

Esc::
GuiClose:
	ExitApp