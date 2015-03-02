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
