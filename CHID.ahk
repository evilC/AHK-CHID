/*
A base set of methods for interfacing with HID API calls

Source material
http://www.codeproject.com/Articles/185522/Using-the-Raw-Input-API-to-Process-Joystick-Input
HID Usages: http://www.freebsddiary.org/APC/usb_hid_usages.php
Lots of useful code samples: https://gitorious.org/bsnes/bsnes/source/ccfff86140a02c098732961c685e9c04994bf57b:bsnes/ruby/input/rawinput.cpp#Lundefined

ToDo:
* Remove all ByRefs.
Calling code should correctly use pointers where appropriate.
Whilst slightly more complex for the user, it will remove all ambiguity as to when and when not to use pointers.
It will also mean better compatibility with _Struct etc.

*/
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
