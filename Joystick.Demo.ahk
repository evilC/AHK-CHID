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

OutputDebug, DBGVIEWCLEAR

GUI_WIDTH := 701

Gui +Resize -MaximizeBox -MinimizeBox
Gui, Add, Text, % "xm Center w" GUI_WIDTH, % "Select a Joystick to subscribe to WM_INPUT messages for that stick."
Gui, Add, Listview, % "w" GUI_WIDTH " h200 vlvDL gSelectDevice AltSubmit +Grid",#|Name|Btns|Axes|POVs|VID|PID|UsPage|Usage|handle
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

	;HID := new CHID()
	HID := new CHIDHelper()
	
	SelectvJoyDevice()
	;DeviceList := new HID.RAWINPUTDEVICELIST()
	;NumDevices := DeviceList.NumDevices
	HID.GetRawInputDeviceList(0, NumDevices, sizeof(WinStructs.RAWINPUTDEVICELIST))
	DeviceList := new _Struct("WinStructs.RAWINPUTDEVICELIST[" NumDevices "]")
	HID.GetRawInputDeviceList(DeviceList[], NumDevices, sizeof(WinStructs.RAWINPUTDEVICELIST))
	DeviceList.NumDevices := NumDevices

	HID.GetRawInputDeviceInfo(DeviceList[1].hDevice, HID.RIDI_DEVICEINFO, 0, DevSize)

	
	; Build Device List ===========================================================
	/*
	DeviceSize := 2 * A_PtrSize ; sizeof(RAWINPUTDEVICELIST)
	HID.GetRawInputDeviceList(0, NumDevices, DeviceSize)
	DeviceList := []
	VarSetCapacity(Data, DeviceSize * NumDevices)
	HID.GetRawInputDeviceList(&Data, NumDevices, DeviceSize)
	Loop % NumDevices {
		b := (DeviceSize * (A_Index - 1))
		DeviceList[A_Index] := {
		(Join,
			_size: DeviceSize
			hDevice: NumGet(data, b, "Uint")
			dwType: NumGet(data, b + A_PtrSize, "Uint")
		)}
	}
	*/
	AxisNames := ["X","Y","Z","RX","RY","RZ","SL0","SL1"]
	DevData := []
	SelectedDevice := 0
	; Store data that does not change for WM_INPUT calls
	CapsArray := {}
	ButtonCapsArray := {}
	ValueCapsArray := {}

	Gui,ListView,lvDL
	Loop % NumDevices {
		; Get device Handle
		if (DeviceList[A_Index].dwType != HID.RIM_TYPEHID){
			;continue
		}
		handle := DeviceList[A_Index].hDevice
		
		;DevInfo := new HID.RID_DEVICE_INFO(handle)
		
		Data := new _Struct("WinStructs.RID_DEVICE_INFO",{cbSize:Size})
		HID.GetRawInputDeviceInfo(handle, HID.RIDI_DEVICEINFO, Data[], DevSize)
		DevData[A_Index] := Data

		if (DevData[A_Index].hid.dwVendorID = ""){
			continue
		}

		/*
		; Get Device Info
		VarSetCapacity(RID_DEVICE_INFO, 32)
		NumPut(32, RID_DEVICE_INFO, 0, "unit") ; cbSize must equal sizeof(RID_DEVICE_INFO) = 32
		static DevSize := 32
		HID.GetRawInputDeviceInfo(handle, HID.RIDI_DEVICEINFO, &RID_DEVICE_INFO, DevSize)
		
		Data := {}
		Data.cbSize := NumGet(RID_DEVICE_INFO, 0, "Uint")
		Data.dwType := NumGet(RID_DEVICE_INFO, 4, "Uint")
		if (Data.dwType = RIM_TYPEHID){
			Data.hid := {
			(Join,
				dwVendorId: NumGet(RID_DEVICE_INFO, 8, "Uint")
				dwProductId: NumGet(RID_DEVICE_INFO, 12, "Uint")
				dwVersionNumber: NumGet(RID_DEVICE_INFO, 16, "Uint")
				usUsagePage: NumGet(RID_DEVICE_INFO, 20, "UShort")
				usUsage: NumGet(RID_DEVICE_INFO, 22, "UShort")
			)}
		}
		*/
		;Data := DevInfo.Data
		;DevData[A_Index] := DevInfo.Data

		OutputDebug, % "Getting Device Info for " DevData[A_Index].hid.dwVendorID
		
		if (DevData[A_Index].dwType != HID.RIM_TYPEHID){
			; ToDo: Why can a DeviceList object be type HID, but the DeviceInfo type be something else?
			;continue
		}
		
		
		; Find Human name from registry
		VID := Format("{:04x}", DevData[A_Index].hid.dwVendorID)
		StringUpper,VID, VID
		PID := Format("{:04x}", DevData[A_Index].hid.dwProductID)
		StringUpper,PID, PID
		if (DevData[A_Index].hid.dwVendorID = 0x45E && DevData[A_Index].hid.dwProductID = 0x28E){
			; Dirty hack for now, cannot seem to read "SYSTEM\CurrentControlSet\Control\MediaProperties\PrivateProperties\Joystick\OEM\VID_045E&PID_028E"
			human_name := "XBOX 360 Controller"
		} else {
			key := "SYSTEM\CurrentControlSet\Control\MediaProperties\PrivateProperties\Joystick\OEM\VID_" VID "&PID_" PID
			RegRead, human_name, HKLM, % key, OEMName
		}
		
		
		; Decode capabilities
		HID.GetRawInputDeviceInfo(handle, HID.RIDI_PREPARSEDDATA, 0, ppSize)
		VarSetCapacity(PreparsedData, ppSize)
		ret := HID.GetRawInputDeviceInfo(handle, HID.RIDI_PREPARSEDDATA, &PreparsedData, ppSize)
		
		VarSetCapacity(Cap, 64)
		HID.HidP_GetCaps(PreparsedData, &Cap)

		CapsArray[handle] := {
		(Join,
			Usage: NumGet(Cap, 0, "UShort")
			UsagePage: NumGet(Cap, 2, "UShort")
			InputReportByteLength: NumGet(Cap, 4, "UShort")
			OutputReportByteLength: NumGet(Cap, 6, "UShort")
			FeatureReportByteLength: NumGet(Cap, 8, "UShort")
			Reserved: NumGet(Cap, 10, "UShort")
			NumberLinkCollectionNodes: NumGet(Cap, 44, "UShort")
			NumberInputButtonCaps: NumGet(Cap, 46, "UShort")
			NumberInputValueCaps: NumGet(Cap, 48, "UShort")
			NumberInputDataIndices: NumGet(Cap, 50, "UShort")
			NumberOutputButtonCaps: NumGet(Cap, 52, "UShort")
			NumberOutputDataIndices: NumGet(Cap, 54, "UShort")
			NumberFeatureButtonCaps: NumGet(Cap, 56, "UShort")
			NumberFeatureDataIndices: NumGet(Cap, 58, "UShort")
		)}
		
		Axes := ""
		Hats := 0
		btns := 0

		; Buttons
		if (CapsArray[handle].NumberInputButtonCaps) {
			
			VarSetCapacity(ButtonCaps, (72 * CapsArray[handle].NumberInputButtonCaps))
			HID.HidP_GetButtonCaps(0, &ButtonCaps, CapsArray[handle].NumberInputButtonCaps, PreparsedData)
			ButtonCapsArray[handle] := []
			Loop % CapsArray[handle].NumberInputButtonCaps {
				b := (A_Index -1) * 72
				ButtonCapsArray[handle][A_Index] := {
				(Join,
					UsagePage: NumGet(ButtonCaps, b + 0, "UShort")
					ReportID: NumGet(ButtonCaps, b + 2, "UChar")
					IsAlias: NumGet(ButtonCaps, b + 3, "UChar")
					BitField: NumGet(ButtonCaps, b + 4, "UShort")
					LinkCollection: NumGet(ButtonCaps, b + 6, "UShort")
					LinkUsage: NumGet(ButtonCaps, b + 8, "UShort")
					LinkUsagePage: NumGet(ButtonCaps, b + 10, "UShort")
					IsRange: NumGet(ButtonCaps, b + 12, "UChar")
					IsStringRange: NumGet(ButtonCaps, b + 13, "UChar")
					IsDesignatorRange: NumGet(ButtonCaps, b + 14, "UChar")
					IsAbsolute: NumGet(ButtonCaps, b + 15, "UChar")
					Reserved: NumGet(ButtonCaps, b + 16, "Uint")
				)}
				if (ButtonCapsArray[handle][A_Index].IsRange){
					ButtonCapsArray[handle][A_Index].Range := {
					(Join,
						UsageMin: NumGet(ButtonCaps, b + 56, "UShort")
						UsageMax: NumGet(ButtonCaps, b + 58, "UShort")
						StringMin: NumGet(ButtonCaps, b + 60, "UShort")
						StringMax: NumGet(ButtonCaps, b + 62, "UShort")
						DesignatorMin: NumGet(ButtonCaps, b + 64, "UShort")
						DesignatorMax: NumGet(ButtonCaps, b + 66, "UShort")
						DataIndexMin: NumGet(ButtonCaps, b + 68, "UShort")
						DataIndexMax: NumGet(ButtonCaps, b + 70, "UShort")
					)}
					
				} else {
					ButtonCapsArray[handle][A_Index].NotRange := {
					(Join,
						Usage: NumGet(ButtonCaps, 56, "UShort")
						Reserved1: NumGet(ButtonCaps, 58, "UShort")
						StringIndex: NumGet(ButtonCaps, 60, "UShort")
						Reserved2: NumGet(ButtonCaps, 62, "UShort")
						DesignatorIndex: NumGet(ButtonCaps, 64, "UShort")
						Reserved3: NumGet(ButtonCaps, 66, "UShort")
						DataIndex: NumGet(ButtonCaps, 68, "UShort")
						Reserved4: NumGet(ButtonCaps, 70, "UShort")
					)}
				}
			}
			
			btns := (Range:=ButtonCapsArray[handle].1.Range).UsageMax - Range.UsageMin + 1
		}
		; Axes / Hats
		if (CapsArray[handle].NumberInputValueCaps) {
			;ValueCaps := StructSetHIDP_VALUE_CAPS(ValueCaps, CapsArray[handle].NumberInputValueCaps)
			VarSetCapacity(ValueCaps, (72 * CapsArray[handle].NumberInputValueCaps))
			HID.HidP_GetValueCaps(0, &ValueCaps, CapsArray[handle].NumberInputValueCaps, PreparsedData)
			
			;ValueCapsArray[handle] := StructGetHIDP_VALUE_CAPS(ValueCaps, CapsArray[handle].NumberInputValueCaps)
			ValueCapsArray[handle] := []
			Loop % CapsArray[handle].NumberInputValueCaps {
				b := (A_Index -1) * 72
				ValueCapsArray[handle][A_Index] := {
				(Join,
					UsagePage: NumGet(ValueCaps, b + 0, "UShort")
					ReportID: NumGet(ValueCaps, b + 2, "UChar")
					IsAlias: NumGet(ValueCaps, b + 3, "UChar")
					BitField: NumGet(ValueCaps, b + 4, "UShort")
					LinkCollection: NumGet(ValueCaps, b + 6, "UShort")
					LinkUsage: NumGet(ValueCaps, b + 8, "UShort")
					LinkUsagePage: NumGet(ValueCaps, b + 10, "UShort")
					IsRange: NumGet(ValueCaps, b + 12, "UChar")
					IsStringRange: NumGet(ValueCaps, b + 13, "UChar")
					IsDesignatorRange: NumGet(ValueCaps, b + 14, "UChar")
					IsAbsolute: NumGet(ValueCaps, b + 15, "UChar")
					HasNull: NumGet(ValueCaps, b + 16, "UChar")
					Reserved: NumGet(ValueCaps, b + 17, "UChar")
					BitSize: NumGet(ValueCaps, b + 18, "UShort")
					ReportCount: NumGet(ValueCaps, b + 20, "UShort")
					Reserved2: NumGet(ValueCaps, b + 22, "UShort")
					UnitsExp: NumGet(ValueCaps, b + 32, "Uint")
					Units: NumGet(ValueCaps, b + 36, "Uint")
					LogicalMin: NumGet(ValueCaps, b + 40, "int")
					LogicalMax: NumGet(ValueCaps, b + 44, "int")
					PhysicalMin: NumGet(ValueCaps, b + 48, "int")
					PhysicalMax: NumGet(ValueCaps, b + 52, "int")
				)}
				; ToDo: Why is IsRange not 1?
				;if (out[A_Index].IsRange)
					ValueCapsArray[handle][A_Index].Range := {
					(Join,
						UsageMin: NumGet(ValueCaps, b + 56, "UShort")
						UsageMax: NumGet(ValueCaps, b + 58, "UShort")
						StringMin: NumGet(ValueCaps, b + 60, "UShort")
						StringMax: NumGet(ValueCaps, b + 62, "UShort")
						DesignatorMin: NumGet(ValueCaps, b + 64, "UShort")
						DesignatorMax: NumGet(ValueCaps, b + 66, "UShort")
						DataIndexMin: NumGet(ValueCaps, b + 68, "UShort")
						DataIndexMax: NumGet(ValueCaps, b + 70, "UShort")
					)}
				/*	
				} else {
					ValueCapsArray[handle][A_Index].NotRange := {
					(Join,
						Usage: NumGet(ValueCaps, 56, "UShort")
						Reserved1: NumGet(ValueCaps, 58, "UShort")
						StringIndex: NumGet(ValueCaps, 60, "UShort")
						Reserved2: NumGet(ValueCaps, 62, "UShort")
						DesignatorIndex: NumGet(ValueCaps, 64, "UShort")
						Reserved3: NumGet(ValueCaps, 66, "UShort")
						DataIndex: NumGet(ValueCaps, 68, "UShort")
						Reserved4: NumGet(ValueCaps, 70, "UShort")
					)}
				}
				*/
			}
			
			Loop % CapsArray[handle].NumberInputValueCaps {
				Type := (Range:=ValueCapsArray[handle][A_Index].Range).UsageMin
				if (Type = 0x39){
					; Hat
					Hats++
				} else if (Type >= 0x30 && Type <= 0x38) {
					; If one of the known 8 standard axes
					Type -= 0x2F
					if (Axes != ""){
						Axes .= ","
					}
					Axes .= AxisNames[Type]
				}
			}
		}
		; Update LV
		if (!btns && Axes = "" && !Hats){
			continue
		}
		if (human_name = ""){
			human_name := "Unknown"
		}
		LV_Add(,A_INDEX, human_name, btns, Axes, Hats, VID, PID, DevData[A_Index].hid.usUsagePage, DevData[A_Index].hid.usUsage, handle )
	}
}

