#!/usr/bin/env python3
import os
import tempfile
import unittest
from pathlib import Path

import tm_logs


class TailLinesTest(unittest.TestCase):
    def test_missing_file(self):
        missing = Path("/tmp/tm_logs_does_not_exist.log")
        self.assertIsNone(tm_logs.tail_lines(missing, 10))

    def test_last_n_lines(self):
        with tempfile.TemporaryDirectory() as raw:
            path = Path(raw) / "Openplanet.log"
            path.write_text("".join(f"line {i}\n" for i in range(12)))
            got = tm_logs.tail_lines(path, 5)
            self.assertEqual(got, ["line 7", "line 8", "line 9", "line 10", "line 11"])


class NewestFilesTest(unittest.TestCase):
    def test_missing_dir(self):
        missing = Path("/tmp/tm_logs_dir_does_not_exist")
        self.assertEqual(tm_logs.newest_files(missing, 5), [])

    def test_newest_five_by_mtime(self):
        with tempfile.TemporaryDirectory() as raw:
            folder = Path(raw)
            names = []
            base = 1_700_000_000
            for i in range(7):
                p = folder / f"LogCrash_{i:02d}.txt"
                p.write_text(f"crash {i}")
                os.utime(p, (base + i, base + i))
                names.append(p.name)
            got = tm_logs.newest_files(folder, 5)
            self.assertEqual([item.name for item in got], list(reversed(names))[:5])


class ReportTest(unittest.TestCase):
    def test_missing_logcrash_is_explicit(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            log = root / "Openplanet.log"
            log.write_text("a\nb\nc\n")
            docs = root / "tm-docs"
            docs.mkdir()
            text = tm_logs.format_report(log, docs, lines=2, crashes=5)
            self.assertIn("Openplanet.log", text)
            self.assertIn("b", text)
            self.assertIn("c", text)
            self.assertNotIn("\na\n", "\n" + text)
            self.assertIn("LogCrash dir: MISSING", text)

    def test_lists_logcrash_and_root_crash_files(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            log = root / "Openplanet.log"
            log.write_text("keep-me\n")
            docs = root / "tm-docs"
            crash_dir = docs / "LogCrash"
            crash_dir.mkdir(parents=True)
            (crash_dir / "LogCrash_AAAA.txt").write_text("in-dir")
            (docs / "LogCrash_BBBB.txt").write_text("root")
            (docs / "Crash_00000001.txt").write_text("root-crash")
            text = tm_logs.format_report(log, docs, lines=10, crashes=5)
            self.assertIn("LogCrash dir: EXISTS", text)
            self.assertIn("LogCrash_AAAA.txt", text)
            self.assertIn("LogCrash_BBBB.txt", text)
            self.assertIn("Crash_00000001.txt", text)


if __name__ == "__main__":
    unittest.main()
