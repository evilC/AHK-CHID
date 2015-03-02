/*
RAWINPUT structure
Used in GetRawInputData calls: https://msdn.microsoft.com/en-us/library/windows/desktop/ms645596%28v=vs.85%29.aspx
sizeof(RAWINPUTHEADER) = 16

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
			bRawData: NumGet(data, 24, "UChar")
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

; ==============================
/*
HIDP_BUTTON_CAPS structure
https://msdn.microsoft.com/en-gb/library/windows/hardware/ff539693(v=vs.85).aspx
sizeof(HIDP_BUTTON_CAPS) = 72

typedef struct _HIDP_BUTTON_CAPS {
  USAGE   UsagePage;
  UCHAR   ReportID;
  BOOLEAN IsAlias;
  USHORT  BitField;
  USHORT  LinkCollection;
  USAGE   LinkUsage;
  USAGE   LinkUsagePage;
  BOOLEAN IsRange;
  BOOLEAN IsStringRange;
  BOOLEAN IsDesignatorRange;
  BOOLEAN IsAbsolute;
  ULONG   Reserved[10];
  union {
    struct {
      USAGE  UsageMin;
      USAGE  UsageMax;
      USHORT StringMin;
      USHORT StringMax;
      USHORT DesignatorMin;
      USHORT DesignatorMax;
      USHORT DataIndexMin;
      USHORT DataIndexMax;
    } Range;
    struct {
      USAGE  Usage;
      USAGE  Reserved1;
      USHORT StringIndex;
      USHORT Reserved2;
      USHORT DesignatorIndex;
      USHORT Reserved3;
      USHORT DataIndex;
      USHORT Reserved4;
    } NotRange;
  };
} HIDP_BUTTON_CAPS, *PHIDP_BUTTON_CAPS;

*/

StructSetHIDP_BUTTON_CAPS(ByRef data, NumCaps){
	VarSetCapacity(data, (72 * NumCaps))
	return data
}

StructGetHIDP_BUTTON_CAPS(ByRef data, NumCaps){
	; ToDo: Why is NumberLinkCollectionNodes @ offset 44?
	out := []
	Loop % NumCaps {
		b := (A_Index -1) * 72
		out[A_Index] := {
		(Join,
			UsagePage: NumGet(data, b + 0, "UShort")
			ReportID: NumGet(data, b + 2, "UChar")
			IsAlias: NumGet(data, b + 3, "UChar")
			BitField: NumGet(data, b + 4, "UShort")
			LinkCollection: NumGet(data, b + 6, "UShort")
			LinkUsage: NumGet(data, b + 8, "UShort")
			LinkUsagePage: NumGet(data, b + 10, "UShort")
			IsRange: NumGet(data, b + 12, "UChar")
			IsStringRange: NumGet(data, b + 13, "UChar")
			IsDesignatorRange: NumGet(data, b + 14, "UChar")
			IsAbsolute: NumGet(data, b + 15, "UChar")
			Reserved: NumGet(data, b + 16, "Uint")
		)}
		if (out[A_Index].IsRange){
			out[A_Index].Range := {
			(Join,
				UsageMin: NumGet(data, b + 56, "UShort")
				UsageMax: NumGet(data, b + 58, "UShort")
				StringMin: NumGet(data, b + 60, "UShort")
				StringMax: NumGet(data, b + 62, "UShort")
				DesignatorMin: NumGet(data, b + 64, "UShort")
				DesignatorMax: NumGet(data, b + 66, "UShort")
				DataIndexMin: NumGet(data, b + 68, "UShort")
				DataIndexMax: NumGet(data, b + 70, "UShort")
			)}
			
		} else {
			out[A_Index].NotRange := {
			(Join,
				Usage: NumGet(data, 56, "UShort")
				Reserved1: NumGet(data, 58, "UShort")
				StringIndex: NumGet(data, 60, "UShort")
				Reserved2: NumGet(data, 62, "UShort")
				DesignatorIndex: NumGet(data, 64, "UShort")
				Reserved3: NumGet(data, 66, "UShort")
				DataIndex: NumGet(data, 68, "UShort")
				Reserved4: NumGet(data, 70, "UShort")
			)}
		}
	}
	return out
}

