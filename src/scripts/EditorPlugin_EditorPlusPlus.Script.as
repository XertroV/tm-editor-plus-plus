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

Void SendAllInfo() {
	declare metadata Integer EPP_EditorPluginLoads for Map = 0;
	declare metadata Integer EPP_PlaygroundSwitches for Map = 0;
	declare metadata Integer EPP_MappingTime for Map = 0;
	declare metadata Integer EPP_MappingTime_Testing for Map = 0;
	declare metadata Integer EPP_MappingTime_Validating for Map = 0;
	declare metadata Integer EPP_MappingTime_Mapping for Map = 0;
	declare metadata Boolean EPP_ThumbnailLocked for Map = False;
	SendEvent("PluginLoads", [""^EPP_EditorPluginLoads]);
	SendEvent("PGSwitches", [""^EPP_PlaygroundSwitches]);
	SendEvent("MappingTime", [""^EPP_MappingTime, ""^EPP_MappingTime_Mapping, ""^EPP_MappingTime_Testing, ""^EPP_MappingTime_Validating]);
	SendEvent("LockedThumbnail", [""^EPP_ThumbnailLocked]);
}

Void ProcessIncomingMessages() {
	declare Text[][] EPP_MsgQueue for ManialinkPage = [];
	foreach (InMsg in EPP_MsgQueue) {
		if (InMsg.count == 0) continue;
		declare MsgType = InMsg[0];
		log("E++ EditorPlugin got incoming msg of type: " ^ MsgType);
		if (MsgType == "LockThumbnail") {
			LockThumbnail(InMsg[1] == "true");
		} else if (MsgType == "ResyncPlease") {
			SendAllInfo();
		}
	}
	EPP_MsgQueue.clear();
}

main() {
	LayersDefaultManialinkVersion = 3;
	ManialinkText = CreateManialink();

	// log(""^This);
	declare Boolean IsInPlayground = False;
	declare Integer LastMappingTimeUpdate = Now;
	// ! make sure to update SendAllInfo, too
	declare metadata Integer EPP_EditorPluginLoads for Map = 0;
	declare metadata Integer EPP_PlaygroundSwitches for Map = 0;
	declare metadata Integer EPP_MappingTime for Map = 0;
	declare metadata Integer EPP_MappingTime_Testing for Map = 0;
	declare metadata Integer EPP_MappingTime_Validating for Map = 0;
	declare metadata Integer EPP_MappingTime_Mapping for Map = 0;
	declare metadata Boolean EPP_ThumbnailLocked for Map = False;
	declare Text[][] EPP_MsgQueue for ManialinkPage = [];
	EPP_EditorPluginLoads += 1;

	log("E++: Setting AttachID on UI layer");
	UILayers[0].AttachId = "E++ Supporting Plugin";
	declare CUILayer MainLayer <=> UILayers[0];
	SendAllInfo();

	declare Integer ValidationStart = 0;

	while(True)
	{
		if (EPP_MsgQueue.count > 0) {
			ProcessIncomingMessages();
		}

		// signal from angelscript: clear CustomSelectionCoords
		if (CustomSelectionCoords.count == 1 && CustomSelectionCoords[0].X == -1) {
			CustomSelectionCoords.clear();
		} else if (CustomSelectionCoords.count > 0) {
			declare Int3[] Tmp = [];
			foreach (Coord in CustomSelectionCoords) { Tmp.add(Coord); }
			CustomSelectionCoords.clear();
			foreach (Coord in Tmp) { CustomSelectionCoords.add(Coord); }
		}

		// track playground in-out
		if ((IsTesting || IsValidating) != IsInPlayground) {
			IsInPlayground = IsTesting || IsValidating;
			if (IsInPlayground) {
				EPP_PlaygroundSwitches += 1;
				SendEvent("PGSwitches", [""^EPP_PlaygroundSwitches]);
			}
		}

		// update mapping time for map
		if (Now - LastMappingTimeUpdate > 100) {
			declare Delta = (Now - LastMappingTimeUpdate);
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
			LastMappingTimeUpdate = Now;
		}

		yield;
	}
}
""".Replace('_"_"_"_', '"""');