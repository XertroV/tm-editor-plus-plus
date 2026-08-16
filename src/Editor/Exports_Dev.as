// Dev-only exports: spike/research helpers not intended for other plugins.
// Build with `./build.sh dev` (defines DEV). Release builds export nothing from here.
#if DEV
namespace Editor {
    // Issue #35 spike: place CarSport at latest start-block spawn. JSON string report.
    import string SpikePlaceVehiclePreview() from "Editor";
    import string SpikeDumpTestVehicleCursor() from "Editor";
    import string SpikeLeaveTestMode() from "Editor";
    import string SpikeEnterGizmoOnLatestStart(int blockIndex = -1, int itemIndex = -1) from "Editor";
    import string SpikeExitGizmo() from "Editor";
    import string SpikeSetKeepVehiclePatch(bool on) from "Editor";
    import string SpikeEnterTestAtLatestStart() from "Editor";
    import string SpikeNudgeKeptVehicle(float dy) from "Editor";
}
#endif
