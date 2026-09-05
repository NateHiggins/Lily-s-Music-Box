import unittest

from haunt_control import assess_pair, known_warning, warning_debt
from test_haunt_control import fixture

RGB = "WARNING: Image format RGB8 not supported by hardware, converting to RGBA8."
SITE = "   at: _validate_texture_format (servers/rendering/renderer_rd/storage_rd/texture_storage.cpp:2855)"
GENERAL = "WARNING: GENERAL - Message Id Number: 0 | Message Id Name: Loader Message"
REGISTRY = "windows_read_data_files_in_registry: Registry lookup failed to get layer manifest files."
CALLBACK = "   at: _debug_messenger_callback (drivers/vulkan/rendering_context_driver_vulkan.cpp:654)"


class KnownWarningTests(unittest.TestCase):
    def test_exact_conversion_remains_named_debt(self):
        f = fixture(); f["old_stderr"] = RGB + "\n" + SITE + "\n"
        result = assess_pair(**f)
        self.assertTrue(result["expected_control_pattern"])
        self.assertEqual(result["known_warning_debt"]["omission"], {"known RGB8 conversion debt": 1})

    def test_same_header_wrong_site_rejected(self):
        f = fixture(); f["old_stderr"] = RGB + "\n" + SITE.replace(":2855", ":9999") + "\n"
        self.assertFalse(assess_pair(**f)["expected_control_pattern"])

    def test_exact_registry_detail_and_site_required(self):
        self.assertEqual(known_warning([GENERAL, REGISTRY, CALLBACK], 0), "known host registry warning")
        self.assertEqual(known_warning([GENERAL, "different registry failure", CALLBACK], 0), "")
        self.assertEqual(known_warning([GENERAL, REGISTRY], 0), "")

    def test_unknown_warning_is_still_reported(self):
        self.assertEqual(warning_debt("", "WARNING: unrelated\n"), {"unreviewed warning": 1})


if __name__ == "__main__":
    unittest.main(verbosity=2)