; ================================================
/*
HIDP_VALUE_CAPS structure
https://msdn.microsoft.com/en-us/library/windows/hardware/ff539832(v=vs.85).aspx
sizeof(HIDP_VALUE_CAPS) = 72

typedef struct _HIDP_VALUE_CAPS {
  USAGE   UsagePage;
  UCHAR   ReportID;
  BOOLEAN IsAlias;
  USHORT  BitField;
  USHORT  LinkCollection;
  USAGE   LinkUsage;
  USAGE   LinkUsagePage;
  BOOLEAN IsRange;
  BOOLEAN IsStringRange;
  BOOLEAN IsDesignatorRange;
  BOOLEAN IsAbsolute;
  BOOLEAN HasNull;
  UCHAR   Reserved;
  USHORT  BitSize;
  USHORT  ReportCount;
  USHORT  Reserved2[5];
  ULONG   UnitsExp;
  ULONG   Units;
  LONG    LogicalMin;
  LONG    LogicalMax;
  LONG    PhysicalMin;
  LONG    PhysicalMax;
  union {
    struct {
      USAGE  UsageMin;
      USAGE  UsageMax;
      USHORT StringMin;
      USHORT StringMax;
      USHORT DesignatorMin;
      USHORT DesignatorMax;
      USHORT DataIndexMin;
      USHORT DataIndexMax;
    } Range;
    struct {
      USAGE  Usage;
      USAGE  Reserved1;
      USHORT StringIndex;
      USHORT Reserved2;
      USHORT DesignatorIndex;
      USHORT Reserved3;
      USHORT DataIndex;
      USHORT Reserved4;
    } NotRange;
  };
} HIDP_VALUE_CAPS, *PHIDP_VALUE_CAPS;

*/

StructGetHIDP_VALUE_CAPS(ByRef data, NumCaps){
	out := []
	Loop % NumCaps {
		b := (A_Index -1) * 72
		out[A_Index] := {
		(Join,
			UsagePage: NumGet(data, b + 0, "UShort")
			ReportID: NumGet(data, b + 2, "UChar")
			IsAlias: NumGet(data, b + 3, "UChar")
			BitField: NumGet(data, b + 4, "UShort")
			LinkCollection: NumGet(data, b + 6, "UShort")
			LinkUsage: NumGet(data, b + 8, "UShort")
			LinkUsagePage: NumGet(data, b + 10, "UShort")
			IsRange: NumGet(data, b + 12, "UChar")
			IsStringRange: NumGet(data, b + 13, "UChar")
			IsDesignatorRange: NumGet(data, b + 14, "UChar")
			IsAbsolute: NumGet(data, b + 15, "UChar")
			HasNull: NumGet(data, b + 16, "UChar")
			Reserved: NumGet(data, b + 17, "UChar")
			BitSize: NumGet(data, b + 18, "UShort")
			ReportCount: NumGet(data, b + 20, "UShort")
			Reserved2: NumGet(data, b + 22, "UShort")
			UnitsExp: NumGet(data, b + 32, "Uint")
			Units: NumGet(data, b + 36, "Uint")
			LogicalMin: NumGet(data, b + 40, "int")
			LogicalMax: NumGet(data, b + 44, "int")
			PhysicalMin: NumGet(data, b + 48, "int")
			PhysicalMax: NumGet(data, b + 52, "int")
		)}
		; ToDo: Why is IsRange not 1?
		;if (out[A_Index].IsRange)
			out[A_Index].Range := {
			(Join,
				UsageMin: NumGet(data, b + 56, "UShort")
				UsageMax: NumGet(data, b + 58, "UShort")
				StringMin: NumGet(data, b + 60, "UShort")
				StringMax: NumGet(data, b + 62, "UShort")
				DesignatorMin: NumGet(data, b + 64, "UShort")
				DesignatorMax: NumGet(data, b + 66, "UShort")
				DataIndexMin: NumGet(data, b + 68, "UShort")
				DataIndexMax: NumGet(data, b + 70, "UShort")
			)}
		/*	
		} else {
			out[A_Index].NotRange := {
			(Join,
				Usage: NumGet(data, 56, "UShort")
				Reserved1: NumGet(data, 58, "UShort")
				StringIndex: NumGet(data, 60, "UShort")
				Reserved2: NumGet(data, 62, "UShort")
				DesignatorIndex: NumGet(data, 64, "UShort")
				Reserved3: NumGet(data, 66, "UShort")
				DataIndex: NumGet(data, 68, "UShort")
				Reserved4: NumGet(data, 70, "UShort")
			)}
		}
		*/
	}
	return out
}

StructSetHIDP_VALUE_CAPS(ByRef data, NumCaps){
	VarSetCapacity(data, (72 * NumCaps))
	return data
}
