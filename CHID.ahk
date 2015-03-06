; REQUIRES FUCNTION BINDING AHK TEST BUILD >= v1.1.19.03-37+gd7b054a from HERE: http://ahkscript.org/boards/viewtopic.php?f=24&t=5802
/*
A base set of methods for interfacing with HID API calls

Source material
http://www.codeproject.com/Articles/185522/Using-the-Raw-Input-API-to-Process-Joystick-Input
HID Usages: http://www.freebsddiary.org/APC/usb_hid_usages.php
Lots of useful code samples: https://gitorious.org/bsnes/bsnes/source/ccfff86140a02c098732961c685e9c04994bf57b:bsnes/ruby/input/rawinput.cpp#Lundefined

ToDo:
* Remove superfluous ByRefs.
* Remove DLL wrappers? AHK-H would negate need for wrappers...
* Implement RIDI_DEVICENAME in GetRawInputDeviceInfo to get unique, persistent name
*/
#singleinstance force
SetBatchLines -1
OutputDebug, DBGVIEWCLEAR

jt := new JoystickTester()
return

class JoystickTester extends CHID {
	GUI_WIDTH := 651
	
	__New(){
		base.__New()
		Gui, Add, Text, % "xm Center w" this.GUI_WIDTH, % "Select a Joystick to subscribe to WM_INPUT messages for that UsagePage/Usage."
		Gui, Add, Listview, % "hwndhLV w" this.GUI_WIDTH " h150 +AltSubmit +Grid",Handle|Name|Btns|Axes|POVs|VID|PID|UsPage|Usage
		this.hLV := hLV
		LV_Modifycol(1,80)
		LV_Modifycol(2,130)
		LV_Modifycol(3,40)
		LV_Modifycol(4,140)
		LV_Modifycol(5,50)
		LV_Modifycol(6,50)
		LV_Modifycol(7,50)
		LV_Modifycol(8,50)
		LV_Modifycol(9,50)
		
		Gui, Add, Edit, % "hwndhButtons w" this.GUI_WIDTH / 2 " h200"
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
			LV_Add(, handle, device.HumanName, device.NumButtons, device.AxisString, device.NumPOVs, device.VID, device.PID, device.UsagePage, device.Usage )
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
	
	; The selected device changed
	DeviceChanged(device){
		GuiControl, , % this.hButtons, % device.btnstring
		GuiControl, , % this.hProcessTime, % device._ProcessTime
	}
}

Esc::
GuiClose:
	ExitApp

class CHID {
	static RIM_TYPEMOUSE := 0, RIM_TYPEKEYBOARD := 1, RIM_TYPEHID := 2
    static RIDI_DEVICENAME := 0x20000007, RIDI_DEVICEINFO := 0x2000000b, RIDI_PREPARSEDDATA := 0x20000005
	static RID_HEADER := 0x10000005, RID_INPUT := 0x10000003
	static RIDEV_APPKEYS := 0x00000400, RIDEV_CAPTUREMOUSE := 0x00000200, RIDEV_DEVNOTIFY := 0x00002000, RIDEV_EXCLUDE := 0x00000010, RIDEV_EXINPUTSINK := 0x00001000, RIDEV_INPUTSINK := 0x00000100, RIDEV_NOHOTKEYS := 0x00000200, RIDEV_NOLEGACY := 0x00000030, RIDEV_PAGEONLY := 0x00000020, RIDEV_REMOVE := 0x00000001
	static HIDP_STATUS_SUCCESS := 1114112, HIDP_STATUS_BUFFER_TOO_SMALL := -1072627705, HIDP_STATUS_INCOMPATIBLE_REPORT_ID := -1072627702, HIDP_STATUS_USAGE_NOT_FOUND := -1072627708, HIDP_STATUS_INVALID_REPORT_LENGTH := -1072627709, HIDP_STATUS_INVALID_REPORT_TYPE := -1072627710, HIDP_STATUS_INVALID_PREPARSED_DATA := -1072627711
	static AxisAssoc := {x:0x30, y:0x31, z:0x32, rx:0x33, ry:0x34, rz:0x35, sl1:0x36, sl2:0x37, sl3:0x38, pov1:0x39, Vx:0x40, Vy:0x41, Vz:0x42, Vbrx:0x44, Vbry:0x45, Vbrz:0x46} ; Name (eg "x", "y", "z", "sl1") to HID Descriptor
	static AxisHexToName := {0x30:"x", 0x31:"y", 0x32:"z", 0x33:"rx", 0x34:"ry", 0x35:"rz", 0x36:"sl1", 0x37:"sl2", 0x38:"sl3", 0x39:"pov", 0x40:"Vx", 0x41:"Vy", 0x42:"Vz", 0x44:"Vbrx", 0x45:"Vbry", 0x46:"Vbrz"} ; Name (eg "x", "y", "z", "sl1") to HID Descriptor
	
