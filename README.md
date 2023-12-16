Build Vim spell file 🧙 from sources
====================================

## DESCRIPTION

  Build Vim spell file from published and private sources

## OVERVIEW

  [`spell/en.utf-8.add--personal`](spell/en.utf-8.add--personal)
  is the base Vim spell file that gets merged with other spell files.

  [`bin/spells.sh`](bin/spells.sh)
  merges the base spell file and the
  list of spell files passed to it.

  - It sorts and removes duplicates.

  - And it tells you if you need to merge into the active
    spell file (`~/.vim/spell/en.utf-8.add`), or if you
    need to sync new words back into your source files.

  This feature is used by DepoXy during a so-called `mr autocommit` operation.

  - See how DepoXy uses `bin/spells.sh`:

      [spellfile.txt-runner.sh](https://github.com/DepoXy/depoxy/blob/release/home/.config/ohmyrepos/spellfile.txt-runner.sh)

## COMMANDS

  `./bin/spells.sh compile-spells [path]...`

  - `compile-spells` takes a list of spell files to merge.

    It expects the first argument to be a `$HOME`-ish directory
    (one that has a `.vim/spell` subdirectory).

    - It saves the compiled spell file to `.vim/spell/en.utf-8.add--compiled`

    The second and subsequent paths can be paths to spell files directly.

## EXAMPLES

  If you have a private spell file at `~/.vim/spell/private`,
  here's how you would build your spell file:

      $ cd path/to/spellfile.txt  # This repo's directory, not a text file
      $ bin/spells.sh compile-spells . ~/.vim/spell/private
      $ view ./.vim/spell/en.utf-8.add--compiled

  If this is all very interesting to you, check of how DepoXy uses
  this project for a better understanding.

## SEE ALSO

  DepoXy Development Environment Orchestrator

  https://github.com/DepoXy/depoxy#🍯

## AUTHOR

Copyright (c) 2010-2023 Landon Bouma &lt;depoxy@tallybark.com&gt;

This software is released under the MIT license (see `LICENSE` file for more)

## REPORTING BUGS

&lt;https://github.com/DepoXy/spellfile.txt/issues&gt;

