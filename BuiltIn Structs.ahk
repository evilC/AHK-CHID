StructGetRAWINPUT(ByRef data){
	static RIM_TYPEMOUSE := 0, RIM_TYPEKEYBOARD := 1, RIM_TYPEHID := 2
	static RAWINPUT := {}
	;RAWINPUT.header.dwType := NumGet(data, 0, "Uint")
	RAWINPUT.header := {
	(Join,
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

StructGetRAWINPUTHeaderSize(){
	return 16 ; sizeof(RAWINPUTHEADER)
}

StructSetRAWINPUT(ByRef RawInput := 0, data := 0){
	VarSetCapacity(RawInput, 40)
	return RawInput
}
