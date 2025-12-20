// can use PMT to edit/show thumbnail stuff
//
class MapThumbnailPropsTab : Tab {
    MapThumbnailPropsTab(TabGroup@ parent) {
        super(parent, "Map Thumbnail", Icons::MapO + Icons::Camera);
        // RegisterOnEditorLoadCallback(CoroutineFunc(this.OnEnterEditor), this.tabName);
    }

}
