namespace Editor {
    namespace Callbacks {
        namespace Exts {
            IEppExtension@[] allExtensions;

            /*
              when adding a new callback, make sure to add it to `RegisterExtension` and `RemoveExtension_Immediate`
            */

            IEppExtension@[] withEditorLoadCbs;
            IEppExtension@[] withEditorStartingUpCbs;
            IEppExtension@[] withItemEditorLoadCbs;
            IEppExtension@[] withMTEditorLoadCbs;
            IEppExtension@[] withMTEditorUnloadCbs;
            IEppExtension@[] withEditorUnloadCbs;
            IEppExtension@[] withEditorGoneNullCbs;
            IEppExtension@[] withSelectedItemChangedCbs;
            IEppExtension@[] withEnteringPlaygroundCbs;
            IEppExtension@[] withLeavingPlaygroundCbs;
            IEppExtension@[] withMapTypeUpdateCbs;
            IEppExtension@[] withAfterMapTypeUpdateCbs;
            IEppExtension@[] withAfterCursorUpdateCbs;
            IEppExtension@[] withBeforeCursorUpdateCbs;
            IEppExtension@[] withApplyColorToSelectionCbs;
            // IEppExtension@[] withOnEditorSaveMapCbs;
            // IEppExtension@[] withAfterEditorSaveMapCbs;
            IEppExtension@[] withItemPlaceCbs;
            IEppExtension@[] withItemDeleteCbs;
            IEppExtension@[] withBlockPlaceCbs;
            IEppExtension@[] withBlockDeleteCbs;

            void RegisterExtension(IEppExtension@ extension) {
                allExtensions.InsertLast(extension);

                if (extension.onEditorLoad !is null) withEditorLoadCbs.InsertLast(extension);
                if (extension.onEditorStartingUp !is null) withEditorStartingUpCbs.InsertLast(extension);
                if (extension.onItemEditorLoad !is null) withItemEditorLoadCbs.InsertLast(extension);
                if (extension.onMTEditorLoad !is null) withMTEditorLoadCbs.InsertLast(extension);
                if (extension.onMTEditorUnload !is null) withMTEditorUnloadCbs.InsertLast(extension);
                if (extension.onEditorUnload !is null) withEditorUnloadCbs.InsertLast(extension);
                if (extension.onEditorGoneNull !is null) withEditorGoneNullCbs.InsertLast(extension);
                if (extension.onLeavingPlayground !is null) withLeavingPlaygroundCbs.InsertLast(extension);
                if (extension.onEnteringPlayground !is null) withEnteringPlaygroundCbs.InsertLast(extension);
                if (extension.onMapTypeUpdate !is null) withMapTypeUpdateCbs.InsertLast(extension);
                if (extension.afterMapTypeUpdate !is null) withAfterMapTypeUpdateCbs.InsertLast(extension);
                if (extension.onAfterCursorUpdate !is null) withAfterCursorUpdateCbs.InsertLast(extension);
                if (extension.onBeforeCursorUpdate !is null) withBeforeCursorUpdateCbs.InsertLast(extension);
                if (extension.onApplyColorToSelection !is null) withApplyColorToSelectionCbs.InsertLast(extension);
                if (extension.onNewSelectedItem !is null) withSelectedItemChangedCbs.InsertLast(extension);
                if (extension.onPlaceItem !is null) withItemPlaceCbs.InsertLast(extension);
                if (extension.onDeleteItem !is null) withItemDeleteCbs.InsertLast(extension);
                if (extension.onPlaceBlock !is null) withBlockPlaceCbs.InsertLast(extension);
                if (extension.onDeleteBlock !is null) withBlockDeleteCbs.InsertLast(extension);
                // if (extension.onEditorSaveMap !is null) withOnEditorSaveMapCbs.InsertLast(extension);
                // if (extension.afterEditorSaveMap !is null) withAfterEditorSaveMapCbs.InsertLast(extension);
            }

            void RemoveExtension_Immediate(IEppExtension@ extension) {
                if (extension !is null) extension.kill();
                RemoveFromArrayIfExists(allExtensions, extension);
                RemoveFromArrayIfExists(withEditorLoadCbs, extension);
                RemoveFromArrayIfExists(withEditorStartingUpCbs, extension);
                RemoveFromArrayIfExists(withItemEditorLoadCbs, extension);
                RemoveFromArrayIfExists(withMTEditorLoadCbs, extension);
                RemoveFromArrayIfExists(withMTEditorUnloadCbs, extension);
                RemoveFromArrayIfExists(withEditorUnloadCbs, extension);
                RemoveFromArrayIfExists(withEditorGoneNullCbs, extension);
                RemoveFromArrayIfExists(withLeavingPlaygroundCbs, extension);
                RemoveFromArrayIfExists(withEnteringPlaygroundCbs, extension);
                RemoveFromArrayIfExists(withMapTypeUpdateCbs, extension);
                RemoveFromArrayIfExists(withAfterMapTypeUpdateCbs, extension);
                RemoveFromArrayIfExists(withAfterCursorUpdateCbs, extension);
                RemoveFromArrayIfExists(withBeforeCursorUpdateCbs, extension);
                RemoveFromArrayIfExists(withApplyColorToSelectionCbs, extension);
                RemoveFromArrayIfExists(withSelectedItemChangedCbs, extension);
                RemoveFromArrayIfExists(withItemPlaceCbs, extension);
                RemoveFromArrayIfExists(withItemDeleteCbs, extension);
                RemoveFromArrayIfExists(withBlockPlaceCbs, extension);
                RemoveFromArrayIfExists(withBlockDeleteCbs, extension);
                // RemoveFromArrayIfExists(withOnEditorSaveMapCbs, extension);
                // RemoveFromArrayIfExists(withAfterEditorSaveMapCbs, extension);
            }

