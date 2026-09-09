"""Execute the shipped donor wait with host I/O mocks; no game or plugin build.

Only AngelScript handle/member/throw syntax is translated. This checks actual
wait control flow, not AngelScript VM semantics or native editor lifetime.
"""

import re
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "src/Editor/MacroblockTerrain.as"


def shipped_wait():
    source = SOURCE.read_text()
    start = source.index("void WaitForDonorRestores()")
    brace = source.index("{", start)
    depth = 1
    end = brace + 1
    while depth:
        depth += (source[end] == "{") - (source[end] == "}")
        end += 1
    return source[start:end]


def translate(source):
    source = re.sub(r"//[^\n]*", "", source)
    source = source.replace("!is", "!=")
    source = re.sub(r"\bis\b", "==", source)
    source = re.sub(r"\bnull\b", "nullptr", source)
    source = source.replace(".Length", ".size()")
    source = re.sub(r"\bapp\.", "app->", source)
    source = re.sub(r'throw\("([^"\n]*)"\);', r'throw std::runtime_error("\1");', source)
    return source


HARNESS = r'''
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

using uint = unsigned;
struct Nod {};
struct App {
    Nod *Editor, *RootMap, *CurrentPlayground;
    uint exitRequested = 0;
};
Nod editor, map, playground, replacement;
App original{&editor, &map, nullptr}, other{&editor, &map, nullptr};
App* current = &original;
App* GetApp() { return current; }
std::vector<int> _terrainPlaceRestoreQueue;
uint yields = 0, mutations = 0, changeAt = 1, offset = 0x7D8;
bool drainAtChange = true, readFailure = false;
std::string change;

uint GetOffset(const std::string& type, const std::string& member) {
    if (type != "CGameCtnApp" || member != "Editor")
        throw std::runtime_error("unexpected reflection request");
    if (offset == 0xFFFF) throw std::runtime_error("Invalid offset: 0xFFFF");
    return offset;
}
namespace Dev {
uint GetOffsetUint32(App* app, uint actualOffset) {
    if (app != current) throw std::runtime_error("expired app access");
    if (actualOffset != 0x7B4) throw std::runtime_error("wrong exit flag offset");
    if (readFailure) throw std::runtime_error("injected exit read failure");
    return app->exitRequested;
}
}
void yield() {
    if (++yields > changeAt) {
        // A late check must not pass merely because identities subsequently return.
        current = &original;
        original.Editor = &editor;
        original.RootMap = &map;
        original.CurrentPlayground = nullptr;
        original.exitRequested = 0;
        _terrainPlaceRestoreQueue.clear();
        return;
    }
    if (yields != changeAt) return;
    if (change == "app") current = &other;
    else if (change == "app-null") current = nullptr;
    else if (change == "editor") original.Editor = &replacement;
    else if (change == "editor-null") original.Editor = nullptr;
    else if (change == "map") original.RootMap = &replacement;
    else if (change == "map-null") original.RootMap = nullptr;
    else if (change == "playground") original.CurrentPlayground = &playground;
    else if (change == "playground-replaced") original.CurrentPlayground = &replacement;
    else if (change == "playground-null") original.CurrentPlayground = nullptr;
    else if (change == "exit") original.exitRequested = 2;
    else if (change == "read-failure") readFailure = true;
    if (drainAtChange) _terrainPlaceRestoreQueue.clear();
}

SHIPPED_WAIT

// Any native mutation in a captured-editor caller must remain unreachable on rejection.
void CapturedEditorCaller() {
    auto capturedEditor = GetApp() == nullptr ? nullptr : GetApp()->Editor;
    (void)capturedEditor;
    WaitForDonorRestores();
    ++mutations;
}

int main(int argc, char** argv) {
    if (argc != 6) return 2;
    change = argv[1];
    const bool pending = std::stoi(argv[2]);
    changeAt = std::stoul(argv[3]);
    drainAtChange = std::stoi(argv[4]);
    const bool reject = std::stoi(argv[5]);
    if (pending) _terrainPlaceRestoreQueue.push_back(7);
    if (change == "initial-app-null") current = nullptr;
    if (change == "playground-replaced" || change == "playground-null" || change == "same-playground")
        original.CurrentPlayground = &playground;
    if (change == "initial-exit") original.exitRequested = 1;
    if (change == "initial-editor-null") original.Editor = nullptr;
    if (change == "initial-map-null") original.RootMap = nullptr;
    if (change == "bad-offset") offset = 0x23;
    if (change == "missing-offset") offset = 0xFFFF;
    bool threw = false;
    std::string error;
    try { CapturedEditorCaller(); }
    catch (const std::exception& e) { threw = true; error = e.what(); }
    const uint expectedYields = pending && change.rfind("initial-", 0) != 0
        && change != "bad-offset" && change != "missing-offset" ? changeAt : 0;
    const bool queuePreserved = !pending || (expectedYields > 0 && drainAtChange)
        ? _terrainPlaceRestoreQueue.empty()
        : _terrainPlaceRestoreQueue.size() == 1 && _terrainPlaceRestoreQueue[0] == 7;
    if (threw != reject || mutations != (reject ? 0U : 1U) || yields != expectedYields
            || !queuePreserved || error == "expired app access" || error == "wrong exit flag offset") {
        std::cerr << "reject=" << threw << " native mutations=" << mutations
                  << " yields=" << yields << " expected yields=" << expectedYields
                  << " queue preserved=" << queuePreserved << " error=" << error << '\n';
        return 1;
    }
    return 0;
}
'''


class DonorWaitTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix="epp-donor-wait-")
        cls.addClassCleanup(cls.temp.cleanup)
        cls.work = Path(cls.temp.name)
        cls.source = shipped_wait()
        cls.binary = cls.compile(cls.source, "shipped")

    @classmethod
    def compile(cls, source, name):
        cpp = cls.work / f"{name}.cpp"
        cpp.write_text(HARNESS.replace("SHIPPED_WAIT", translate(source)))
        binary = cls.work / name
        result = subprocess.run(
            ["/usr/bin/g++", "-std=c++17", "-Wall", "-Wextra", "-Werror", str(cpp), "-o", str(binary)],
            capture_output=True, text=True, check=False, timeout=30,
        )
        if result.returncode:
            raise RuntimeError(result.stdout + result.stderr)
        return binary

    def run_case(self, change, *, pending=True, change_at=1, drain=True, reject=True, binary=None):
        return subprocess.run(
            [str(binary or self.binary), change, str(int(pending)), str(change_at), str(int(drain)), str(int(reject))],
            capture_output=True, text=True, check=False, timeout=5,
        )

    def check_case(self, change, **kwargs):
        result = self.run_case(change, **kwargs)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_unchanged_scene_continues_once(self):
        self.check_case("none", pending=False, reject=False)
        self.check_case("same-playground", reject=False)
        for frames in (1, 3):
            with self.subTest(frames=frames):
                self.check_case("none", change_at=frames, reject=False)

    def test_every_identity_change_blocks_native_continuation(self):
        for change in ("app", "app-null", "editor", "editor-null", "map", "map-null",
                       "playground", "playground-replaced", "playground-null", "exit"):
            for frames in (1, 2):
                for drain in (False, True):
                    with self.subTest(change=change, frames=frames, drain=drain):
                        self.check_case(change, change_at=frames, drain=drain)

    def test_initial_invalid_scene_and_exit_never_yield_or_mutate(self):
        for change in ("initial-app-null", "initial-exit", "initial-editor-null", "initial-map-null"):
            for pending in (False, True):
                with self.subTest(change=change, pending=pending):
                    self.check_case(change, pending=pending)

    def test_exit_support_failures_block_native_continuation(self):
        for change in ("bad-offset", "missing-offset"):
            with self.subTest(change=change):
                self.check_case(change)
        self.check_case("read-failure")

    def test_return_before_post_yield_guard_mutation_is_detected(self):
        before = "            yield();"
        self.assertEqual(self.source.count(before), 1)
        mutated = self.source.replace(
            before, before + "\n            if (_terrainPlaceRestoreQueue.Length == 0) return;"
        )
        binary = self.compile(mutated, "early-return")
        result = self.run_case("editor", binary=binary)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("native mutations=1", result.stderr)

    def test_exit_flag_guard_mutation_is_detected(self):
        before = "Dev::GetOffsetUint32(app, editorOffset - 0x24) != 0"
        self.assertEqual(self.source.count(before), 1)
        binary = self.compile(self.source.replace(before, "false"), "no-exit-guard")
        result = self.run_case("exit", binary=binary)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("native mutations=1", result.stderr)


if __name__ == "__main__":
    unittest.main()
