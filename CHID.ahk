; DEPENDENCIES:
; _Struct():  https://raw.githubusercontent.com/HotKeyIt/_Struct/master/_Struct.ahk - docs: http://www.autohotkey.net/~HotKeyIt/AutoHotkey/_Struct.htm
; sizeof(): https://raw.githubusercontent.com/HotKeyIt/_Struct/master/sizeof.ahk - docs: http://www.autohotkey.net/~HotKeyIt/AutoHotkey/sizeof.htm
#Include <_Struct>

; A base set of methods for interfacing with HID API calls using _Structs
Class CHID {
	; Constants pulled from header files
    static RIDI_DEVICENAME := 0x20000007, RIDI_DEVICEINFO := 0x2000000b, RIDI_PREPARSEDDATA := 0x20000005
	
	; Proprietatary Constants
    static RIM_TYPE := {0: "Mouse", 1: "Keyboard", 2: "Other"}

	; Structures
	static STRUCT_RAWINPUTDEVICELIST := "
	(
		HANDLE Device;	// A handle to the raw input device.
		DWORD Type;		// The type of device. This can be one of the following values
						// RIM_TYPEHID 			2 - The device is an HID that is not a keyboard and not a mouse
						// RIM_TYPEKEYBOARD 	1 - The device is a keyboard.
						// RIM_TYPEMOUSE 		0 - The device is a mouse.
	)"

	static STRUCT_RID_DEVICE_INFO_MOUSE := "
	(
		DWORD Id;
		DWORD NumberOfButtons;
		DWORD SampleRate;
		BOOL HasHorizontalWheel;
	)"
	
	static STRUCT_RID_DEVICE_INFO_KEYBOARD := "
	(
		DWORD Type;
		DWORD SubType;
		DWORD KeyboardMode;
		DWORD NumberOfFunctionKeys;
		DWORD NumberOfIndicators;
		DWORD NumberOfKeysTotal;
	)"
	
	static STRUCT_RID_DEVICE_INFO_HID := "
	(
		DWORD VendorId;
		DWORD ProductId;
		DWORD VersionNumber;
		USHORT UsagePage;
		USHORT Usage;
	)"

	static STRUCT_RID_DEVICE_INFO := "
	(
		DWORD Size;
		DWORD Type;
		{
			CHID.STRUCT_RID_DEVICE_INFO_MOUSE mouse;
			CHID.STRUCT_RID_DEVICE_INFO_KEYBOARD keyboard;
			CHID.STRUCT_RID_DEVICE_INFO_HID hid;
		}
	)"
	
	;https://msdn.microsoft.com/en-us/library/windows/hardware/ff539697(v=vs.85).aspx
	static STRUCT_HIDP_CAPS := "
	(
		USHORT Usage;
		USHORT UsagePage;
		USHORT InputReportByteLength;
		USHORT OutputReportByteLength;
		USHORT FeatureReportByteLength;
		USHORT Reserved[17];
		USHORT NumberLinkCollectionNodes;
		USHORT NumberInputButtonCaps;
		USHORT NumberInputValueCaps;
		USHORT NumberInputDataIndices;
		USHORT NumberOutputButtonCaps;
		USHORT NumberOutputValueCaps;
		USHORT NumberOutputDataIndices;
		USHORT NumberFeatureButtonCaps;
		USHORT NumberFeatureValueCaps;
		USHORT NumberFeatureDataIndices;
	)"

	__New(){
		; ToDo: Accelerate DLL calls in here by loading libs etc.
		;DLLCall("LoadLibrary", "Str", CheckLocations[A_Index])
	}

	GetRawInputDeviceList(ByRef RawInputDeviceList := 0, ByRef NumDevices := 0){
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
		*/
		; Perform the call
		if IsByRef(RawInputDeviceList) {			; RawInputDeviceList contains a struct, not a number
			; Params passed - pull the device list.
			RawInputDeviceList := new _Struct("CHID.STRUCT_RAWINPUTDEVICELIST[" NumDevices "]")
			r := DllCall("GetRawInputDeviceList", "Ptr", RawInputDeviceList[], "UInt*", NumDevices, "UInt", sizeof(CHID.STRUCT_RAWINPUTDEVICELIST) )
		} else {
			; No Struct passed in, fill NumDevices with number of devices
			r := DllCall("GetRawInputDeviceList", "Ptr", 0, "UInt*", NumDevices, "UInt", sizeof(CHID.STRUCT_RAWINPUTDEVICELIST) )
		}
		
		;Check for errors
		if ((r = -1) Or ErrorLevel) {
			Return -1, ErrorLevel := "GetRawInputDeviceList call failed.`nReturn value: " r "`nErrorLevel: " ErrorLevel "`nLine: " A_LineNumber "`nLast Error: " A_LastError
		}
		Return NumDevices
	}
	
	GetRawInputDeviceInfo(Device, Command := -1, ByRef Data := 0, ByRef Size := 0){
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
		*/
		
		if (Command = -1){
			Command := this.RIDI_DEVICEINFO
		}
		;if (Command = this.RIDI_DEVICEINFO){
			if (Size) {   ; RawInputDeviceList contains a struct, not a number
				if (Command = this.RIDI_DEVICEINFO){
					Data := new _Struct("CHID.STRUCT_RID_DEVICE_INFO",{size:Size})
					r := DllCall("GetRawInputDeviceInfo", "Ptr", Device, "UInt", Command, "Ptr", Data[], "UInt*", Size)
				} else if (Command = this.RIDI_PREPARSEDDATA){
					VarSetCapacity(Data, Size)
					r := DllCall("GetRawInputDeviceInfo", "Ptr", Device, "UInt", Command, "Ptr", Data, "UInt*", Size)
				}
			} else {
				; No Struct passed in
				r := DllCall("GetRawInputDeviceInfo", "Ptr", Device, "UInt", Command, "Ptr", Data, "UInt*", Size)
			}
		;}
		If (r = -1) Or ErrorLevel {
			ErrorLevel = GetRawInputDeviceInfo call failed.`nReturn value: %r%`nErrorLevel: %ErrorLevel%`nLine: %A_LineNumber%`nLast Error: %A_LastError%
			Return -1
		}
		
		return Size
	}
	
	HidP_GetCaps(ByRef PreparsedData, ByRef Capabilities){
		/*
		https://msdn.microsoft.com/en-us/library/windows/hardware/ff539715%28v=vs.85%29.aspx
		
		NTSTATUS __stdcall HidP_GetCaps(
		  _In_   PHIDP_PREPARSED_DATA PreparsedData,
		  _Out_  PHIDP_CAPS Capabilities
		);
		*/
		Capabilities := new _Struct("CHID.STRUCT_HIDP_CAPS")
		r := DllCall("Hid\HidP_GetCaps", "Ptr", &PreparsedData, "Ptr", Capabilities[])
		If (r = -1) Or ErrorLevel {
			ErrorLevel = HidP_GetCaps call failed.`nReturn value: %r%`nErrorLevel: %ErrorLevel%`nLine: %A_LineNumber%`nLast Error: %A_LastError%
			Return -1
		}
		return r
	}
}
