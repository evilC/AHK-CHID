StructGetRAWINPUT(ByRef data){
	/*
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
