; REQUIRES FUCNTION BINDING AHK TEST BUILD >= v1.1.19.03-37+gd7b054a from HERE: http://ahkscript.org/boards/viewtopic.php?f=24&t=5802
/*
A base set of methods for interfacing with HID API calls

Source material
RawInput reference: https://msdn.microsoft.com/en-us/library/windows/desktop/ff468895(v=vs.85).aspx
HIDClass support routines: https://msdn.microsoft.com/en-us/library/windows/hardware/ff538865(v=vs.85).aspx

http://www.codeproject.com/Articles/185522/Using-the-Raw-Input-API-to-Process-Joystick-Input
HID Usages: http://www.freebsddiary.org/APC/usb_hid_usages.php
Lots of useful code samples: https://gitorious.org/bsnes/bsnes/source/ccfff86140a02c098732961c685e9c04994bf57b:bsnes/ruby/input/rawinput.cpp#Lundefined

ToDo:
* Solve why HIDP_VALUE_CAPS.IsRange is always 0. Or is that not the indicator for which union to use?
* Better way of getting human-readable name?. HidD_GetProductString?
* Get all axis values in one DLL call using HidP_GetUsageValueArray
* Get change in button states using HidP_UsageListDifference
* Calculate calibrated values? HidP_GetScaledUsageValue?
* Clean up debug / Button+Axis state class properties (eg AxisDebug)
* Improve error handling / logging.
*/

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

class CHID extends _CHID_Base {
	NumDevices := 0						; The Number of current devices
	_RAWINPUTDEVICELIST := []			; Array of RAWINPUTDEVICELIST objects
	DevicesByHandle := {}				; Array of _CDevice objects, indexed by handle
	RegisteredDevices := []				; Handles of devices registered for Messages
	RegisteredUsages := []				; Indexed array of usagepages and usages that are registered
	
