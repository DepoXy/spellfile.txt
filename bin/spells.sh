#!/usr/bin/env bash
# vim:tw=0:ts=2:sw=2:et:norl:nospell:ft=bash
# Author: Landon Bouma (landonb &#x40; retrosoft &#x2E; com)
# Related: https://github.com/DepoXy/spellfile.txt#🧙
# License: MIT

# Copyright (c) © 2023 Landon Bouma. All Rights Reserved.

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

init_spellssh () {
  SPELL_NAME="en.utf-8.add"
  # E.g., --personal
  SPELLS_PERSONAL_SUFFIX="${SPELLS_PERSONAL_SUFFIX:---personal}"
  # E.g., --compiled
  SPELLS_COMPILED_SUFFIX="${SPELLS_COMPILED_SUFFIX:---compiled}"
  # E.g., sync-spells-
  SPELLS_SYNC_PREFIX="${SPELLS_SYNC_PREFIX:-sync-spells-}"

  # E.g., spell/en.utf-8.add
  SPELL_PATH="spell/${SPELL_NAME}"

  # E.g., .vim/spell/en.utf-8.add
  VIM_SPELL_PATH=".vim/${SPELL_PATH}"

  # E.g., ~/.vim/spell/en.utf-8.add
  VIM_SPELL_FILE="${HOME}/${VIM_SPELL_PATH}"

  # E.g., /path/to/spellfile.txt
  SPF_BASE_DIR="$(dirname -- "$(realpath -- "$0")")/.."
  # E.g., /path/to/spellfile.txt/spell/en.utf-8.add
  SPF_SPELL_FILE="${SPF_BASE_DIR}/${VIM_SPELL_PATH}${SPELLS_PERSONAL_SUFFIX}"

  SPELLS_VERBOSE="${SPELLS_VERBOSE:-false}"
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

compile_spells () {
  local homeish_path="$1"
  shift

  local compiled_spells
  compiled_spells="$(print_compiled_spells_path "${homeish_path}")"

  [ $? -eq 0 ] && [ -n "${compiled_spells}" ] || return 1

  local spell_paths
  local echoerr_spell_paths=${SPF_PRINT_SPELLS:-true}
  spell_paths="$(find_and_print_spell_paths "$@")"
  unset -v echoerr_spell_paths

  set -- ${spell_paths}

  local n_spells=$#

  [ ${n_spells} -gt 0 ] || return 1

  merge_spells_verified "$@" > "${compiled_spells}"

  # ***

  local spellish_path="$(dirname -- "${compiled_spells}")"
  local active_spell="${spellish_path}/${SPELL_NAME}"

  local cleanup_only=false

  if ! is_canonical_spell_file "${homeish_path}"; then
    cleanup_only=true
  fi

  if [ -s "${active_spell}" ] \
    && ! diff -q "${compiled_spells}" "${active_spell}" > /dev/null \
  ; then
    # Normally --compiled falls behind active_spell, because when user adds
    # dictionary words in Vim, Vim updates active_spell.
    # - If --compiled has words, means user needs to update active_spell
    #   (should rarely happen).
    # - Note the [ -s "${active_spell}" ] — skip this check in the Vim
    #   spell file is empty. This happens when user is standing up a new
    #   Vim install, and after this script creates the --compiled file,
    #   the caller can copy that to active_spell and commit it.
    # - Add "-1", some `comm -3 -1` called, i.e., show only lines
    #   unique to rhs: ${compiled_spells}.
    local n_uniq_src_spells
    n_uniq_src_spells=$(print_unique_lines "${active_spell}" "${compiled_spells}" -1 | wc -l)

    if [ ${n_uniq_src_spells} -gt 0 ]; then
      # The compiled_spells file has unique lines.
      # - Check if active_spell does, because, if not, we can assume user
      #   updated their source spell files not through Vim, and it's okay
      #   to rebuild Vim's .add file. (I.e., user has not added new words
      #   to the .add file that we might clobber.)
      local n_uniq_vim_spells
      n_uniq_vim_spells=$(print_unique_lines "${active_spell}" "${compiled_spells}" -2 | wc -l)

      if [ ${n_uniq_vim_spells} -gt 0 ]; then
        >&2 echo
        >&2 echo "BWARE: New Vim spells found. Resolve the issue, then try again. E.g.,"
        >&2 echo
        >&2 echo "     $(fg_hotpink)meld$(attr_reset) \\"
        >&2 echo "       $(fg_hotpink)\"${active_spell}\" \\$(attr_reset)"
        >&2 echo "       $(fg_hotpink)\"${compiled_spells}\" &$(attr_reset)"
        >&2 echo
      else
        log_trace_ls_spell_files ()  {
          local when="$1"

          ${SPELLS_VERBOSE:-false} || return 0

          >&2 echo "${when} Vim mkspell:"
          >&2 echo "  $ ll ${active_spell}*"
          command ls -la ${active_spell}* | >&2 sed 's/^/  /'
          >&2 echo
        }

        # CXREF:
        #   https://github.com/landonb/vim-mkspell-when-stale#🥖
        #     ~/.vim/pack/landonb/start/vim-mkspell-when-stale/autoload/mkspell_when_stale.vim
        #       redir @a
        #       silent execute 'mkspell! ' . fnameescape(vocab)
        #       redir END
        vim_generate_spellfile () {
          # Create '.spl' file, e.g.,
          #   :execute 'mkspell! ~/path/to/.vim/spell/en.utf-8.add'
          # will generate the spell file:
          #   ~/path/to/.vim/spell/en.utf-8.add.spl

          log_trace_ls_spell_files "Before"

          >&2 echo "vim -c \"execute 'mkspell! ${active_spell}'\" -c q"

          # Redirect stderr, lest: Vim: Warning: Output is not to a terminal
          vim -c "execute 'mkspell! ${active_spell}'" -c q 2> /dev/null

          log_trace_ls_spell_files "After"
        }

        >&2 echo "command cp -- \"${compiled_spells}\" \\"
        >&2 echo "  \"${active_spell}\""

        command cp -- "${compiled_spells}" "${active_spell}"

        vim_generate_spellfile

        log_user_alert () {
          ${SPELLS_VERBOSE:-false} || return 0

          >&2 echo
          >&2 echo "ALERT: Replaced .add and .spl files after source changes detected:"
          >&2 echo
          ( ls -la "$(realpath -- "${active_spell}")" ;
            ls -la "$(realpath -- "${active_spell}.spl")" ;
          ) | sed "s/^/  $(fg_hotpink)/" | >&2 sed "s/$/$(attr_reset)/"
          # Too boring:
          #  ) | >&2 sed 's/^/  /'
        }
        log_user_alert

        if command rm -- "${active_spell}.spl" 2> /dev/null; then
          >&2 echo "✗ Removed intermediate .spl (not ~/.vim's): ${active_spell}.spl"
        else
          >&2 echo "GAFFE: No .spl file at: ${active_spell}.spl"
        fi
      fi
    fi
  else
    cleanup_only=true
  fi

  local i_spell
  for i_spell in $(seq 1 ${n_spells}); do

    local spells_sync_part="${spellish_path}/${SPELLS_SYNC_PREFIX}"
    local spells_without_ispell="${spells_sync_part}-${i_spell}"
    local source_spells_plus_new="${spells_without_ispell}-new"
    local spells_sync_executable="${source_spells_plus_new}.sh"

    # Grab $1, $2, or $3, etc., from $@ using index.
    local source_spell="${!i_spell}"
    local sorted_source="${source_spell}--sorted"

    if ${cleanup_only}; then
      command rm -f -- "${spells_sync_executable}"
      command rm -f -- "${sorted_source}"

      continue
    fi

    local omit_spell=${i_spell}
    merge_spells_verified "$@" > "${spells_without_ispell}"

    print_unique_lines "${spells_without_ispell}" "${active_spell}" > "${source_spells_plus_new}"

    command rm -- "${spells_without_ispell}"

    cat "${source_spell}" | special_sort > "${sorted_source}"

    local rm_sorted_source=true
    if ! diff -q --ignore-blank-lines "${source_spell}" "${sorted_source}" > /dev/null; then
      rm_sorted_source=false

      >&2 echo "✗ Source not sorted properly: ${source_spell}"
      >&2 echo "  - Leaving sorted copy for you to process:"
      >&2 echo "      ${sorted_source}"
    fi

    if diff -q "${sorted_source}" "${source_spells_plus_new}" > /dev/null; then
      >&2 echo "✓ Synced: ${source_spell}"

      command rm -f -- "${spells_sync_executable}"
    else
      if ${SPELLS_VERBOSE:-false}; then
        >&2 echo "✗ Creating sync script: ${spells_sync_executable}"
        >&2 echo "    diff \"${sorted_source}\" \\"
        >&2 echo "      \"${source_spells_plus_new}\""
      fi

      (
        echo "#!/usr/bin/env bash"
        echo
        echo "# USAGE: Run this file, then move new words from right to left"
        echo "#        if the new word belongs in the source file on the left"
        echo
        echo "# CXREF: The source spells were combined into a single file:"
        echo "#          ${compiled_spells}"
        echo "#        And new words were identified by comparing against"
        echo "#        the active Vim spell file:"
        echo "#          ${active_spell}"
        echo
        echo "$(print_meld_command) \\"
        echo '  "'"${source_spell}"'" \'
        echo '  <(sed '0,/^✂️$/d' "'"${spells_sync_executable}"'") \'
        echo '  2>/dev/null &'
        echo
        echo "exit 0"
        echo
        echo "# REMEMBER: You don't need to save this file. Move words to the other file."
        echo "# - Do the same for any other similar script that was created."
        echo "# - Run compile-spells again to verify everything captured,"
        echo "#   and this and any similar scripts will have been removed."
        echo
        echo "✂️"
        echo "# Copy appropriate words to the leftward source:"
        echo "#   ${source_spell}"
        cat "${source_spells_plus_new}"
      ) > "${spells_sync_executable}"

      chmod +x "${spells_sync_executable}"
    fi

    command rm -- "${source_spells_plus_new}"
    
    ! ${rm_sorted_source} || command rm -- "${sorted_source}"
  done

  echo "${compiled_spells}"
}

# ***

# Here's a simpler de-deduplicate, but doesn't honor caller's order:
#
#   verify_and_print_spell_paths "$@" | sort | uniq
#
# We'll walk the results instead to de-duplicate, and to honor the
# caller's original order. But it's not the most elegant code.

find_and_print_spell_paths () {
  local spell_paths
  spell_paths="$(verify_and_print_spell_paths "$@")"

  if [ -z "${spell_paths}" ]; then
    >&2 echo "ERROR: No spell files found"

    return 1
  fi

  local n_spellfiles=$(echo "${spell_paths}" | wc -l)
  for i_spath in $(seq 1 ${n_spellfiles}); do
    # This is so inefficient, but it's just 3 or 4 lines in practice.
    local spath="$(echo "${spell_paths}" | head -n ${i_spath} | tail -n 1)"
    local unique=true

    if [ ${i_spath} -gt 1 ]; then
      if echo "${spell_paths}" | head -n $((${i_spath} - 1)) | grep -q -e "^${spath}$"; then
        unique=false
      fi
    fi

    if ${unique}; then
      echo "${spath}"
    fi
  done
}

verify_and_print_spell_paths () {
  local n_spells=0

  local path
  for path in "${SPF_SPELL_FILE}" "$@"; do
    local probe="${path}"

    # >&2 echo "?: ${probe}"
    [ -n "${probe}" ] || continue

    # If path not the spell file, it's to a spell-ish, vim-ish or home-ish dir.
    [ -f "${probe}" ] || probe="${path}/${SPELL_NAME}${SPELLS_PERSONAL_SUFFIX}"
    [ -f "${probe}" ] || probe="${path}/${SPELL_PATH}${SPELLS_PERSONAL_SUFFIX}"
    [ -f "${probe}" ] || probe="${path}/${VIM_SPELL_PATH}${SPELLS_PERSONAL_SUFFIX}"

    [ -f "${probe}" ] || continue

    let 'n_spells += 1'

    ! ${echoerr_spell_paths:-false} || >&2 echo "${n_spells}: ${probe}"

    realpath -- "${probe}"
  done
}

# Merges this project's spellfile with those specified as arguments.
# - Each path argument can specify the spell file directly, e.g.,
#     /path/to/en.utf-8.add
#   Or the path argument can be to a home-ish directory, where
#   the spell file is expected to be found at:
#     .vim/spell/en.utf-8.add
#     .vim/spell/en.utf-8.add
# - The lines from the passed paths and from spellfile.txt/spell/en.utf-8.add
#   are concatenated, sorted, culled for duplicates, and printed.
cat_spells () {
  n_spells=0

  local path
  for path in "$@"; do
    let 'n_spells += 1'

    [ ${omit_spell:-0} -eq 0 ] || [ ${omit_spell} -ne ${n_spells} ] || continue

    # I've never seen a pound sign used in the spell file, so this should be
    # okay to allow comments, and to filter them here.
    cat "${path}" | sed 's/ \+#.*//g' | sed '/^#/d'
  done
}

# Unused fcn.
merge_spells () {
  local spell_paths
  spell_paths="$(find_and_print_spell_paths "$@")"

  set -- ${spell_paths}

  merge_spells_verified "$@"
}

# Sorta like `cat "$@" | sort`, but overly complicated.
merge_spells_verified () {
  cat_spells "$@" | special_sort
}

# ***

print_compiled_spells_path () {
  local homeish_path="$1"

  local vimish_path
  if [ -n "${homeish_path}" ]; then
    vimish_path="${homeish_path}/.vim"
  else
    vimish_path="${SPF_BASE_DIR}"
  fi

  local spellish_path="${vimish_path}/${SPELL_PATH}"
  if [ ! -d "$(dirname -- "${spellisfh_path}")" ]; then
    >&2 echo "ERROR: Homeish path missing expected spell subdir:"
    >&2 echo "  ${spellish_path}"

    return 1
  fi

  # E.g., path/to/home/.vim/spell/en.utf-8.add--compiled
  local compiled_spells="${spellish_path}${SPELLS_COMPILED_SUFFIX}"

  printf "%s" "${compiled_spells}"
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

print_meld_command () {
  # SAVVY: Just check dir., as flatpak-info is slower. E.g., not:
  #
  #   if command -v "flatpak" > /dev/null 2>&1; then
  #     # CXREF: ${HOME}/.local/share/flatpak/app/org.gnome.meld
  #     if flatpak info org.gnome.meld > /dev/null 2>&1; then
  #       ...
  is_meld_flatpak_installed () {
    [ -d "${HOME}/.local/share/flatpak/app/org.gnome.meld" ] \
      || [ -d "/var/lib/flatpak/app/org.gnome.meld" ]
  }

  # ***

  # Aka ${HOMEBREW_PREFIX}
  local brew_home="/opt/homebrew"
  # Otherwise on Intel Macs it's under /usr/local.
  [ -d "${brew_home}" ] || brew_home="/usr/local"

  local user_meld="${DOPP_KIT:-${HOME}/.kit}/py/meld"

  # USYNC: DEPOXY_PYENV_PYVERS
  local py_vers="${DEPOXY_MELD_PYVERS:-${DEPOXY_PYENV_PYVERS:-3.12.1}}"
  local py_path="/opt/homebrew/lib/python${py_vers%.*}/site-packages"

  is_meld_sources_installed () {
    [ -x "${user_meld}/bin/meld" ] \
      && [ -x "${brew_home}/bin/meld" ] \
      && [ -d "${py_path}/meld" ]
  }

  # ALTLY: Because of #!/usr/bin/python3 in brew executable,
  # we could instead call brew module via python3 directly:
  #   PYTHONPATH="${py_path}" python3 ${brew_home}/bin/meld "$@"
  print_meld_sources () {
    # Avoid same-named Homebrew executable with `command` preflight.
    echo 'test "$(command -v deactivate)" = "deactivate" && deactivate'
    echo 'eval "$(pyenv init -)"'

    # Shouldn't be necessary/wouldn't make sense here:
    #   pyenv install -s ${py_vers}
    echo "pyenv shell ${py_vers}"

    printf "%s" "PYTHONPATH=\"${py_path}\" ${user_meld}/bin/meld"
  }

  # ***

  is_meld_application_installed () {
    [ -d "/Applications/Meld.app/" ]
  }

  # ***

  # Prefer flatpak meld (Debian)
  # or Meld from sources (macOS).

  if is_meld_flatpak_installed; then
    printf "%s" "flatpak run org.gnome.meld"
  elif is_meld_sources_installed; then
    print_meld_sources
  elif is_meld_application_installed; then
    # ALTLY: `open` could work, but fails on relative paths.
    #   open /Applications/Meld.app/ --args "$@"
    printf "%s" "/Applications/Meld.app/Contents/MacOS/Meld"
  elif type -f "meld" > /dev/null 2>&1; then
    # `type -f` ignores functions, i.e., don't match the function we're in.

    # We don't need ourselves again.
    unset -f meld

    printf "%s" "/usr/bin/env meld"
  else
    >&2 echo "ERROR: Cannot locate meld (via flatpak or on PATH)"

    exit 1
  fi
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

# Tell user count of spells added since last merged back to sources.
# - Note vanilla sort, which comm expects, vs. `LC_ALL='C' sort -d`.

print_num_unsynced_changes () {
  local homeish_path="$1"

  local compiled_spells
  compiled_spells="$(print_compiled_spells_path "${homeish_path}")"

  [ $? -eq 0 ] && [ -n "${compiled_spells}" ] || return 1

  if [ ! -f "${compiled_spells}" ]; then
    >&2 echo "ERROR: Compiled spells not found:"
    >&2 echo "    ${spellish_path}"
    >&2 echo "- Hint: Have you run compile-spells yet?"

    return 1
  fi

  if [ ! -f "${VIM_SPELL_FILE}" ]; then
    >&2 echo "ERROR: Missing Vim spell file!"
    >&2 echo "    ${VIM_SPELL_FILE}"
    >&2 echo "- Now that's a doozie..."

    return 1
  fi

  local n_lines_diff=0

  if is_canonical_spell_file "${homeish_path}"; then
    n_lines_diff=$( \
      print_unique_lines "${VIM_SPELL_FILE}" "${compiled_spells}" \
        | wc -l)
  elif ${SPELLS_VERBOSE:-false}; then
    >&2 echo "BWARE: Skipping non-canonical spell file compare"
    >&2 echo "- I.e., not processing ~/${VIM_SPELL_PATH}"
  fi

  printf "%s" "${n_lines_diff}"
}

  # Check if ~/.vim/spell/en.utf-8.add -> local project file
is_canonical_spell_file () {
  local homeish_path="$1"
  
  test "$(realpath -- "${VIM_SPELL_FILE}")" = \
    "$(realpath -- "${homeish_path}/${VIM_SPELL_PATH}")"
}

# ***

# Interesting: `comm --output-delimiter=""` works from session,
# but when you pipe it to a file, it uses null bytes. So leave
# the leading tabs and remove them on post.
#
# - Nope, uses null bytes, but not like -z/--zero-terminated,
#   which only seems to nullify document BEG and EOF.
#
#     comm -3 --output-delimiter="" \
#       <(cat "${spell1}" | sort) \
#       <(cat "${spell2}" | sort)

print_unique_lines () {
  local spell1="$1"
  local spell2="$2"
  shift 2
  # Suppress common (matching) lines "-3" by default.
  # - Add "-1" to suppress lines unique to ${spell1}
  #   and/or "-2" to suppress lines unique to ${spell2}.

  comm -3 $@ \
    <(cat "${spell1}" | sort) \
    <(cat "${spell2}" | sort) \
  | sed 's/^\s\+//' \
  | sed '/^$/d' \
  | special_sort
}

# --dictionary-order: Emoji, A-Z, then a-z.
special_sort () {
  sed '/^$/d' | sort | LC_ALL='C' uniq | LC_ALL='C' sort -d
}

# ***

fg_hotpink () {
  printf "\033[38;2;255;0;135m"
}

attr_reset () {
  printf "\033[0m"
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

check_deps () {
  local failed=false

  check_dep_mktemp || failed=true
  check_dep_realpath || failed=true

  ${failed} && exit 1 || true
}

check_dep_mktemp () {
  hint_install_deb () { >&2 echo "  sudo apt-get install coreutils"; }
  hint_install_brew () { >&2 echo "  brew install coreutils"; }

  check_dep_with_hint "mktemp"
}

check_dep_realpath () {
  ( true \
    && command -v realpath > /dev/null \
    && realpath --version 2> /dev/null | head -1 | grep -q -e "(GNU coreutils)" \
  ) && return 0 || true

  hint_install_deb () { >&2 echo "  sudo apt-get install coreutils"; }
  hint_install_brew () { >&2 echo "  brew install realpath"; }

  check_dep_with_hint 'realpath' 'realpath (from coreutils)' true
}

check_dep_with_hint () {
  cmd="$1"
  name="${2:-${cmd}}"
  assume_failed=${3:-false}

  if ! ${assume_failed}; then
    command -v ${cmd} > /dev/null && return 0 || true
  fi

  os_is_macos () { [ "$(uname)" = 'Darwin' ]; }

  >&2 echo "ERROR: Requires ‘${cmd}’"
  >&2 echo "- Hint: Install ‘${cmd}’, e.g.:"
  os_is_macos && hint_install_brew || hint_install_deb 

  return 1
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

dispatch_command () {
  local command="$1"
  shift

  case ${command} in
    compile-spells)
      compile_spells "$@"
      ;;
    print-num-unsynced-changes)
      print_num_unsynced_changes "$@"
      ;;
    *)
      >&2 echo "ERROR: Unrecognized command: “${command}”"

      exit 1
      ;;
  esac
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

clear_traps () {
  trap - EXIT INT
}

set_traps () {
  trap -- trap_exit EXIT
  trap -- trap_int INT
}

exit_0 () {
  clear_traps

  exit 0
}

exit_1 () {
  clear_traps

  exit 1
}

trap_exit () {
  clear_traps

  # USAGE: Alert on unexpected error path, so you can add happy path.
  >&2 echo "ALERT: "$(basename -- "$0")" exited abnormally!"
  >&2 echo "- Hint: Enable \`set -x\` and run again..."

  exit 2
}

trap_int () {
  clear_traps

  exit 3
}

# ***

main () {
  set -e

  set_traps

  check_deps

  init_spellssh

  dispatch_command "$@"

  clear_traps
}

# Only run when executed; no-op when sourced.
if [ "$0" = "${BASH_SOURCE[0]}" ]; then
  main "$@"
fi