	NumDevices := 0						; The Number of current devices
	_RAWINPUTDEVICELIST := []			; Array of RAWINPUTDEVICELIST objects
	DevicesByHandle := {}				; Array of _CDevice objects, indexed by handle
	RegisteredDevices := []				; Handles of devices registered for Messages
	RegisteredUsages := []				; Indexed array of usagepages and usages that are registered
	
	__New(){
		DeviceSize := 2 * A_PtrSize ; sizeof(RAWINPUTDEVICELIST)
		DLLWrappers.GetRawInputDeviceList(0, NumDevices, DeviceSize)
		this.NumDevices := NumDevices
		this._RAWINPUTDEVICELIST := {}
		this.DevicesByHandle := {}
		VarSetCapacity(Data, DeviceSize * NumDevices)
		DLLWrappers.GetRawInputDeviceList(&Data, NumDevices, DeviceSize)
		Loop % NumDevices {
			b := (DeviceSize * (A_Index - 1))
			this._RAWINPUTDEVICELIST[A_Index] := {
			(Join,
				_size: DeviceSize
				hDevice: NumGet(data, b, "Uint")
				dwType: NumGet(data, b + A_PtrSize, "Uint")
			)}
			if (this._RAWINPUTDEVICELIST[A_Index].dwType != this.RIM_TYPEHID){
				; Only HID devices supported
				continue
			}
			this.DevicesByHandle[this._RAWINPUTDEVICELIST[A_Index].hDevice] := new this._CDevice(this, this._RAWINPUTDEVICELIST[A_Index])
			OutputDebug % "Processing Device " this._RAWINPUTDEVICELIST[A_Index].hDevice
			
		}
	}

	; Registers a single device for messages
	; Actually, it registers a UsagePage / Usage for a device, plus adds the device handle to a list so other devices on that UsagePage/Usage can be filtered out.
	RegisterDevice(device){
		static DevSize := 8 + A_PtrSize
		if (device.handle && !ObjHasKey(this.RegisteredDevices, device.handle)){
			found := 0
			Loop % this.RegisteredUsages.MaxIndex() {
				if (this.RegisteredUsages[A_Index].UsagePage = device.UsagePage && this.RegisteredUsages[A_Index].Usage = device.Usage){
					found := 1
					break
				}
			}
			
			this.RegisteredDevices.Insert(device.handle)
			
			if (found){
				; Usage Page and Usage already registered, do not need to register again.
				return
			}
			VarSetCapacity(RAWINPUTDEVICE, DevSize)
			NumPut(device.UsagePage, RAWINPUTDEVICE, 0, "UShort")
			NumPut(device.Usage, RAWINPUTDEVICE, 2, "UShort")
			Flags := 0x00000100 ; RIDEV_INPUTSINK
			NumPut(Flags, RAWINPUTDEVICE, 4, "Uint")
			NumPut(WinExist("A"), RAWINPUTDEVICE, 8, "Uint")
			r := DLLWrappers.RegisterRawInputDevices(&RAWINPUTDEVICE, 1, DevSize)
			this.RegisteredUsages.Insert({UsagePage: device.UsagePage, Usage: device.Usage})
			fn := this._MessageHandler.Bind(this)
			OnMessage(0x00FF, fn)
		}
		return
	}
	