	__New(){
		DeviceSize := 2 * A_PtrSize ; sizeof(RAWINPUTDEVICELIST)
		DllCall("GetRawInputDeviceList", "Ptr", 0, "UInt*", NumDevices, "UInt", DeviceSize )
		this.NumDevices := NumDevices
		this._RAWINPUTDEVICELIST := {}
		this.DevicesByHandle := {}
		VarSetCapacity(Data, DeviceSize * NumDevices)
		DllCall("GetRawInputDeviceList", "Ptr", &Data, "UInt*", NumDevices, "UInt", DeviceSize )
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
			Flags := this.RIDEV_INPUTSINK
			NumPut(Flags, RAWINPUTDEVICE, 4, "Uint")
			NumPut(WinExist("A"), RAWINPUTDEVICE, 8, "Uint")
			DllCall("RegisterRawInputDevices", "Ptr", &RAWINPUTDEVICE, "UInt", 1, "UInt", DevSize )
			this.RegisteredUsages.Insert({UsagePage: device.UsagePage, Usage: device.Usage})
			fn := this._MessageHandler.Bind(this)
			OnMessage(0x00FF, fn)
		}
		return
	}
	
	_MessageHandler(wParam, lParam){
		Critical
		global hAxes, hButtons, hProcessTime
		static cbSizeHeader := 8 + (A_PtrSize * 2)
		static StructRAWINPUT,init:= VarSetCapacity(StructRAWINPUT, 10240)
		static bRawDataOffset := (8 + (A_PtrSize * 2)) + 8
		QPX(true)
		
		; Get handle of device that message is for
		DllCall("GetRawInputData", "Uint", lParam, "UInt", this.RID_INPUT, "Ptr", 0, "UInt*", pcbSize, "Uint", cbSizeHeader)
		
		if (!ret:=DllCall("GetRawInputData", "Uint", lParam, "UInt", this.RID_INPUT, "Ptr", &StructRAWINPUT, "UInt*", pcbSize, "Uint", cbSizeHeader))
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
		if (ObjRAWINPUT.header.dwType = this.RIM_TYPEHID){
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
		
		; Fire callback for device, if registered
		if (device._callback != 0){
			(device._callback).(device)
		}

	}
	
	class _CDevice extends _CHID_Base {
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
		ppSize := 0		; Holds the size of the preparsed data, so we do not have to re-get it.

		__New(parent, RAWINPUTDEVICELIST){
			static DevSize := 32
			
			this._parent := parent
			this.handle := RAWINPUTDEVICELIST.hDevice
			this.type := RAWINPUTDEVICELIST.dwType
			
			VarSetCapacity(RID_DEVICE_INFO, 32)
			NumPut(32, RID_DEVICE_INFO, 0, "unit") ; cbSize must equal sizeof(RID_DEVICE_INFO) = 32
			r := DllCall("GetRawInputDeviceInfo", "Ptr", this.handle, "UInt", this.RIDI_DEVICEINFO, "Ptr", &RID_DEVICE_INFO, "UInt*", DevSize)
			if (!r){
				MsgBox % A_ThisFunc " Error in GetRawInputDeviceInfo call" - this.ErrMsg(r)
			}
			Data := {}
			Data.cbSize := NumGet(RID_DEVICE_INFO, 0, "Uint")
			Data.dwType := NumGet(RID_DEVICE_INFO, 4, "Uint")
			if (Data.dwType = this.RIM_TYPEHID){
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
			
			; Get the unique device name
			VarSetCapacity(dev_name, 256)
			DllCall("GetRawInputDeviceInfo", "Ptr", this.handle, "UInt", this.RIDI_DEVICENAME, "Ptr", &dev_name, "UInt*", 256)
			this.GUID := StrGet(&dev_name)
			
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
			if (this.ppSize = 0){
				; Set size of Preparsed Data once to avoid excessive DLL calls
				DllCall("GetRawInputDeviceInfo", "Ptr", this.handle, "UInt", this.RIDI_PREPARSEDDATA, "Ptr", 0, "UInt*", ppSize)
				this.ppSize := ppSize
			}
			
			VarSetCapacity(PreparsedData, this.ppSize)
			DllCall("GetRawInputDeviceInfo", "Ptr", this.handle, "UInt", this.RIDI_PREPARSEDDATA, "Ptr", &PreparsedData, "UInt*", this.ppSize)
			
			VarSetCapacity(Cap, 64)
			DllCall("Hid\HidP_GetCaps", "Ptr", &PreparsedData, "Ptr", &Cap)

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
			btn_min := 0
			mtn_max := 0
			
			if (this.HIDP_CAPS.NumberInputButtonCaps) {
				VarSetCapacity(ButtonCaps, (72 * this.HIDP_CAPS.NumberInputButtonCaps))
				DllCall("Hid\HidP_GetButtonCaps", "UInt", 0, "Ptr", &ButtonCaps, "UShort*", this.HIDP_CAPS.NumberInputButtonCaps, "Ptr", &PreparsedData)
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
						if (this.HIDP_BUTTON_CAPS[A_Index].Range.UsageMax > btn_max){
							btn_max := this.HIDP_BUTTON_CAPS[A_Index].Range.UsageMax
						}
						if (this.HIDP_BUTTON_CAPS[A_Index].Range.UsageMin > btn_min){
							btn_min := this.HIDP_BUTTON_CAPS[A_Index].Range.UsageMin
						}
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
				if (btn_max){
					btns := btn_max - btn_min + 1
				}
			}
			
			this.NumButtons := btns

			; Axes / Hats
			if (this.HIDP_CAPS.NumberInputValueCaps) {
				;ValueCaps := StructSetHIDP_VALUE_CAPS(ValueCaps, this.HIDP_CAPS.NumberInputValueCaps)
				VarSetCapacity(ValueCaps, (72 * this.HIDP_CAPS.NumberInputValueCaps))
				DllCall("Hid\HidP_GetValueCaps", "UInt", 0, "Ptr", &ValueCaps, "UShort*", this.HIDP_CAPS.NumberInputValueCaps, "Ptr", &PreparsedData)
				
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
					;if (this.HIDP_VALUE_CAPS[A_Index].IsRange)
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
						Axes .= this.AxisNames[Type]
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
			if (this.ppSize = 0){
				; Shouldn't really happen as ppSize should be set when the device initializes
				DllCall("GetRawInputDeviceInfo", "Ptr", this.handle, "UInt", this.RIDI_PREPARSEDDATA, "Ptr", 0, "UInt*", ppSize)
				this.ppSize := ppSize
			}
			VarSetCapacity(PreparsedData, this.ppSize)
			DllCall("GetRawInputDeviceInfo", "Ptr", this.handle, "UInt", this.RIDI_PREPARSEDDATA, "Ptr", &PreparsedData, "UInt*", this.ppSize)
			btnstring := "Pressed Buttons:`n`n"
			if (this.HIDP_CAPS.NumberInputButtonCaps) {
				Loop % this.HIDP_CAPS.NumberInputButtonCaps {
					btns := (Range:=this.HIDP_BUTTON_CAPS[A_Index].Range).UsageMax - Range.UsageMin + 1
					UsageLength := btns
					
					VarSetCapacity(UsageList, 256)
					
					ret := DllCall("Hid\HidP_GetUsages", "uint", 0, "ushort", this.HIDP_BUTTON_CAPS[A_Index].UsagePage, "ushort", 0, "Ptr", &UsageList, "Uint*", UsageLength, "Ptr", &PreparsedData, "Ptr", bRawData, "Uint", dwSizeHid)
					if (ret < 0){
						MsgBox % A_ThisFunc ": Error: " ret "`n`n" this.HidP_ErrMsg(ret)
					}
					Loop % UsageLength {
						if (A_Index > 1){
							btnstring .= ", "
						}
						btnstring .= NumGet(UsageList,(A_Index -1) * 2, "Ushort")
					}
				}
			}
			this.btnstring := btnstring

			axisstring:= "Axes:`n`n"
			; Decode Axis States
			if (this.HIDP_CAPS.NumberInputValueCaps){
				;static value := StaticSetCapacity(value, 4)
				VarSetCapacity(value, A_PtrSize)
				Loop % this.HIDP_CAPS.NumberInputValueCaps {
					if (this.HIDP_VALUE_CAPS[A_Index].UsagePage != 1){
						; Ignore things not on the page we subscribed to.
						continue
					}
					DllCall("Hid\HidP_GetUsageValue", "uint", 0, "ushort", this.HIDP_VALUE_CAPS[A_Index].UsagePage, "ushort", 0, "ushort", this.HIDP_VALUE_CAPS[A_Index].Range.UsageMin, "Ptr", &value, "Ptr", &PreparsedData, "Ptr", bRawData, "Uint", dwSizeHid)
					value := NumGet(value,0,"Uint")
					axisstring .= this.AxisHexToName[this.HIDP_VALUE_CAPS[A_Index].Range.UsageMin] " axis: " value "`n"

				}
				
				/*
				UsageValueByteLength := 1024
				VarSetCapacity(UsageValue, UsageValueByteLength)
				r := DllCall("Hid\HidP_GetUsageValueArray", "uint", 0, "ushort", this.HIDP_VALUE_CAPS[A_Index].UsagePage, "ushort", 0, "ushort", this.HIDP_VALUE_CAPS[A_Index].Usage, "Ptr", &UsageValue, "Ushort", UsageValueByteLength, "Ptr", &PreparsedData, "Ptr", bRawData, "Uint", dwSizeHid)
				if (r < 0){
					MsgBox % A_ThisFunc " Error: " this.HidP_ErrMsg(r)
				}
				*/
				;ToolTip % "ret: " r
			}
			this.AxisDebug := AxisString
		}
	}
	

}

class _CHID_Base {
	static RIM_TYPEMOUSE := 0, RIM_TYPEKEYBOARD := 1, RIM_TYPEHID := 2
    static RIDI_DEVICENAME := 0x20000007, RIDI_DEVICEINFO := 0x2000000b, RIDI_PREPARSEDDATA := 0x20000005
	static RID_HEADER := 0x10000005, RID_INPUT := 0x10000003
	static RIDEV_APPKEYS := 0x00000400, RIDEV_CAPTUREMOUSE := 0x00000200, RIDEV_DEVNOTIFY := 0x00002000, RIDEV_EXCLUDE := 0x00000010, RIDEV_EXINPUTSINK := 0x00001000, RIDEV_INPUTSINK := 0x00000100, RIDEV_NOHOTKEYS := 0x00000200, RIDEV_NOLEGACY := 0x00000030, RIDEV_PAGEONLY := 0x00000020, RIDEV_REMOVE := 0x00000001
	static HIDP_STATUS_SUCCESS := 1114112, HIDP_STATUS_BUFFER_TOO_SMALL := -1072627705, HIDP_STATUS_INCOMPATIBLE_REPORT_ID := -1072627702, HIDP_STATUS_USAGE_NOT_FOUND := -1072627708, HIDP_STATUS_INVALID_REPORT_LENGTH := -1072627709, HIDP_STATUS_INVALID_REPORT_TYPE := -1072627710, HIDP_STATUS_INVALID_PREPARSED_DATA := -1072627711
	static AxisAssoc := {x:0x30, y:0x31, z:0x32, rx:0x33, ry:0x34, rz:0x35, sl1:0x36, sl2:0x37, sl3:0x38, pov1:0x39, Vx:0x40, Vy:0x41, Vz:0x42, Vbrx:0x44, Vbry:0x45, Vbrz:0x46} ; Name (eg "x", "y", "z", "sl1") to HID Descriptor
	static AxisHexToName := {0x30:"x", 0x31:"y", 0x32:"z", 0x33:"rx", 0x34:"ry", 0x35:"rz", 0x36:"sl1", 0x37:"sl2", 0x38:"sl3", 0x39:"pov", 0x40:"Vx", 0x41:"Vy", 0x42:"Vz", 0x44:"Vbrx", 0x45:"Vbry", 0x46:"Vbrz"} ; Name (eg "x", "y", "z", "sl1") to HID Descriptor
	static AxisNames := ["X","Y","Z","RX","RY","RZ","SL0","SL1"]

	HidP_ErrMsg(ErrNum){
		if (ErrNum = "") {
			return "NO ERROR CODE"
		} else if (ErrNum = this.HIDP_STATUS_BUFFER_TOO_SMALL){
			return "HIDP_STATUS_BUFFER_TOO_SMALL"
		} else if (ErrNum = this.HIDP_STATUS_INCOMPATIBLE_REPORT_ID){
			return "HIDP_STATUS_INCOMPATIBLE_REPORT_ID"
		} else if (ErrNum = this.HIDP_STATUS_USAGE_NOT_FOUND){
			return "HIDP_STATUS_USAGE_NOT_FOUND"
		} else if (ErrNum = this.HIDP_STATUS_INVALID_REPORT_LENGTH){
			return "HIDP_STATUS_INVALID_REPORT_LENGTH"
		} else if (ErrNum = this.HIDP_STATUS_INVALID_REPORT_TYPE){
			return "HIDP_STATUS_INVALID_REPORT_TYPE"
		} else if (ErrNum = this.HIDP_STATUS_INVALID_PREPARSED_DATA){
			return "HIDP_STATUS_INVALID_PREPARSED_DATA"
		} else {
			return "UNKNOWN ERROR (" ErrMsg ")"
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

QPX( N=0 ) { ; Wrapper for QueryPerformanceCounter()by SKAN | CD: 06/Dec/2009
	Static F,A,Q,P,X ; www.autohotkey.com/forum/viewtopic.php?t=52083 | LM: 10/Dec/2009
	If	( N && !P )
		Return	DllCall("QueryPerformanceFrequency",Int64P,F) + (X:=A:=0) + DllCall("QueryPerformanceCounter",Int64P,P)
	DllCall("QueryPerformanceCounter",Int64P,Q), A:=A+Q-P, P:=Q, X:=X+1
	Return	( N && X=N ) ? (X:=X-1)<<64 : ( N=0 && (R:=A/X/F) ) ? ( R + (A:=P:=X:=0) ) : 1
}