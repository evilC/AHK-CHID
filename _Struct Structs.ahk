class CHID_StructStructs extends CHID {
	StructGetRAWINPUT(ByRef data){
		/*
		static RAWINPUT := {}
		;RAWINPUT.header.dwType := NumGet(data, 0, "Uint")
		RAWINPUT.header := {
		(Join,
			dwType: NumGet(data, 0, "Uint")
			dwSize: NumGet(data, 4, "Uint")
			hDevice: NumGet(data, 8, "Uint")
			wParam: NumGet(data, 12, "Uint")
		)}
		if (RAWINPUT.header.dwType = this.RIM_TYPEHID){
			RAWINPUT.hid := {
			(Join,
				dwSizeHid: NumGet(data, 16, "Uint")
				dwCount: NumGet(data, 20, "Uint")
				bRawData: NumGet(data, 24, "Char")
			)}
		}
		return RAWINPUT
		*/
	}
	
	StructSetRAWINPUT(ByRef RawInput, data := 0){
		/*
		if (data = 0){
			VarSetCapacity(RawInput, 40) ; sizeof(RAWINPUT)
			return 16 ; sizeof(RAWINPUTHEADER)
		}
		*/
	}
}