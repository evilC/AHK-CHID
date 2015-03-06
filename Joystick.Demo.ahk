#singleinstance force
SetBatchLines -1

;OutputDebug, DBGVIEWCLEAR

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

BuildDeviceList(){
	global HID
	global SelectedDevice, DeviceList, DevData
	global hAxes, hButtons, hProcessTime
	global PreparsedData, ppSize, CapsArray, ButtonCapsArray, ValueCapsArray

	static RIM_TYPEMOUSE := 0, RIM_TYPEKEYBOARD := 1, RIM_TYPEHID := 2

	HID := new CHID()
	
	; Build Device List ===========================================================
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
			continue
		}
		handle := DeviceList[A_Index].hDevice
		
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
		;Data := DevInfo.Data
		DevData[A_Index] := Data

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
		NumPut(DevData[s].hid.usUsagePage, RAWINPUTDEVICE, 0, "UShort")
		NumPut(DevData[s].hid.usUsage, RAWINPUTDEVICE, 2, "UShort")
		Flags := 0x00000100 ; RIDEV_INPUTSINK
		NumPut(Flags, RAWINPUTDEVICE, 4, "Uint")
		NumPut(WinExist("A"), RAWINPUTDEVICE, 8, "Uint")
		r := HID.RegisterRawInputDevices(&RAWINPUTDEVICE, 1, DevSize)
		SelectedDevice := DeviceList[s].hDevice
		OnMessage(0x00FF, "InputMsg")
	}
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
		QPX(false)
		return
	}
	devtype := ObjRAWINPUT.header.dwType
	if (devtype != HID.RIM_TYPEHID){
		MsgBox % "Wrong Device Type: " devtype
		QPX(false)
		return
	}

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