            bool RemoveFromArrayIfExists(IEppExtension@[]@ arr, IEppExtension@ extension) {
                int ix = arr.FindByRef(extension);
                if (ix < 0) return false;
                arr.RemoveAt(ix);
                return true;
            }

            void Run_OnEditorLoad() {
                for (int i = 0; i < int(withEditorLoadCbs.Length); i++) {
                    auto ext = withEditorLoadCbs[i];
                    if (ext is null || ext.isDead || ext.onEditorLoad is null) {
                        RemoveExtension_Immediate(ext);
                        i--;
                        continue;
                    }
                    ext.onEditorLoad();
                }
            }

            void Run_OnEditorStartingUp() {
                for (int i = 0; i < int(withEditorStartingUpCbs.Length); i++) {
                    auto ext = withEditorStartingUpCbs[i];
                    if (ext is null || ext.isDead || ext.onEditorStartingUp is null) {
                        RemoveExtension_Immediate(ext);
                        i--;
                        continue;
                    }
                    ext.onEditorStartingUp();
                }
            }

            void Run_OnItemEditorLoad() {
                for (int i = 0; i < int(withItemEditorLoadCbs.Length); i++) {
                    auto ext = withItemEditorLoadCbs[i];
                    if (ext is null || ext.isDead || ext.onItemEditorLoad is null) {
                        RemoveExtension_Immediate(ext);
                        i--;
                        continue;
                    }
                    ext.onItemEditorLoad();
                }
            }

            void Run_OnMTEditorLoad() {
                for (int i = 0; i < int(withMTEditorLoadCbs.Length); i++) {
                    auto ext = withMTEditorLoadCbs[i];
                    if (ext is null || ext.isDead || ext.onMTEditorLoad is null) {
                        RemoveExtension_Immediate(ext);
                        i--;
                        continue;
                    }
                    ext.onMTEditorLoad();
                }
            }

            void Run_OnMTEditorUnload() {
                for (int i = 0; i < int(withMTEditorUnloadCbs.Length); i++) {
                    auto ext = withMTEditorUnloadCbs[i];
                    if (ext is null || ext.isDead || ext.onMTEditorUnload is null) {
                        RemoveExtension_Immediate(ext);
                        i--;
                        continue;
                    }
                    ext.onMTEditorUnload();
                }
            }

            void Run_OnEditorUnload() {
                for (int i = 0; i < int(withEditorUnloadCbs.Length); i++) {
                    auto ext = withEditorUnloadCbs[i];
                    if (ext is null || ext.isDead || ext.onEditorUnload is null) {
                        RemoveExtension_Immediate(ext);
                        i--;
                        continue;
                    }
                    ext.onEditorUnload();
                }
            }

            void Run_OnEditorGoneNull() {
                for (int i = 0; i < int(withEditorGoneNullCbs.Length); i++) {
                    auto ext = withEditorGoneNullCbs[i];
                    if (ext is null || ext.isDead || ext.onEditorGoneNull is null) {
                        RemoveExtension_Immediate(ext);
                        i--;
                        continue;
                    }
                    ext.onEditorGoneNull();
                }
            }

            void Run_OnLeavingPlayground() {
                for (int i = 0; i < int(withLeavingPlaygroundCbs.Length); i++) {
                    auto ext = withLeavingPlaygroundCbs[i];
                    if (ext is null || ext.isDead || ext.onLeavingPlayground is null) {
                        RemoveExtension_Immediate(ext);
                        i--;
                        continue;
                    }
                    ext.onLeavingPlayground();
                }
            }

            void Run_OnEnteringPlayground() {
                for (int i = 0; i < int(withEnteringPlaygroundCbs.Length); i++) {
                    auto ext = withEnteringPlaygroundCbs[i];
                    if (ext is null || ext.isDead || ext.onEnteringPlayground is null) {
                        RemoveExtension_Immediate(ext);
                        i--;
                        continue;
                    }
                    ext.onEnteringPlayground();
                }
            }

            void Run_OnMapTypeUpdate() {
                for (int i = 0; i < int(withMapTypeUpdateCbs.Length); i++) {
                    auto ext = withMapTypeUpdateCbs[i];
                    if (ext is null || ext.isDead || ext.onMapTypeUpdate is null) {
                        RemoveExtension_Immediate(ext);
                        i--;
                        continue;
                    }
                    ext.onMapTypeUpdate();
                }
            }

