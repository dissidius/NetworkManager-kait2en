import importlib.machinery
import importlib.util
import unittest
from pathlib import Path

loader = importlib.machinery.SourceFileLoader("companion", str(Path(__file__).with_name("kait2en-wifi")))
spec = importlib.util.spec_from_loader(loader.name, loader)
m = importlib.util.module_from_spec(spec)
loader.exec_module(m)

class Policy(unittest.TestCase):
    def test_parse(self):
        self.assertEqual(m.parse_info("Interface wlp5s0\n\twiphy 0\n\ttype managed\n\tchannel 36 (5180 MHz), width: 80 MHz, center1: 5210 MHz"),
                         (0, "managed", (36, 5180, 80)))
    def test_same_channel(self):
        self.assertEqual(m.target((36, 5180, 80)), ("a",36,80))
        self.assertEqual(m.target((44, 5220, 40)), ("a",44,40))
        self.assertEqual(m.target((6, 2437, 40)), ("bg",6,20))
    def test_unsafe_or_unknown(self):
        for x in (None, (112,5560,80), (36,5180,160), (149,5745,80), (14,2484,20), (36,5560,80)):
            self.assertIsNone(m.target(x))
    def test_bad_info(self):
        with self.assertRaises(RuntimeError):
            m.parse_info("")

if __name__ == "__main__":
    unittest.main()
