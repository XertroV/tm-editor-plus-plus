// void OpenMapBaseSizeChanger() {
//     if (g_MapBaseSizeChanger is null) return;
//     g_MapBaseSizeChanger.windowOpen = true;
// }

// MapBaseSizeChangerTab@ g_MapBaseSizeChanger;

// class MapBaseSizeChangerTab : Tab {
//     int stage = -1;

//     MapBaseSizeChangerTab(TabGroup@ p) {
//         super(p, "Map Base Size Changer", Icons::MapO + Icons::Expand);
//     }

//     void DrawInner() override {
//         if (stage < 0) {
//             DrawInit();
//         } else {
//             UI::Text("Stage: " + stage + " / 3");
//         }
//     }

//     nat3 origSize;
//     nat3 newSize;
//     uint mapDecoId;

//     void DrawInit() {
//         UI::Text("This tool will change the size of the map.");
//         UI::TextWrapped("\\$f80Warning!\\$z This will save the map, close the editor, and load the map again.");
//         auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
//         if (editor is null) {
//             UI::Text("You need to be in the editor to use this tool.");
//             return;
//         }
//         auto map = editor.Challenge;
//         if (origSize != map.Size) {
//             origSize = map.Size;
//             newSize = origSize;
//         }
//         UI::Text("Original size: " + origSize.ToString());
//         newSize.x = UI::InputInt("New X", newSize.x);
//         newSize.y = UI::InputInt("New Y", newSize.y);
//         newSize.z = UI::InputInt("New Z", newSize.z);
//         UI::Text("Decoration: " + map.Decoration.IdName);
//         mapDecoId = map.Decoration.Id.Value;
//         if (UI::Button("Begin")) {
//             startnew(CoroutineFunc(RunChangeSize));
//         }
//     }

//     nat3 origDecoSize;

//     void RunChangeSize() {
//         stage = 1;
//         auto app = cast<CGameManiaPlanet>(GetApp());
//         auto editor = cast<CGameCtnEditorFree>(app.Editor);
//         auto deco = app.RootMap.Decoration;
//         deco.MwAddRef();
//         auto currCam = Editor::GetCurrentCamState(editor);
//         string fileName = editor.Challenge.MapInfo.FileName;
//         string modUrl = "";
//         // if (app.RootMap.ModPackDesc !is null) {
//         //     modUrl = app.RootMap.ModPackDesc.Url;
//         //     if (modUrl.Length == 0) {
//         //         modUrl = app.RootMap.ModPackDesc.Name;
//         //     }
//         // }
//         auto playerModel = ""; // app.RootMap.VehicleName.GetName();

//         @editor = null;

//         stage++;
//         Editor::SaveAndExitMap();

//         origDecoSize.x = deco.DecoSize.SizeX;
//         origDecoSize.y = deco.DecoSize.SizeY;
//         origDecoSize.z = deco.DecoSize.SizeZ;

//         deco.DecoSize.SizeX = newSize.x;
//         deco.DecoSize.SizeY = newSize.y;
//         deco.DecoSize.SizeZ = newSize.z;

//         MwFastBuffer<wstring> scripts();
//         MwFastBuffer<wstring> args();
//         scripts.Add("TrackMania/Nadeo/Trackmania/PlayMapAtSave.Script.txt");
//         args.Add("");
//         scripts.Add("TrackMania/Nadeo/TMGame/ColorAndAnimation.Script.txt");
//         args.Add("<root></root>");

//         stage++;
//         app.ManiaTitleControlScriptAPI.EditMap5(fileName, deco.Name, modUrl, playerModel, scripts, args, true, false);

//         AwaitEditor();
//         sleep(200);
//         startnew(Editor::_RestoreMapName);
//         Editor::SetCamAnimationGoTo(currCam);

//         deco.DecoSize.SizeX = origDecoSize.x;
//         deco.DecoSize.SizeY = origDecoSize.y;
//         deco.DecoSize.SizeZ = origDecoSize.z;
//         deco.MwRelease();

//         stage = -1;
//     }
// }