	_MessageHandler(wParam, lParam){
		Critical
		global hAxes, hButtons, hProcessTime
		
		static RIM_TYPEMOUSE := 0, RIM_TYPEKEYBOARD := 1, RIM_TYPEHID := 2
		static cbSizeHeader := 8 + (A_PtrSize * 2)
		static StructRAWINPUT,init:= VarSetCapacity(StructRAWINPUT, 10240)
		static bRawDataOffset := (8 + (A_PtrSize * 2)) + 8
		QPX(true)
		
		; Get handle of device that message is for
		DLLWrappers.GetRawInputData(lParam, this.RID_INPUT, 0, pcbSize, cbSizeHeader)
		;VarSetCapacity(StructRAWINPUT, pcbSize)
		if (!ret:=DLLWrappers.GetRawInputData(lParam, this.RID_INPUT, &StructRAWINPUT, pcbSize, cbSizeHeader))
			MsgBox % this.ErrMsg() "`n" pcbSize "`n" ret
		
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

		if (ObjRAWINPUT.header.dwType != this.RIM_TYPEHID){
			return
		}

		handle := ObjRAWINPUT.header.hDevice
		device := this.DevicesByHandle[handle]
		
		; Check this.RegisteredDevices to see if this specific handle was registered
		Loop % this.RegisteredDevices.MaxIndex() {
			if (this.RegisteredDevices[A_Index] = handle){
				; Tell the device to get preparsed data and update
				this.DevicesByHandle[handle].GetPreparsedData(&StructRAWINPUT + bRawDataOffset, ObjRAWINPUT.hid.dwSizeHid)
				break
			}
		}
		device._ProcessTime := QPX(false)
	}
	
	class _CDevice {
		; Exposed properties
		RID_DEVICE_INFO := {}	; An object containing the data from the RIDI_DEVICEINFO GetRawInputDeviceInfo call
		VID := 0				; VID of the device, in the format it would appear in the registry
		PID := 0				; PID of the device
		UsagePage := 0			; Usage Page of the device
		Usage := 0				; Usage of the device
		NumButtons := 0			; The number of Buttons
		NumAxes := 0			; The number of axes
		AxisString := ""		; A human-readable comma-separated list of axes
		NumPOVs := 0			; The number of POV hats
		HumanName := ""			; A Human-readable name (May not be unique)
		Type := -1 				; Should be RIM_TYPEHID
		
		; private properties
		_callback := 0			; Function to be called when this device changes

