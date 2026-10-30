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


class AdvertisingTests(unittest.TestCase):
    FIRM = {"name": "Otis & Son", "mark": "O", "mark_shape": "ring", "id_line": "Est. 1889", "address": "The Arcade",
            "telephone": "Havemeyer 2120", "hours": "", "slogan": ""}

    def ad(self, **overrides):
        ad = {"paper": "both", "firm": "Otis & Son", "style": "card", "size": "S", "headline": "A headline",
              "body": " ".join(["word"] * 20), "image": "res://data/newspapers/papers.json"}
        ad.update(overrides)
        return ad

    def page(self, **overrides):
        return [self.ad(size=size, **overrides) for size in ("S", "S", "S", "S", "W", "W", "T", "B")]

    def run_ads(self, ads):
        found = []
        audit.check_ads({"firms": {"Otis & Son": self.FIRM}, "ads": ads}, found)
        return found

    def test_good_ads_pass(self):
        self.assertEqual(self.run_ads(self.page()), [])

    def test_each_paper_needs_a_full_page_of_ads(self):
        self.assertTrue(self.run_ads([self.ad()] * 6))
        self.assertTrue(self.run_ads(self.page(paper="record")))

    def test_limits_and_forbidden_words(self):
        for bad in (self.ad(headline="x" * 40), self.ad(body="too short"), self.ad(paper="gazette"),
                    self.ad(body=" ".join(["word"] * 20) + " at the orison"),
                    self.ad(firm="Nobody Inc."), self.ad(style="poster"), self.ad(size="X"),
                    self.ad(image="res://nope.png")):
            self.assertTrue(self.run_ads([bad] + self.page()), bad)

    def test_a_firm_must_say_who_it_is_and_how_to_reach_it(self):
        for field, value in (("telephone", ""), ("address", ""), ("id_line", ""), ("name", "Mae Kessler")):
            found = []
            audit.check_ads({"firms": {"Otis & Son": dict(self.FIRM, **{field: value})}, "ads": self.page()}, found)
            self.assertTrue(found, field)

    def test_cartoons_run_on_sundays_with_a_real_image(self):
        image = "res://data/newspapers/papers.json"
        good = {"date": "1928-11-11", "image": image, "caption": "A caption."}
        found = []
        audit.check_cartoons({"cartoons": [good]}, found)
        self.assertEqual(found, [])
        for bad in (dict(good, date="1928-11-12"), dict(good, image="res://nope.png"), dict(good, caption="")):
            found = []
            audit.check_cartoons({"cartoons": [bad]}, found)
            self.assertTrue(found, bad)


if __name__ == "__main__":
    unittest.main()
