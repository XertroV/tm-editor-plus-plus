vec3 g_MapBounds;
nat3 g_MapCoordBounds;

void CacheMapBounds() {
    auto map = GetApp().RootMap;
    g_MapCoordBounds = map is null ? nat3(48, 40, 48) : map.Size;
    g_MapBounds = CoordToPos(g_MapCoordBounds);
}