return

; Register for WM_INPUT messages ==============================================
SelectDevice:
	SelectDevice()
	return

SelectDevice(){
	global HID, SelectedDevice, DeviceList, DevData
	
	LV_GetText(s, LV_GetNext())
	if (A_GuiEvent = "i" && s > 0){
		static DevSize := 8 + A_PtrSize
		RAWINPUTDEVICE := StaticSetCapacity(RAWINPUTDEVICE, DevSize)
		;NumPut(DevData[s].hid.usUsagePage, RAWINPUTDEVICE, 0, "UShort")
		;NumPut(DevData[s].hid.usUsage, RAWINPUTDEVICE, 2, "UShort")
		NumPut(1, RAWINPUTDEVICE, 0, "UShort")
		NumPut(4, RAWINPUTDEVICE, 2, "UShort")
		Flags := 0x00000100 ; RIDEV_INPUTSINK
		NumPut(Flags, RAWINPUTDEVICE, 4, "Uint")
		NumPut(WinExist("A"), RAWINPUTDEVICE, 8, "Uint")
		r := HID.RegisterRawInputDevices(&RAWINPUTDEVICE, 1, DevSize)
		;SelectedDevice := DeviceList[s].hDevice
		SelectedDevice := 131145
		;MsgBox % "subscribing to`nDevice: " DeviceList[s].hDevice "`nPage: " DevData[s].hid.usUsagePage "`nUsage: " DevData[s].hid.usUsage
		OnMessage(0x00FF, "InputMsg")
	}
	return
}

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
	
	;handle := DeviceList[s].hDevice
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

	;ToolTip % "L: " CapsArray[handle].InputReportByteLength
	if (ObjRAWINPUT.header.dwType = HID.RIM_TYPEHID){
		; ToDo: ppSize should be cached on CapsArray or something.
		HID.GetRawInputDeviceInfo(handle, HID.RIDI_PREPARSEDDATA, 0, ppSize)
		VarSetCapacity(PreparsedData, ppSize)
		ret := HID.GetRawInputDeviceInfo(handle, HID.RIDI_PREPARSEDDATA, &PreparsedData, ppSize)
		btnstring := "Pressed Buttons:`n`n"
		if (CapsArray[handle].NumberInputButtonCaps) {
			; ToDo: Loop through ButtonCapsArray[handle][x] - Caps.NumberInputButtonCaps might not be 1
			
			btns := (Range:=ButtonCapsArray[handle].1.Range).UsageMax - Range.UsageMin + 1
			UsageLength := btns
			
			static UsageList := StaticSetCapacity(UsageList, 512)
			;static UsageList := StaticSetCapacity(UsageList, 256)
			HID.HidP_GetUsages(0, ButtonCapsArray[handle].UsagePage, 0, &UsageList, UsageLength, PreparsedData, &StructRAWINPUT + bRawDataOffset, ObjRAWINPUT.hid.dwSizeHid)
			Loop % UsageLength {
				if (A_Index > 1){
					btnstring .= ", "
				}
				; ToDo: This should be an array of USHORTs? Why do we have to use a size of 4 per button?
				;btnstring .= NumGet(UsageList,(A_Index -1) * 2, "Ushort")
				btnstring .= NumGet(UsageList,(A_Index -1) * 4, "Ushort")
			}
		}
		
		axisstring:= "Axes:`n`n"
		; Decode Axis States
		if (CapsArray[handle].NumberInputValueCaps){
			;static value := StaticSetCapacity(value, 4)
			static value := StaticSetCapacity(value, A_PtrSize)
			Loop % CapsArray[handle].NumberInputValueCaps {
				if (ValueCapsArray[handle][A_Index].UsagePage != 1){
					; Ignore things not on the page we subscribed to.
					continue
				}
				r := HID.HidP_GetUsageValue(0, ValueCapsArray[handle][A_Index].UsagePage, 0, ValueCapsArray[handle][A_Index].Range.UsageMin, value, PreparsedData, &StructRAWINPUT + bRawDataOffset, ObjRAWINPUT.hid.dwSizeHid)
				;value := NumGet(value,0,"Short")
				value := NumGet(value,0,"Uint")
				axisstring .= HID.AxisHexToName[ValueCapsArray[handle][A_Index].Range.UsageMin] " axis: " value "`n"
			}
		}
		Ti := QPX(false)
		GuiControl,,% hButtons, % btnstring
		GuiControl,,% hAxes, % axisstring
		GuiControl,,% hProcessTime, % Ti
	}

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