"""Run THE BLANK DECK: `python -m oracle`, or `python path/to/oracle` for a copied folder."""
import sys

if __package__ in (None, ""):          # run as a folder: its parent has to be importable, and it must not be
    import os
    sys.path[0] = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    from oracle import cli
    cli.RUN_AS = sys.argv[0]            # so that what the player is told to type is what they typed
    main = cli.main
else:
    from .cli import main

if __name__ == "__main__":
    sys.exit(main())
