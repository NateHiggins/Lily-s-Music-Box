"""The newspaper audit's rules for the optional back page."""
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import audit_newspapers as audit

BODY = " ".join(["word"] * 30)


def column(kind="news", headline="A plain headline"):
    return {"kind": kind, "headline": headline, "body": BODY}


def back(**overrides):
    page = {"columns": [column(), column("sport"), column("notices"), column("classified")],
            "foot": "One line at the foot."}
    page.update(overrides)
    return page


def failures(page, paper="record"):
    found = []
    audit.check_back(page, paper, "test", found)
    return found


class BackPageTests(unittest.TestCase):
    def test_a_good_back_page_passes(self):
        self.assertEqual(failures(back()), [])

    def test_four_columns_exactly(self):
        self.assertTrue(failures(back(columns=[column()] * 3)))

    def test_a_kind_from_the_other_paper_fails(self):
        self.assertTrue(failures(back(columns=[column("pun_derby"), column(), column(), column()])))
        self.assertEqual(failures(back(columns=[column("pun_derby"), column(), column(), column()]), "speaker"), [])

    def test_headline_limit_is_ninety(self):
        self.assertEqual(failures(back(columns=[column(headline="x" * 89), column(), column(), column()])), [])
        self.assertTrue(failures(back(columns=[column(headline="x" * 90), column(), column(), column()])))

    def test_one_classified_at_most(self):
        self.assertTrue(failures(back(columns=[column("classified"), column("classified"), column(), column()])))

    def test_body_word_limits_match_the_front(self):
        short = {"kind": "news", "headline": "A plain headline", "body": "Too short."}
        self.assertTrue(failures(back(columns=[short, column(), column(), column()])))

    def test_foot_is_one_line(self):
        self.assertTrue(failures(back(foot="")))
        self.assertTrue(failures(back(foot="two\nlines")))

    def test_the_year_is_clean_and_requiring_back_pages_notices_their_absence(self):
        found, stats = audit.audit("1928-11a")
        self.assertEqual(found, [])
        required, _ = audit.audit("1928-11a", require_back=True)
        expected = 2 * stats["issues"] - stats["back_pages"]
        self.assertEqual(sum(line.endswith("no back page") for line in required), expected)


if __name__ == "__main__":
    unittest.main()
