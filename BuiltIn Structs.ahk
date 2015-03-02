/*
RAWINPUT structure
Used in GetRawInputData calls: https://msdn.microsoft.com/en-us/library/windows/desktop/ms645596%28v=vs.85%29.aspx

typedef struct tagRAWINPUT {
  RAWINPUTHEADER header;
  union {
	RAWMOUSE    mouse;
	RAWKEYBOARD keyboard;
	RAWHID      hid;
  } data;
} RAWINPUT, *PRAWINPUT, *LPRAWINPUT;

typedef struct tagRAWINPUTHEADER {
  DWORD  dwType;
  DWORD  dwSize;
  HANDLE hDevice;
  WPARAM wParam;
} RAWINPUTHEADER, *PRAWINPUTHEADER;

typedef struct tagRAWHID {
  DWORD dwSizeHid;
  DWORD dwCount;
  BYTE  bRawData[1];
} RAWHID, *PRAWHID, *LPRAWHID;

*/
StructGetRAWINPUT(ByRef data){
	static RIM_TYPEMOUSE := 0, RIM_TYPEKEYBOARD := 1, RIM_TYPEHID := 2
	static RAWINPUT := {}
	;RAWINPUT.header.dwType := NumGet(data, 0, "Uint")
	RAWINPUT.header := {
	(Join,
		_size: 16
		dwType: NumGet(data, 0, "Uint")
		dwSize: NumGet(data, 4, "Uint")
		hDevice: NumGet(data, 8, "Uint")
		wParam: NumGet(data, 12, "Uint")
	)}
	if (RAWINPUT.header.dwType = RIM_TYPEHID){
		RAWINPUT.hid := {
		(Join,
			dwSizeHid: NumGet(data, 16, "Uint")
			dwCount: NumGet(data, 20, "Uint")
			bRawData: NumGet(data, 24, "Char")
		)}
	}
	return RAWINPUT
}

StructSetRAWINPUT(ByRef RawInput := 0, data := 0){
	VarSetCapacity(RawInput, 40)
	return RawInput
}

; ====================================================
/*
RAWINPUTDEVICE structure
Used in RegisterRawInputDevices calls: https://msdn.microsoft.com/en-us/library/windows/desktop/ms645600%28v=vs.85%29.aspx

typedef struct tagRAWINPUTDEVICE {
  USHORT usUsagePage;
  USHORT usUsage;
  DWORD  dwFlags;
  HWND   hwndTarget;
} RAWINPUTDEVICE, *PRAWINPUTDEVICE, *LPRAWINPUTDEVICE;
*/

StructSetRAWINPUTDEVICE(ByRef data, obj){
	VarSetCapacity(data, 12)
	if (ObjHasKey(obj,"usUsagePage")){
		NumPut(obj.usUsagePage, data, 0, "UShort")
	}
	if (ObjHasKey(obj,"usUsage")){
		NumPut(obj.usUsage, data, 2, "UShort")
	}
	if (ObjHasKey(obj,"dwFlags")){
		NumPut(obj.dwFlags, data, 4, "Uint")
	}
	if (ObjHasKey(obj,"hwndTarget")){
		NumPut(obj.hwndTarget, data, 8, "Uint")
	}
	return data
}

; ====================================================
/*
RAWINPUTDEVICELIST structure
Used in  GetRawInputDeviceList calls: https://msdn.microsoft.com/en-us/library/windows/desktop/ms645568(v=vs.85).aspx
typedef struct tagRAWINPUTDEVICELIST {
  HANDLE hDevice;
  DWORD  dwType;
} RAWINPUTDEVICELIST, *PRAWINPUTDEVICELIST;
*/

SizeGetRAWINPUTDEVICE(){
	return 8
}

StructGetRAWINPUTDEVICELIST(ByRef data, NumDevices){
	out := []
	Loop % NumDevices {
		b := (8 * (A_Index - 1))
		out[A_Index] := {
		(Join,
			_size: 8
			hDevice: NumGet(data, b, "Uint")
			dwType: NumGet(data, b + 4, "Uint")
		)}
	}
	return out
}

StructSetRAWINPUTDEVICELIST(ByRef arr, NumDevices){
	VarSetCapacity(arr, 8 * NumDevices)
	return arr
}

; ==================================================
StructGetRIDI_DEVICEINFO(ByRef data){
	static RIM_TYPEMOUSE := 0, RIM_TYPEKEYBOARD := 1, RIM_TYPEHID := 2
	
	out := {}
	out.cbSize := NumGet(data, 0, "Uint")
	out.dwType := NumGet(data, 4, "Uint")
	if (out.dwType = RIM_TYPEHID){
		out.hid := {
		(Join,
			dwVendorId: NumGet(data, 8, "Uint")
			dwProductId: NumGet(data, 12, "Uint")
			dwVersionNumber: NumGet(data, 16, "Uint")
			usUsagePage: NumGet(data, 20, "UShort")
			usUsage: NumGet(data, 22, "UShort")
		)}
	}
	return out
}

StructSetRIDI_DEVICEINFO(ByRef struct){
	; sizeof(RID_DEVICE_INFO) = 32
	VarSetCapacity(struct, 32)
	NumPut(32, struct, 0, "unit")
	return struct
}

; ===================================================
/*
HIDP_CAPS structure
https://msdn.microsoft.com/en-us/library/windows/hardware/ff539697(v=vs.85).aspx
Used by HidP_GetCaps: https://msdn.microsoft.com/en-us/library/windows/hardware/ff539715%28v=vs.85%29.aspx
sizeof(HIDP_CAPS) = 64

typedef struct _HIDP_CAPS {
  USAGE  Usage;
  USAGE  UsagePage;
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
} HIDP_CAPS, *PHIDP_CAPS;
*/

StructGetHIDP_CAPS(ByRef data){
	; ToDo: Why is NumberLinkCollectionNodes @ offset 44?
	out := {
	(Join,
		Usage: NumGet(data, 0, "UShort")
		UsagePage: NumGet(data, 2, "UShort")
		InputReportByteLength: NumGet(data, 4, "UShort")
		OutputReportByteLength: NumGet(data, 6, "UShort")
		FeatureReportByteLength: NumGet(data, 8, "UShort")
		Reserved: NumGet(data, 10, "UShort")
		NumberLinkCollectionNodes: NumGet(data, 44, "UShort")
		NumberInputButtonCaps: NumGet(data, 46, "UShort")
		NumberInputValueCaps: NumGet(data, 48, "UShort")
		NumberInputDataIndices: NumGet(data, 50, "UShort")
		NumberOutputButtonCaps: NumGet(data, 52, "UShort")
		NumberOutputDataIndices: NumGet(data, 54, "UShort")
		NumberFeatureButtonCaps: NumGet(data, 56, "UShort")
		NumberFeatureDataIndices: NumGet(data, 58, "UShort")
	)}
	return out
}

StructSetHIDP_CAPS(ByRef data){
	VarSetCapacity(data, 64)
	return data
}