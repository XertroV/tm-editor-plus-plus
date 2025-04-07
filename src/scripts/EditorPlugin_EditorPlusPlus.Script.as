const string EDITORPLUGIN_EDITORPLUSPLUS_SCRIPT_TXT = """
 #RequireContext CMapEditorPlugin

 #Include "TextLib" as TL
 #Include "TimeLib" as TiL
 #Include "MathLib" as ML

Text CreateManialink() {
	declare Text MLText = _"_"_"_
		<script><!--

		Void Test() {
			log("test");
		}

		main() {
			declare Text[][] EPP_MsgQueue for Page = [];
			log("started layer main");
			declare Integer NonceTime = /*TIMENOW*/0/*TIMENOW*/;
			declare Text[][] NewEvents = /*EVENTS*/[]/*EVENTS*/;
			foreach (NewEvent in NewEvents) {
				EPP_MsgQueue.add(NewEvent);
			}
			yield;
		}
		--></script>
	_"_"_"_;
	return MLText;
}

Void SendEvent(Text _EventName, Text[] _Args) {
	LayerCustomEvent(UILayers[0], "E++_"^_EventName, _Args);
}

Void LockThumbnail(Boolean _Lock) {
	declare metadata EPP_ThumbnailLocked for Map = False;
	EPP_ThumbnailLocked = _Lock;
	SendEvent("LockedThumbnail", [""^EPP_ThumbnailLocked]);
}

Void SaveCameraState() {
	declare metadata EPP_CameraHAngle for Map = CameraHAngle;
	declare metadata EPP_CameraVAngle for Map = CameraVAngle;
	declare metadata EPP_CameraPosition for Map = CameraPosition;
	declare metadata EPP_CameraTargetPosition for Map = CameraTargetPosition;
	declare metadata EPP_CameraToTargetDistance for Map = CameraToTargetDistance;
	EPP_CameraHAngle = CameraHAngle;
	EPP_CameraVAngle = CameraVAngle;
	EPP_CameraPosition = CameraPosition;
	EPP_CameraTargetPosition = CameraTargetPosition;
	EPP_CameraToTargetDistance = CameraToTargetDistance;
}

Void LoadCameraState() {
	declare metadata EPP_CameraHAngle for Map = CameraHAngle;
	declare metadata EPP_CameraVAngle for Map = CameraVAngle;
	declare metadata EPP_CameraPosition for Map = CameraPosition;
	declare metadata EPP_CameraTargetPosition for Map = CameraTargetPosition;
	declare metadata EPP_CameraToTargetDistance for Map = CameraToTargetDistance;
	CameraHAngle = EPP_CameraHAngle;
	CameraVAngle = EPP_CameraVAngle;
	// CameraPosition = EPP_CameraPosition;
	CameraTargetPosition = EPP_CameraTargetPosition;
	CameraToTargetDistance = EPP_CameraToTargetDistance;
}

Void SendAllInfo() {
	declare metadata Integer EPP_EditorPluginLoads for Map = 0;
	declare metadata Integer EPP_PlaygroundSwitches for Map = 0;
	declare metadata Integer EPP_MappingTime for Map = 0;
	declare metadata Integer EPP_MappingTime_Testing for Map = 0;
	declare metadata Integer EPP_MappingTime_Validating for Map = 0;
	declare metadata Integer EPP_MappingTime_Mapping for Map = 0;
	declare metadata Boolean EPP_ThumbnailLocked for Map = False;
	declare metadata Boolean EPP_MetadataDisabled for Map = False;
	declare metadata Text CCT_CustomColorTables for Map = "";
	SendEvent("PluginLoads", [""^EPP_EditorPluginLoads]);
	SendEvent("PGSwitches", [""^EPP_PlaygroundSwitches]);
	SendEvent("MappingTime", [""^EPP_MappingTime, ""^EPP_MappingTime_Mapping, ""^EPP_MappingTime_Testing, ""^EPP_MappingTime_Validating]);
	SendEvent("LockedThumbnail", [""^EPP_ThumbnailLocked]);
	SendEvent("MetadataDisabled", [""^EPP_MetadataDisabled]);
	SendEvent("CustomColorTables", [""^CCT_CustomColorTables]);
}

declare Boolean ShouldBreakLoop;
declare Boolean DisableMetadata;

Void ProcessIncomingMessages() {
	declare Text[][] EPP_MsgQueue for ManialinkPage = [];
	foreach (InMsg in EPP_MsgQueue) {
		if (InMsg.count == 0) continue;
		declare MsgType = InMsg[0];
		log("E++ EditorPlugin got incoming msg of type: " ^ MsgType);
		if (MsgType == "ResyncPlease") {
			SendAllInfo();
		} else if (MsgType == "MetadataCleared") {
			ShouldBreakLoop = True;
			if (DisableMetadata) {
				declare metadata Boolean EPP_MetadataDisabled for Map = False;
				EPP_MetadataDisabled = True;
			}
		} else if (InMsg.count == 1) {
			// any msgs with args go below this; no args: above.
			log("E++ EditorPlugin: unknown bodyless message type: " ^ MsgType);
			continue;
		} else if (MsgType == "LockThumbnail") {
			LockThumbnail(InMsg[1] == "true");
		} else if (MsgType == "SetMetadataEnabled") {
			ShouldBreakLoop = True;
			DisableMetadata = InMsg.count > 1 && InMsg[1] == "false";
		} else if (MsgType == "AddValidationTime") {
			declare metadata Integer EPP_MappingTime_Validating for Map = 0;
			EPP_MappingTime_Validating += TL::ToInteger(InMsg[1]);
		} else if (MsgType == "SetCustomColorTables") {
			declare metadata Text CCT_CustomColorTables for Map = "";
			log("CCT_CustomColorTables prior: " ^ CCT_CustomColorTables);
			CCT_CustomColorTables = InMsg[1];
			log("CCT_CustomColorTables after: " ^ CCT_CustomColorTables);
			SendEvent("CustomColorTables", [""^CCT_CustomColorTables]);
		}
	}
	EPP_MsgQueue.clear();
}

Boolean EPP_GetMetadataDisabled() {
	declare metadata Boolean EPP_MetadataDisabled for Map = False;
	return EPP_MetadataDisabled;
}


Void InitializeCustomSelectionCoords() {
	// ShowCustomSelection();
	CustomSelectionCoords.clear();
	declare Integer S;
	declare Boolean Bit1 = False;
	declare Boolean Bit2 = False;
	for (X, 0, 48) {
		for (Z, 0, 48) {
			S = X + Z;
			if (Bit1) {
				CustomSelectionCoords.add(<X, 0, Z>);
			} else {
				CustomSelectionCoords.add(<X, 2, Z>);
			}
			Bit1 = !Bit1;
			if (!Bit1) Bit2 = !Bit2;
		}
		Bit1 = !Bit1;
		Bit2 = !Bit2;
	}
}

Void DeInitializeCustomSelectionCoords() {
	CustomSelectionCoords.clear();
	HideCustomSelection();
}

main() {
	ShouldBreakLoop = False;

	DisableMetadata = EPP_GetMetadataDisabled();

	LayersDefaultManialinkVersion = 3;
	ManialinkText = CreateManialink();

	if (!DisableMetadata) {
		declare metadata Text CCT_CustomColorTables for Map = "nil";
		if (CCT_CustomColorTables == "nil") {
			CCT_CustomColorTables = "";
		}
	}

	declare Boolean ResetCustomSelectionCoords = True;
	// don't initialize, can show up persistently and is annoying
	//InitializeCustomSelectionCoords();
	yield;

	// outer loop: used to re-init metadata after clear
	while (True) {
		yield;

		if (ResetCustomSelectionCoords) {
			ResetCustomSelectionCoords = False;
			DeInitializeCustomSelectionCoords();
		}

		declare Text[][] EPP_MsgQueue for ManialinkPage = [];
		ShouldBreakLoop = False;
		if (DisableMetadata) {
			log("E++ EditorPlugin: metadata disabled");
			declare metadata Boolean EPP_MetadataDisabled for Map = False;
			EPP_MetadataDisabled = True;
			while (True) {
				if (EPP_MsgQueue.count > 0) {
					ProcessIncomingMessages();
				}
				if (ShouldBreakLoop) {
					break;
				}
				yield;
			}
			continue;
		}
		// log(""^This);
		declare Boolean IsInPlayground = False;
		declare Integer LastRegularValuesUpdate = Now;
		declare metadata Boolean EPP_MetadataDisabled for Map = False;
		// ! make sure to update SendAllInfo, too
		declare metadata Integer EPP_EditorPluginLoads for Map = 0;
		declare metadata Integer EPP_PlaygroundSwitches for Map = 0;
		declare metadata Integer EPP_MappingTime for Map = 0;
		declare metadata Integer EPP_MappingTime_Testing for Map = 0;
		declare metadata Integer EPP_MappingTime_Validating for Map = 0;
		declare metadata Integer EPP_MappingTime_Mapping for Map = 0;
		declare metadata Boolean EPP_ThumbnailLocked for Map = False;
		EPP_EditorPluginLoads += 1;
		declare metadata Integer[] Race_AuthorRaceWaypointTimes for Map;
		declare Integer[] Race_Share_AuthorRaceWaypointTimes for Map;
		declare Integer Race_Share_AuthorTime for Map = -1;
		declare Ident Race_Share_AuthorGhostId for Map;

		LoadCameraState();

		log("E++: Setting AttachID on UI layer");
		UILayers[0].AttachId = "E++ Supporting Plugin";
		declare CUILayer MainLayer <=> UILayers[0];
		SendAllInfo();

		declare Integer ValidationStart = 0;
		declare Integer LastCustomSelectionSize = 0;

		while(True)
		{
			if (EPP_MsgQueue.count > 0) {
				ProcessIncomingMessages();
			}

			if (ShouldBreakLoop) {
				// ShouldBreakLoop is set in ProcessIncomingMessages
				break;
			}

			// // signal from angelscript: clear CustomSelectionCoords
			// if (CustomSelectionCoords.count == 1 && CustomSelectionCoords[0].X == -1) {
			// 	CustomSelectionCoords.clear();
			// 	LastCustomSelectionSize = 0;
			// } else if (CustomSelectionCoords.count != LastCustomSelectionSize) {
			// 	LastCustomSelectionSize = CustomSelectionCoords.count;
			// 	declare Int3[] Tmp = [];
			// 	foreach (Coord in CustomSelectionCoords) { Tmp.add(Coord); }
			// 	CustomSelectionCoords.clear();
			// 	foreach (Coord in Tmp) { CustomSelectionCoords.add(Coord); }
			// }

			// track playground in-out
			if ((IsTesting || IsValidating) != IsInPlayground) {
				IsInPlayground = IsTesting || IsValidating;
				if (IsInPlayground) {
					EPP_PlaygroundSwitches += 1;
					SendEvent("PGSwitches", [""^EPP_PlaygroundSwitches]);
				}
			}

			if (Now - LastRegularValuesUpdate > 100) {
				// save the camera state
				SaveCameraState();
				// update mapping time for map
				declare Delta = (Now - LastRegularValuesUpdate);
				EPP_MappingTime += Delta;
				if (IsTesting) {
					EPP_MappingTime_Testing += Delta;
				} else if (IsValidating) {
					// validation not trackable from editor plugins
					EPP_MappingTime_Validating += Delta;
				} else {
					EPP_MappingTime_Mapping += Delta;
				}
				SendEvent("MappingTime", [""^EPP_MappingTime, ""^EPP_MappingTime_Mapping, ""^EPP_MappingTime_Testing, ""^EPP_MappingTime_Validating]);
				LastRegularValuesUpdate = Now;
			}

			yield;
		}
	}
}
""".Replace('_"_"_"_', '"""');