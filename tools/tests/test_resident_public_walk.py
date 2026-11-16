"""The route authoring tool reports disconnected public paths without crashing."""
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from build_resident_routes import _public_walk


class PublicWalk(unittest.TestCase):
    def test_missing_route_names_start_and_all_goals(self):
        with self.assertRaises(SystemExit) as caught:
            _public_walk("isolated", ["stairs", "lobby"], "F01", {}, {}, [])
        self.assertEqual(str(caught.exception),
                         "no public walk from isolated to ['stairs', 'lobby']")

    def test_reaches_an_available_goal_instead_of_requiring_the_first(self):
        spaces = {key: {"level": "F01", "class": "public"}
                  for key in ("start", "hall", "exit")}
        links = [{"connects": ["start", "hall"]},
                 {"connects": ["hall", "exit"]}]
        self.assertEqual(_public_walk("start", ["unreachable", "exit"], "F01",
                                      {}, spaces, links),
                         [(links[0], "hall"), (links[1], "exit")])

    def test_private_room_does_not_become_a_public_shortcut(self):
        spaces = {"private": {"level": "F01", "class": "private"},
                  "exit": {"level": "F01", "class": "public"}}
        links = [{"connects": ["start", "private"]},
                 {"connects": ["private", "exit"]}]
        with self.assertRaises(SystemExit):
            _public_walk("start", ["exit"], "F01", {}, spaces, links)

    def test_start_already_at_a_goal_needs_no_path(self):
        self.assertEqual(_public_walk("stairs", ["stairs"], "F01", {}, {}, []), [])


if __name__ == "__main__":
    unittest.main()