		__New(parent, RAWINPUTDEVICELIST){
			static RIM_TYPEMOUSE := 0, RIM_TYPEKEYBOARD := 1, RIM_TYPEHID := 2
			static RIDI_DEVICENAME := 0x20000007, RIDI_DEVICEINFO := 0x2000000b, RIDI_PREPARSEDDATA := 0x20000005
			static DevSize := 32
			static AxisNames := ["X","Y","Z","RX","RY","RZ","SL0","SL1"]
			
			this._parent := parent
			this.handle := RAWINPUTDEVICELIST.hDevice
			this.type := RAWINPUTDEVICELIST.dwType
			
			VarSetCapacity(RID_DEVICE_INFO, 32)
			NumPut(32, RID_DEVICE_INFO, 0, "unit") ; cbSize must equal sizeof(RID_DEVICE_INFO) = 32
			r := DLLWrappers.GetRawInputDeviceInfo(this.handle, RIDI_DEVICEINFO, &RID_DEVICE_INFO, DevSize)
			if (!r){
				MsgBox % A_ThisFunc " Error in GetRawInputDeviceInfo call"
			}
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
			this.RID_DEVICE_INFO := Data
			
			VID := Format("{:04x}", Data.hid.dwVendorID)
			PID := Format("{:04x}",Data.hid.dwProductID)
			StringUpper,VID, VID
			StringUpper,PID, PID
			
			this.VID := VID
			this.PID := PID
			this.UsagePage := Data.Hid.usUsagePage
			this.Usage := Data.Hid.usUsage
			
			if (Data.hid.dwVendorID = 0x45E && Data.hid.dwProductID = 0x28E){
				; Dirty hack for now, cannot seem to read "SYSTEM\CurrentControlSet\Control\MediaProperties\PrivateProperties\Joystick\OEM\VID_045E&PID_028E"
				HumanName := "XBOX 360 Controller"
			} else {
				key := "SYSTEM\CurrentControlSet\Control\MediaProperties\PrivateProperties\Joystick\OEM\VID_" VID "&PID_" PID
				RegRead, HumanName, HKLM, % key, OEMName
				if (HumanName = ""){
					HumanName := "(Unknown Device)"
				}
			}
			this.HumanName := HumanName
			
			; Decode capabilities
			DLLWrappers.GetRawInputDeviceInfo(this.handle, RIDI_PREPARSEDDATA, 0, ppSize)
			VarSetCapacity(PreparsedData, ppSize)
			ret := DLLWrappers.GetRawInputDeviceInfo(this.handle, RIDI_PREPARSEDDATA, &PreparsedData, ppSize)
			
			VarSetCapacity(Cap, 64)
			DLLWrappers.HidP_GetCaps(PreparsedData, &Cap)

			this.HIDP_CAPS := {
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
			AxisCount := 0
			Hats := 0
			btns := 0
			
			if (this.HIDP_CAPS.NumberInputButtonCaps) {
				
				VarSetCapacity(ButtonCaps, (72 * this.HIDP_CAPS.NumberInputButtonCaps))
				DLLWrappers.HidP_GetButtonCaps(0, &ButtonCaps, this.HIDP_CAPS.NumberInputButtonCaps, PreparsedData)
				this.HIDP_BUTTON_CAPS := []
				Loop % this.HIDP_CAPS.NumberInputButtonCaps {
					b := (A_Index -1) * 72
					this.HIDP_BUTTON_CAPS[A_Index] := {
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
					if (this.HIDP_BUTTON_CAPS[A_Index].IsRange){
						this.HIDP_BUTTON_CAPS[A_Index].Range := {
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
						this.HIDP_BUTTON_CAPS[A_Index].NotRange := {
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
				btns := (Range:=this.HIDP_BUTTON_CAPS.1.Range).UsageMax - Range.UsageMin + 1
				if (btns = ""){
					btns := 0
				}
			}
			
			this.NumButtons := btns

			; Axes / Hats
			if (this.HIDP_CAPS.NumberInputValueCaps) {
				;ValueCaps := StructSetHIDP_VALUE_CAPS(ValueCaps, this.HIDP_CAPS.NumberInputValueCaps)
				VarSetCapacity(ValueCaps, (72 * this.HIDP_CAPS.NumberInputValueCaps))
				DLLWrappers.HidP_GetValueCaps(0, &ValueCaps, this.HIDP_CAPS.NumberInputValueCaps, PreparsedData)
				
				;this.HIDP_VALUE_CAPS := StructGetHIDP_VALUE_CAPS(ValueCaps, this.HIDP_CAPS.NumberInputValueCaps)
				this.HIDP_VALUE_CAPS := []
				Loop % this.HIDP_CAPS.NumberInputValueCaps {
					b := (A_Index -1) * 72
					this.HIDP_VALUE_CAPS[A_Index] := {
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
						this.HIDP_VALUE_CAPS[A_Index].Range := {
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
						this.HIDP_VALUE_CAPS[A_Index].NotRange := {
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
				
				Loop % this.HIDP_CAPS.NumberInputValueCaps {
					Type := (Range:=this.HIDP_VALUE_CAPS[A_Index].Range).UsageMin
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
						AxisCount++
					}
				}
			}
			this.NumAxes := AxisCount
			this.AxisString := Axes
			this.NumPOVs := Hats
		}
		
		RegisterCallback(func){
			this._parent.RegisterDevice(this)
			this._callback := func
		}


		; Called when this device received a WM_INPUT message
		GetPreparsedData(bRawData, dwSizeHid){
			static RIDI_DEVICENAME := 0x20000007, RIDI_DEVICEINFO := 0x2000000b, RIDI_PREPARSEDDATA := 0x20000005
	
			DLLWrappers.GetRawInputDeviceInfo(this.handle, RIDI_PREPARSEDDATA, 0, ppSize)
			VarSetCapacity(PreparsedData, ppSize)
			ret := DLLWrappers.GetRawInputDeviceInfo(this.handle, RIDI_PREPARSEDDATA, &PreparsedData, ppSize)
			btnstring := "Pressed Buttons:`n`n"
			if (this.HIDP_CAPS.NumberInputButtonCaps) {
				; ToDo: Loop through this.HIDP_BUTTON_CAPS[x] - Caps.NumberInputButtonCaps might not be 1
				
				btns := (Range:=this.HIDP_BUTTON_CAPS.1.Range).UsageMax - Range.UsageMin + 1
				UsageLength := btns
				
				VarSetCapacity(UsageList, 512)
				
				; ToDo: Why does UsagePage 0 only work? Devices are all UsagePage 1!
				UsagePage := 0
				ret := DLLWrappers.HidP_GetUsages(0, UsagePage, 0, &UsageList, UsageLength, PreparsedData, bRawData, dwSizeHid)
				;ToolTip % "ret: " ret "`nUsagePage: " this.HIDP_BUTTON_CAPS.UsagePage "`nLength Out: " UsageLength "`nLength In: " btns
				Loop % UsageLength {
					if (A_Index > 1){
						btnstring .= ", "
					}
					; ToDo: This should be an array of USHORTs? Why do we have to use a size of 4 per button?
					;btnstring .= NumGet(UsageList,(A_Index -1) * 2, "Ushort")
					btnstring .= NumGet(UsageList,(A_Index -1) * 4, "Ushort")
				}
			}
			
			this.btnstring := btnstring
			;ToolTip % btnstring
			if (this._callback != 0){
				(this._callback).(this)
			}
		}
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
}

; Just an easy way to let me copy across code for now
Class DLLWrappers {
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
		
		BOOL WINAPI RegisterRawInputDevices(
		  _In_  PCRAWINPUTDEVICE pRawInputDevices,
		  _In_  UINT uiNumDevices,
		  _In_  UINT cbSize
		);
		
		Uses RAWINPUTDEVICE structure: https://msdn.microsoft.com/en-us/library/windows/desktop/ms645565(v=vs.85).aspx
		*/
		
		return DllCall("RegisterRawInputDevices", "Ptr", pRawInputDevices, "UInt", uiNumDevices, "UInt", cbSize )
	}
	
	GetRawInputDeviceList(ByRef pRawInputDeviceList := 0, ByRef puiNumDevices := 0, cbSize := 0){
		/*
		https://msdn.microsoft.com/en-us/library/windows/desktop/ms645598%28v=vs.85%29.aspx

		UINT WINAPI GetRawInputDeviceList(
		  _Out_opt_  PRAWINPUTDEVICELIST pRawInputDeviceList,		// An array of RAWINPUTDEVICELIST structures for the devices attached to the system.
																	// If NULL, the number of devices are returned in *puiNumDevices
		  _Inout_    PUINT puiNumDevices,							// If pRawInputDeviceList is NULL, the function populates this variable with the number of devices attached to the system;
																	// otherwise, this variable specifies the number of RAWINPUTDEVICELIST structures that can be contained in the buffer to which
																	// pRawInputDeviceList points. If this value is less than the number of devices attached to the system,
																	// the function returns the actual number of devices in this variable and fails with ERROR_INSUFFICIENT_BUFFER.
		  _In_       UINT cbSize									// The size of a RAWINPUTDEVICELIST structure, in bytes
		);
		
		Uses RAWINPUTDEVICELIST structure: https://msdn.microsoft.com/en-us/library/windows/desktop/ms645568(v=vs.85).aspx
		*/
		return DllCall("GetRawInputDeviceList", "Ptr", pRawInputDeviceList, "UInt*", puiNumDevices, "UInt", cbSize )
	}
	
	GetRawInputDeviceInfo(hDevice, uiCommand := 0, ByRef pData := 0, ByRef pcbSize := 0){
		/*
		https://msdn.microsoft.com/en-us/library/windows/desktop/ms645597%28v=vs.85%29.aspx
		
		UINT WINAPI GetRawInputDeviceInfo(
		  _In_opt_     HANDLE hDevice,		// A handle to the raw input device. This comes from the lParam of the WM_INPUT message, from the hDevice member of RAWINPUTHEADER
											// or from GetRawInputDeviceList.
		  _In_         UINT uiCommand,		// Specifies what data will be returned in pData. This parameter can be one of the following values:
											// RIDI_DEVICENAME 0x20000007 -		pData points to a string that contains the device name.
											//									For this uiCommand only, the value in pcbSize is the character count (not the byte count).
											// RIDI_DEVICEINFO 0x2000000b -		pData points to an RID_DEVICE_INFO structure.
											// RIDI_PREPARSEDDATA 0x20000005 -	pData points to the previously parsed data.
		  _Inout_opt_  LPVOID pData,		// A pointer to a buffer that contains the information specified by uiCommand.
											// If uiCommand is RIDI_DEVICEINFO, set the cbSize member of RID_DEVICE_INFO to sizeof(RID_DEVICE_INFO) before calling GetRawInputDeviceInfo.
		  _Inout_      PUINT pcbSize		// The size, in bytes, of the data in pData
		);
		
		Uses RID_DEVICE_INFO structure: https://msdn.microsoft.com/en-us/library/windows/desktop/ms645581%28v=vs.85%29.aspx
		*/
		return DllCall("GetRawInputDeviceInfo", "Ptr", hDevice, "UInt", uiCommand, "Ptr", pData, "UInt*", pcbSize)
		*/
	}
	
	GetRawInputData(ByRef hRawInput, uiCommand := -1, ByRef pData := 0, ByRef pcbSize := 0, cbSizeHeader := 0){
		/*
		https://msdn.microsoft.com/en-us/library/windows/desktop/ms645596%28v=vs.85%29.aspx
		
		UINT WINAPI GetRawInputData(
		  _In_       HRAWINPUT hRawInput,
		  _In_       UINT uiCommand,
		  _Out_opt_  LPVOID pData,
		  _Inout_    PUINT pcbSize,
		  _In_       UINT cbSizeHeader
		);		
		
		Uses RAWINPUT structure: https://msdn.microsoft.com/en-us/library/windows/desktop/ms645562(v=vs.85).aspx

		*/
		return DllCall("GetRawInputData", "Uint", hRawInput, "UInt", uiCommand, "Ptr", pData, "UInt*", pcbSize, "Uint", cbSizeHeader)
	}
	
	HidP_GetCaps(ByRef PreparsedData, ByRef Capabilities){
		/*
		https://msdn.microsoft.com/en-us/library/windows/hardware/ff539715%28v=vs.85%29.aspx
		
		NTSTATUS __stdcall HidP_GetCaps(
		  _In_   PHIDP_PREPARSED_DATA PreparsedData,
		  _Out_  PHIDP_CAPS Capabilities
		);
		returns HIDP_STATUS_ value, eg HIDP_STATUS_SUCCESS
		
		Uses HIDP_CAPS structure: https://msdn.microsoft.com/en-us/library/windows/hardware/ff539697(v=vs.85).aspx

		*/
		;Capabilities := new _Struct("WinStructs.HIDP_CAPS")
		return DllCall("Hid\HidP_GetCaps", "Ptr", &PreparsedData, "Ptr", Capabilities)
	}
	
	HidP_GetButtonCaps(ReportType, ByRef ButtonCaps, ByRef ButtonCapsLength, ByRef PreparsedData){
		/*
		https://msdn.microsoft.com/en-us/library/windows/hardware/ff539707(v=vs.85).aspx
		
		NTSTATUS __stdcall HidP_GetButtonCaps(
		  _In_     HIDP_REPORT_TYPE ReportType,
		  _Out_    PHIDP_BUTTON_CAPS ButtonCaps,
		  _Inout_  PUSHORT ButtonCapsLength,
		  _In_     PHIDP_PREPARSED_DATA PreparsedData
		);
		
		Uses HIDP_BUTTON_CAPS structure: https://msdn.microsoft.com/en-gb/library/windows/hardware/ff539693(v=vs.85).aspx
		*/
		return DllCall("Hid\HidP_GetButtonCaps", "UInt", ReportType, "Ptr", ButtonCaps, "UShort*", ButtonCapsLength, "Ptr", &PreparsedData)
	}
	
	HidP_GetValueCaps(ReportType, ByRef ValueCaps, ByRef ValueCapsLength, ByRef PreparsedData){
		/*
		https://msdn.microsoft.com/en-us/library/windows/hardware/ff539754%28v=vs.85%29.aspx
		
		NTSTATUS __stdcall HidP_GetValueCaps(
		  _In_     HIDP_REPORT_TYPE ReportType,
		  _Out_    PHIDP_VALUE_CAPS ValueCaps,
		  _Inout_  PUSHORT ValueCapsLength,
		  _In_     PHIDP_PREPARSED_DATA PreparsedData
		);
		
		Uses HIDP_VALUE_CAPS structure: https://msdn.microsoft.com/en-us/library/windows/hardware/ff539832(v=vs.85).aspx
		*/
		return DllCall("Hid\HidP_GetValueCaps", "UInt", ReportType, "Ptr", ValueCaps, "UShort*", ValueCapsLength, "Ptr", &PreparsedData)
	}
	
	HidP_GetUsages(ReportType, UsagePage, LinkCollection, ByRef UsageList, ByRef UsageLength, ByRef PreparsedData, ByRef Report, ReportLength){
		/*
		https://msdn.microsoft.com/en-us/library/windows/hardware/ff539742%28v=vs.85%29.aspx
		
		NTSTATUS __stdcall HidP_GetUsages(
		  _In_     HIDP_REPORT_TYPE ReportType,
		  _In_     USAGE UsagePage,
		  _In_     USHORT LinkCollection,
		  _Out_    PUSAGE UsageList,
		  _Inout_  PULONG UsageLength,
		  _In_     PHIDP_PREPARSED_DATA PreparsedData,
		  _Out_    PCHAR Report,
		  _In_     ULONG ReportLength
		);
		*/
		
		return DllCall("Hid\HidP_GetUsages", "uint", ReportType, "ushort", UsagePage, "ushort", LinkCollection, "Ptr", UsageList, "Uint*", UsageLength, "Ptr", &PreparsedData, "Ptr", Report, "Uint", ReportLength)
	}
	
	HidP_GetUsageValue(ReportType, UsagePage, LinkCollection, Usage, ByRef UsageValue, ByRef PreparsedData, ByRef Report, ReportLength){
		/*
		https://msdn.microsoft.com/en-us/library/windows/hardware/ff539748%28v=vs.85%29.aspx
		
		NTSTATUS __stdcall HidP_GetUsageValue(
		  _In_   HIDP_REPORT_TYPE ReportType,
		  _In_   USAGE UsagePage,
		  _In_   USHORT LinkCollection,
		  _In_   USAGE Usage,
		  _Out_  PULONG UsageValue,
		  _In_   PHIDP_PREPARSED_DATA PreparsedData,
		  _In_   PCHAR Report,
		  _In_   ULONG ReportLength
		);
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