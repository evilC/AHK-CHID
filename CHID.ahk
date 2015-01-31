/*
All sizeof() comments are 32-bit sizes.
A_PtrSize for x86 is 4, so divide all sizeof() results by 4, feed result into ps()
*/

; DEPENDENCIES:
; _Struct():  https://raw.githubusercontent.com/HotKeyIt/_Struct/master/_Struct.ahk - docs: http://www.autohotkey.net/~HotKeyIt/AutoHotkey/_Struct.htm
; sizeof(): https://raw.githubusercontent.com/HotKeyIt/_Struct/master/sizeof.ahk - docs: http://www.autohotkey.net/~HotKeyIt/AutoHotkey/sizeof.htm
#Include <_Struct>

; ==================================================================================================================================================================================================
; TEST CODE
#singleinstance force
;#Include <CHID>

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
; ==================================================================================================================================================================================================


Class _CHID {
	; Constants pulled from header files
    static RIDI_DEVICENAME := 0x20000007, RIDI_DEVICEINFO := 0x2000000b, RIDI_PREPARSEDDATA := 0x20000005
	
	; Proprietatary Constants
    static RIM_TYPE := {0: "Mouse", 1: "Keyboard", 2: "Other"}

	; Structures
	static STRUCT_RAWINPUTDEVICELIST := "
	(
		HANDLE Device;//12345
		DWORD Type;//123456789012345678901234
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
			struct {_CHID.STRUCT_RID_DEVICE_INFO_MOUSE mouse};
			struct {_CHID.STRUCT_RID_DEVICE_INFO_KEYBOARD keyboard};
			struct {_CHID.STRUCT_RID_DEVICE_INFO_HID hid};
		}
	)"

	__Get(aParam){
		if (aParam = "DeviceList"){
			return new this._CDeviceList(this)
		}
	}
	
	; A class to wrap GetRawInputDeviceList calls.
	; Properties:
	; NumDevices			- The number of devices.
	; [n] (Indexed Array)	- The RAWINPUTDEVICELIST structure for device n
	Class _CDeviceList {
		__New(root){
			; Store link to main class containing DLL call funcs
			this._root := root
			
		}
		
		_Call(aTarget, aName, aParams*){
			msgbox HERE
		}
		
		__Get(aParam){
			if (aParam = "NumDevices"){
				; Querying number of devices
				this.NumDevices := this._root.GetRawInputDeviceList()
				return this.NumDevices
			} else if (aParam = "Device"){
				;if (!ObjHasKey(this, "_RAWINPUTDEVICELIST")){
					this._root.GetRawInputDeviceList(RAWINPUTDEVICELIST, this.NumDevices)
					this.Device := RAWINPUTDEVICELIST
					; DO NOT return a value!
					;return this.Device
				;}
			}
		}
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

		struct tagRAWINPUTDEVICELIST {
		  HANDLE hDevice;
		  DWORD  dwType;
		} RAWINPUTDEVICELIST, *PRAWINPUTDEVICELIST;

		sizeof(RAWINPUTDEVICELIST) = 8
		
		RETURNS: An array of puiNumDevices STRUCTS:
		typedef struct tagRAWINPUTDEVICELIST {
		  HANDLE hDevice;											// A handle to the raw input device.
		  DWORD  dwType;											// The type of device. This can be one of the following values
																	// RIM_TYPEHID 			2 - The device is an HID that is not a keyboard and not a mouse
																	// RIM_TYPEKEYBOARD 	1 - The device is a keyboard.
																	// RIM_TYPEMOUSE 		0 - The device is a mouse.
		} RAWINPUTDEVICELIST, *PRAWINPUTDEVICELIST;		
		*/
		; Perform the call
		if IsByRef(RawInputDeviceList) {			; RawInputDeviceList contains a struct, not a number
			; Params passed - pull the device list.
			RawInputDeviceList := new _Struct("_CHID.STRUCT_RAWINPUTDEVICELIST[" NumDevices "]")
			r := DllCall("GetRawInputDeviceList", "Ptr", RawInputDeviceList[], "UInt*", NumDevices, "UInt", sizeof(_CHID.STRUCT_RAWINPUTDEVICELIST) )
		} else {
			; No Struct passed in, fill NumDevices with number of devices
			r := DllCall("GetRawInputDeviceList", "Ptr", 0, "UInt*", NumDevices, "UInt", sizeof(_CHID.STRUCT_RAWINPUTDEVICELIST) )
		}
		
		;Check for errors
		if ((r = -1) Or ErrorLevel) {
			Return -1, ErrorLevel := "GetRawInputDeviceList call failed.`nReturn value: " r "`nErrorLevel: " ErrorLevel "`nLine: " A_LineNumber "`nLast Error: " A_LastError
		}
		Return NumDevices
	}
	
	; Not converted to _Struct yet
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
		
		typedef struct tagRID_DEVICE_INFO {
		  DWORD cbSize;
		  DWORD dwType;
		  union {
			RID_DEVICE_INFO_MOUSE    mouse;
			RID_DEVICE_INFO_KEYBOARD keyboard;
			RID_DEVICE_INFO_HID      hid;
		  };
		} RID_DEVICE_INFO, *PRID_DEVICE_INFO, *LPRID_DEVICE_INFO;
		*/
		
		if (Command = -1){
			Command := this.RIDI_DEVICEINFO
		}
		if (Command = this.RIDI_DEVICEINFO){
			if (Size) {			; RawInputDeviceList contains a struct, not a number
				Data := new _Struct("_CHID.STRUCT_RID_DEVICE_INFO")
				r := DllCall("GetRawInputDeviceInfo", "Ptr", Device, "UInt", Command, "Ptr", Data[], "UInt*", Size)
			} else {
				; No Struct passed in
				r := DllCall("GetRawInputDeviceInfo", "Ptr", Device, "UInt", Command, "Ptr", Data, "UInt*", Size)
			}
		}
		If (r = -1) Or ErrorLevel {
			ErrorLevel = GetRawInputDeviceInfo call failed.`nReturn value: %r%`nErrorLevel: %ErrorLevel%`nLine: %A_LineNumber%`nLast Error: %A_LastError%
			Return -1
		}
		
		return Size
	}
	
}