Class CHID {
	; Constants pulled from header files
    static RIDI_DEVICENAME := 0x20000007, RIDI_DEVICEINFO := 0x2000000b, RIDI_PREPARSEDDATA := 0x20000005
	static RID_HEADER := 0x10000005, RID_INPUT := 0x10000003
	static RIDEV_APPKEYS := 0x00000400, RIDEV_CAPTUREMOUSE := 0x00000200, RIDEV_DEVNOTIFY := 0x00002000, RIDEV_EXCLUDE := 0x00000010, RIDEV_EXINPUTSINK := 0x00001000, RIDEV_INPUTSINK := 0x00000100, RIDEV_NOHOTKEYS := 0x00000200, RIDEV_NOLEGACY := 0x00000030, RIDEV_PAGEONLY := 0x00000020, RIDEV_REMOVE := 0x00000001
	static HIDP_STATUS_SUCCESS := 1114112, HIDP_STATUS_INVALID_PREPARSED_DATA := -1072627711, HIDP_STATUS_BUFFER_TOO_SMALL := -1072627705, HIDP_STATUS_INCOMPATIBLE_REPORT_ID := -1072627702, HIDP_STATUS_USAGE_NOT_FOUND := -1072627708, HIDP_STATUS_INVALID_REPORT_LENGTH := -1072627709, HIDP_STATUS_INVALID_REPORT_TYPE := -1072627710
	static AxisAssoc := {x:0x30, y:0x31, z:0x32, rx:0x33, ry:0x34, rz:0x35, sl1:0x36, sl2:0x37, sl3:0x38, pov1:0x39, Vx:0x40, Vy:0x41, Vz:0x42, Vbrx:0x44, Vbry:0x45, Vbrz:0x46} ; Name (eg "x", "y", "z", "sl1") to HID Descriptor
	static AxisHexToName := {0x30:"x", 0x31:"y", 0x32:"z", 0x33:"rx", 0x34:"ry", 0x35:"rz", 0x36:"sl1", 0x37:"sl2", 0x38:"sl3", 0x39:"pov", 0x40:"Vx", 0x41:"Vy", 0x42:"Vz", 0x44:"Vbrx", 0x45:"Vbry", 0x46:"Vbrz"} ; Name (eg "x", "y", "z", "sl1") to HID Descriptor
	
	; Proprietatary Constants
    static RIM_TYPE := {0: "Mouse", 1: "Keyboard", 2: "Other"}
	static RIM_TYPEMOUSE := 0, RIM_TYPEKEYBOARD := 1, RIM_TYPEHID := 2

	__New(){
		; ToDo: Accelerate DLL calls in here by loading libs etc.
		;DLLCall("LoadLibrary", "Str", CheckLocations[A_Index])
	}
	
	;----------------------------------------------------------------
	; Function:     ErrMsg
	;               Get the description of the operating system error
	;               
	; Parameters:
	;               ErrNum  - Error number (default = A_LastError)
	;
	; Returns:
	;               String
	;
	ErrMsg(ErrNum=""){ 
		if ErrNum=
			ErrNum := A_LastError

		VarSetCapacity(ErrorString, 1024) ;String to hold the error-message.    
		DllCall("FormatMessage" 
			 , "UINT", 0x00001000     ;FORMAT_MESSAGE_FROM_SYSTEM: The function should search the system message-table resource(s) for the requested message. 
			 , "UINT", 0              ;A handle to the module that contains the message table to search.
			 , "UINT", ErrNum 
			 , "UINT", 0              ;Language-ID is automatically retreived 
			 , "Str",  ErrorString 
			 , "UINT", 1024           ;Buffer-Length 
			 , "str",  "")            ;An array of values that are used as insert values in the formatted message. (not used) 
		
		StringReplace, ErrorString, ErrorString, `r`n, %A_Space%, All      ;Replaces newlines by A_Space for inline-output   
		return %ErrorString% 
	}

	RegisterRawInputDevices(ByRef pRawInputDevices, uiNumDevices, cbSize := 0){
		/*
		https://msdn.microsoft.com/en-us/library/windows/desktop/ms645600%28v=vs.85%29.aspx
		Uses RAWINPUTDEVICE structure: https://msdn.microsoft.com/en-us/library/windows/desktop/ms645565(v=vs.85).aspx
		*/
		
		return DllCall("RegisterRawInputDevices", "Ptr", pRawInputDevices, "UInt", uiNumDevices, "UInt", cbSize )
	}
	
	GetRawInputDeviceList(ByRef pRawInputDeviceList := 0, ByRef puiNumDevices := 0, cbSize := 0){
		/*
		https://msdn.microsoft.com/en-us/library/windows/desktop/ms645598%28v=vs.85%29.aspx
		*/
		return DllCall("GetRawInputDeviceList", "Ptr", pRawInputDeviceList, "UInt*", puiNumDevices, "UInt", cbSize )
	}
	
	GetRawInputDeviceInfo(hDevice, uiCommand := 0, ByRef pData := 0, ByRef pcbSize := 0){
		/*
		https://msdn.microsoft.com/en-us/library/windows/desktop/ms645597%28v=vs.85%29.aspx
		Uses RID_DEVICE_INFO structure: https://msdn.microsoft.com/en-us/library/windows/desktop/ms645581%28v=vs.85%29.aspx
		*/
		return DllCall("GetRawInputDeviceInfo", "Ptr", hDevice, "UInt", uiCommand, "Ptr", pData, "UInt*", pcbSize)
		*/
	}
	
	GetRawInputData(ByRef hRawInput, uiCommand := -1, ByRef pData := 0, ByRef pcbSize := 0, cbSizeHeader := 0){
		/*
		https://msdn.microsoft.com/en-us/library/windows/desktop/ms645596%28v=vs.85%29.aspx
		Uses RAWINPUT structure: https://msdn.microsoft.com/en-us/library/windows/desktop/ms645562(v=vs.85).aspx
		*/
		return DllCall("GetRawInputData", "Uint", hRawInput, "UInt", uiCommand, "Ptr", pData, "UInt*", pcbSize, "Uint", cbSizeHeader)
	}
	
	HidP_GetCaps(ByRef PreparsedData, ByRef Capabilities){
		/*
		https://msdn.microsoft.com/en-us/library/windows/hardware/ff539715%28v=vs.85%29.aspx
		returns HIDP_STATUS_ value, eg HIDP_STATUS_SUCCESS
		Uses HIDP_CAPS structure: https://msdn.microsoft.com/en-us/library/windows/hardware/ff539697(v=vs.85).aspx
		*/
		;Capabilities := new _Struct("WinStructs.HIDP_CAPS")
		return DllCall("Hid\HidP_GetCaps", "Ptr", &PreparsedData, "Ptr", Capabilities)
	}
	
	HidP_GetButtonCaps(ReportType, ByRef ButtonCaps, ByRef ButtonCapsLength, ByRef PreparsedData){
		/*
		https://msdn.microsoft.com/en-us/library/windows/hardware/ff539707(v=vs.85).aspx
		Uses HIDP_BUTTON_CAPS structure: https://msdn.microsoft.com/en-gb/library/windows/hardware/ff539693(v=vs.85).aspx
		*/
		return DllCall("Hid\HidP_GetButtonCaps", "UInt", ReportType, "Ptr", ButtonCaps, "UShort*", ButtonCapsLength, "Ptr", &PreparsedData)
	}
	
	HidP_GetValueCaps(ReportType, ByRef ValueCaps, ByRef ValueCapsLength, ByRef PreparsedData){
		/*
		https://msdn.microsoft.com/en-us/library/windows/hardware/ff539754%28v=vs.85%29.aspx
		Uses HIDP_VALUE_CAPS structure: https://msdn.microsoft.com/en-us/library/windows/hardware/ff539832(v=vs.85).aspx
		*/
		return DllCall("Hid\HidP_GetValueCaps", "UInt", ReportType, "Ptr", ValueCaps, "UShort*", ValueCapsLength, "Ptr", &PreparsedData)
	}
	
	HidP_GetUsages(ReportType, UsagePage, LinkCollection, ByRef UsageList, ByRef UsageLength, ByRef PreparsedData, ByRef Report, ReportLength){
		/*
		https://msdn.microsoft.com/en-us/library/windows/hardware/ff539742%28v=vs.85%29.aspx
		*/
		
		return DllCall("Hid\HidP_GetUsages", "uint", ReportType, "ushort", UsagePage, "ushort", LinkCollection, "Ptr", UsageList, "Uint*", UsageLength, "Ptr", &PreparsedData, "Ptr", Report, "Uint", ReportLength)
	}
	
	HidP_GetUsageValue(ReportType, UsagePage, LinkCollection, Usage, ByRef UsageValue, ByRef PreparsedData, ByRef Report, ReportLength){
		/*
		https://msdn.microsoft.com/en-us/library/windows/hardware/ff539748%28v=vs.85%29.aspx
		*/
		
		return DllCall("Hid\HidP_GetUsageValue", "uint", ReportType, "ushort", UsagePage, "ushort", LinkCollection, "ushort", Usage, "Ptr", &UsageValue, "Ptr", &PreparsedData, "Ptr", Report, "Uint", ReportLength)
	}
}

QPX( N=0 ) { ; Wrapper for QueryPerformanceCounter()by SKAN | CD: 06/Dec/2009
	Static F,A,Q,P,X ; www.autohotkey.com/forum/viewtopic.php?t=52083 | LM: 10/Dec/2009
	If	( N && !P )
		Return	DllCall("QueryPerformanceFrequency",Int64P,F) + (X:=A:=0) + DllCall("QueryPerformanceCounter",Int64P,P)
	DllCall("QueryPerformanceCounter",Int64P,Q), A:=A+Q-P, P:=Q, X:=X+1
	Return	( N && X=N ) ? (X:=X-1)<<64 : ( N=0 && (R:=A/X/F) ) ? ( R + (A:=P:=X:=0) ) : 1
}