            void Run_AfterMapTypeUpdate() {
                for (int i = 0; i < int(withAfterMapTypeUpdateCbs.Length); i++) {
                    auto ext = withAfterMapTypeUpdateCbs[i];
                    if (ext is null || ext.isDead || ext.afterMapTypeUpdate is null) {
                        RemoveExtension_Immediate(ext);
                        i--;
                        continue;
                    }
                    ext.afterMapTypeUpdate();
                }
            }

            void Run_OnAfterCursorUpdate() {
                for (int i = 0; i < int(withAfterCursorUpdateCbs.Length); i++) {
                    auto ext = withAfterCursorUpdateCbs[i];
                    if (ext is null || ext.isDead || ext.onAfterCursorUpdate is null) {
                        RemoveExtension_Immediate(ext);
                        i--;
                        continue;
                    }
                    ext.onAfterCursorUpdate();
                }
            }

            void Run_OnBeforeCursorUpdate() {
                for (int i = 0; i < int(withBeforeCursorUpdateCbs.Length); i++) {
                    auto ext = withBeforeCursorUpdateCbs[i];
                    if (ext is null || ext.isDead || ext.onBeforeCursorUpdate is null) {
                        RemoveExtension_Immediate(ext);
                        i--;
                        continue;
                    }
                    ext.onBeforeCursorUpdate();
                }
            }

            void Run_OnApplyColorToSelection(int64 color) {
                for (int i = 0; i < int(withApplyColorToSelectionCbs.Length); i++) {
                    auto ext = withApplyColorToSelectionCbs[i];
                    if (ext is null || ext.isDead || ext.onApplyColorToSelection is null) {
                        RemoveExtension_Immediate(ext);
                        i--;
                        continue;
                    }
                    ext.onApplyColorToSelection(color);
                }
            }

            void Run_OnNewSelectedItem(CGameItemModel@ itemModel) {
                for (int i = 0; i < int(withSelectedItemChangedCbs.Length); i++) {
                    auto ext = withSelectedItemChangedCbs[i];
                    if (ext is null || ext.isDead || ext.onNewSelectedItem is null) {
                        RemoveExtension_Immediate(ext);
                        i--;
                        continue;
                    }
                    ext.onNewSelectedItem(itemModel);
                }
            }

            void Run_OnPlaceItem(CGameCtnAnchoredObject@ item) {
                for (int i = 0; i < int(withItemPlaceCbs.Length); i++) {
                    auto ext = withItemPlaceCbs[i];
                    if (ext is null || ext.isDead || ext.onPlaceItem is null) {
                        RemoveExtension_Immediate(ext);
                        i--;
                        continue;
                    }
                    ext.onPlaceItem(item);
                }
            }

            void Run_OnDeleteItem(CGameCtnAnchoredObject@ item) {
                for (int i = 0; i < int(withItemDeleteCbs.Length); i++) {
                    auto ext = withItemDeleteCbs[i];
                    if (ext is null || ext.isDead || ext.onDeleteItem is null) {
                        RemoveExtension_Immediate(ext);
                        i--;
                        continue;
                    }
                    ext.onDeleteItem(item);
                }
            }

            void Run_OnPlaceBlock(CGameCtnBlock@ block) {
                for (int i = 0; i < int(withBlockPlaceCbs.Length); i++) {
                    auto ext = withBlockPlaceCbs[i];
                    if (ext is null || ext.isDead || ext.onPlaceBlock is null) {
                        RemoveExtension_Immediate(ext);
                        i--;
                        continue;
                    }
                    ext.onPlaceBlock(block);
                }
            }

            void Run_OnDeleteBlock(CGameCtnBlock@ block) {
                for (int i = 0; i < int(withBlockDeleteCbs.Length); i++) {
                    auto ext = withBlockDeleteCbs[i];
                    if (ext is null || ext.isDead || ext.onDeleteBlock is null) {
                        RemoveExtension_Immediate(ext);
                        i--;
                        continue;
                    }
                    ext.onDeleteBlock(block);
                }
            }

            // void Run_OnEditorSaveMap() {
            //     for (int i = 0; i < int(withOnEditorSaveMapCbs.Length); i++) {
            //         auto ext = withOnEditorSaveMapCbs[i];
            //         if (ext is null || ext.isDead || //         ext is null) {
            //             RemoveExtension_Immediate(ext);
            //             i--;
            //             continue;
            //         }
            //         ext.onEditorSaveMap();
            //     }
            // }

            // void Run_AfterEditorSaveMap() {
            //     for (int i = 0; i < int(withAfterEditorSaveMapCbs.Length); i++) {
            //         auto ext = withAfterEditorSaveMapCbs[i];
            //         if (ext is null || ext.isDead || //         ext is null) {
            //             RemoveExtension_Immediate(ext);
            //             i--;
            //             continue;
            //         }
            //         ext.afterEditorSaveMap();
            //     }
            // }
        }
    }
}
