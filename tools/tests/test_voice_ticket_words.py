from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]/'voice'))
import dynamic


class TicketWordsTests(unittest.TestCase):
    def test_ticket_readings_are_unambiguous_cardinals(self):
        for value, words in [(0, 'zero'), (19, 'nineteen'), (20, 'twenty'), (40, 'forty'),
                             (226, 'two hundred twenty-six'), (233, 'two hundred thirty-three'),
                             (1000, 'one thousand'), (1001, 'one thousand one')]:
            with self.subTest(value=value):
                self.assertEqual(dynamic.number_words(value), words)
        for invalid in (True, -1, 1.5, '233', 1000000):
            with self.subTest(value=invalid), self.assertRaises(ValueError):
                dynamic.number_words(invalid)

    def test_real_ticket_rows_preserve_displayed_digits(self):
        root = Path(__file__).resolve().parents[2]
        inventory = dynamic.build(root)
        rows = [row for row in inventory['supplemental_rows'] if row.get('component_kind') == 'ticket']
        self.assertTrue(rows)
        for row in rows:
            self.assertEqual(row['text'], str(row['component_value']))
            self.assertEqual(row['spoken_form'], dynamic.number_words(row['component_value']))


if __name__ == '__main__':
    unittest.main()
