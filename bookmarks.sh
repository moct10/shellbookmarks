#!/usr/bin/env sh

# Default bookmark database (tab-separated: name<TAB>absolute_path).
BM_DEFAULT_FILE="$HOME/.local/share/shell-bookmarks/bookmarks.tsv"

_bm_file() {
  printf '%s\n' "${BM_FILE:-${BOOKMARKS_FILE:-$BM_DEFAULT_FILE}}"
}

_bm_help() {
  cat <<'EOF'
Usage:
  bm add <name> [path]   Save current directory (or path) as a bookmark
  bm go <name>           Change directory to bookmark
  bm <name>              Shortcut for "bm go <name>"
  bm ls                  List all bookmarks
  bm info                Show bookmark file and stats
  bm clean               Remove bookmarks whose folders no longer exist
  bm cleanup             Alias for "bm clean"
  bm path <name>         Print bookmark path
  bm rm <name>           Remove bookmark
  bm help                Show this help

Notes:
  - Bookmark names allow letters, numbers, ".", "_" and "-"
  - This file must be sourced, not executed:
      source /path/to/bookmarks.sh
EOF
}

_bm_init() {
  bm_file="$(_bm_file)"
  mkdir -p "$(dirname "$bm_file")" || return 1
  [ -f "$bm_file" ] || : >"$bm_file"
}

_bm_validate_name() {
  case "$1" in
  '' | *[!A-Za-z0-9._-]*)
    printf 'Invalid bookmark name: %s\n' "$1" >&2
    printf 'Use only letters, numbers, ".", "_" and "-".\n' >&2
    return 1
    ;;
  esac
}

_bm_get() {
  bm_file="$(_bm_file)"
  awk -F '\t' -v name="$1" '
    $1 == name { print $2; found = 1 }
    END { if (!found) exit 1 }
  ' "$bm_file"
}

_bm_upsert() {
  bm_file="$(_bm_file)"
  name="$1"
  bm_target="$2"
  tmp_file="${bm_file}.tmp.$$"

  awk -F '\t' -v name="$name" '$1 != name' "$bm_file" >"$tmp_file" || return 1
  printf '%s\t%s\n' "$name" "$bm_target" >>"$tmp_file" || return 1
  mv "$tmp_file" "$bm_file"
}

_bm_remove() {
  bm_file="$(_bm_file)"
  name="$1"
  tmp_file="${bm_file}.tmp.$$"

  if ! awk -F '\t' -v name="$name" 'BEGIN { found = 0 } $1 == name { found = 1 } END { exit !found }' "$bm_file"; then
    printf 'Bookmark not found: %s\n' "$name" >&2
    return 1
  fi

  awk -F '\t' -v name="$name" '$1 != name' "$bm_file" >"$tmp_file" || return 1
  mv "$tmp_file" "$bm_file"
}

_bm_info() {
  bm_file="$(_bm_file)"
  tab_char="$(printf '\t')"
  total=0
  valid=0
  invalid=0

  while IFS="$tab_char" read -r name bm_target || [ -n "$name$bm_target" ]; do
    [ -n "$name" ] || continue
    total=$((total + 1))
    if [ -d "$bm_target" ]; then
      valid=$((valid + 1))
    else
      invalid=$((invalid + 1))
    fi
  done <"$bm_file"

  printf 'Bookmarks file: %s\n' "$bm_file"
  printf 'Total bookmarks: %s\n' "$total"
  printf 'Valid folders: %s\n' "$valid"
  printf 'Invalid folders: %s\n' "$invalid"
}

_bm_clean() {
  bm_file="$(_bm_file)"
  tab_char="$(printf '\t')"
  tmp_file="${bm_file}.tmp.$$"
  kept=0
  removed=0

  : >"$tmp_file" || return 1

  while IFS="$tab_char" read -r name bm_target || [ -n "$name$bm_target" ]; do
    [ -n "$name" ] || continue

    if [ -d "$bm_target" ]; then
      printf '%s\t%s\n' "$name" "$bm_target" >>"$tmp_file" || {
        rm -f "$tmp_file"
        return 1
      }
      kept=$((kept + 1))
    else
      printf 'Removed invalid bookmark: %s (%s)\n' "$name" "$bm_target"
      removed=$((removed + 1))
    fi
  done <"$bm_file"

  mv "$tmp_file" "$bm_file" || {
    rm -f "$tmp_file"
    return 1
  }

  printf 'Clean complete. Kept %s, removed %s.\n' "$kept" "$removed"
}

bm() {
  _bm_init || {
    printf 'Failed to initialize bookmarks database: %s\n' "$(_bm_file)" >&2
    return 1
  }

  cmd="$1"
  [ -n "$cmd" ] || {
    _bm_help
    return 0
  }

  case "$cmd" in
  help | -h | --help)
    _bm_help
    ;;
  add)
    name="$2"
    bm_dir="${3:-$PWD}"
    [ -n "$name" ] || {
      printf 'Usage: bm add <name> [path]\n' >&2
      return 1
    }
    _bm_validate_name "$name" || return 1
    [ -d "$bm_dir" ] || {
      printf 'Directory not found: %s\n' "$bm_dir" >&2
      return 1
    }
    abs_path="$(cd "$bm_dir" 2>/dev/null && pwd -P)" || {
      printf 'Could not resolve path: %s\n' "$bm_dir" >&2
      return 1
    }
    _bm_upsert "$name" "$abs_path" || return 1
    printf 'Saved "%s" to %s\n' "$name" "$abs_path"
    ;;
  ls | list)
    bm_file="$(_bm_file)"
    if [ ! -s "$bm_file" ]; then
      printf 'No bookmarks yet. Add one with: bm add <name>\n'
      return 0
    fi
    awk -F '\t' '{ printf "%-20s %s\n", $1, $2 }' "$bm_file" | sort
    ;;
  info)
    _bm_info
    ;;
  clean | cleanup)
    _bm_clean
    ;;
  path)
    name="$2"
    [ -n "$name" ] || {
      printf 'Usage: bm path <name>\n' >&2
      return 1
    }
    _bm_get "$name" || {
      printf 'Bookmark not found: %s\n' "$name" >&2
      return 1
    }
    ;;
  rm | remove | del | delete)
    name="$2"
    [ -n "$name" ] || {
      printf 'Usage: bm rm <name>\n' >&2
      return 1
    }
    _bm_remove "$name" || return 1
    printf 'Removed bookmark: %s\n' "$name"
    ;;
  go)
    name="$2"
    [ -n "$name" ] || {
      printf 'Usage: bm go <name>\n' >&2
      return 1
    }
    target="$(_bm_get "$name")" || {
      printf 'Bookmark not found: %s\n' "$name" >&2
      return 1
    }
    [ -d "$target" ] || {
      printf 'Bookmarked directory no longer exists: %s\n' "$target" >&2
      return 1
    }
    cd "$target" || return 1
    ;;
  *)
    # "bm <name>" acts as shortcut for "bm go <name>"
    if [ "$#" -eq 1 ]; then
      name="$cmd"
      target="$(_bm_get "$name")" || {
        printf 'Bookmark not found: %s\n' "$name" >&2
        return 1
      }
      [ -d "$target" ] || {
        printf 'Bookmarked directory no longer exists: %s\n' "$target" >&2
        return 1
      }
      cd "$target" || return 1
      return 0
    fi
    printf 'Unknown command: %s\n' "$cmd" >&2
    _bm_help
    return 1
    ;;
  esac
}
