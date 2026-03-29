# Shell Folder Bookmarks

Simple utility for Linux/macOS shells to jump to saved folders quickly.

## Install

1. Clone or copy this folder.
2. Source `bookmarks.sh` from your shell profile (`~/.bashrc`, `~/.zshrc`, etc.):

```sh
source /Users/jguo/Documents/bookmarksShell/bookmarks.sh
```

3. Reload your shell:

```sh
source ~/.bashrc
# or source ~/.zshrc
```

## Usage

```sh
bm add proj ~/work/project      # Save a bookmark
bm ls                           # List bookmarks
bm info                         # Show storage file + valid/invalid counts
bm clean                        # Remove bookmarks pointing to missing folders
bm proj                         # cd to bookmark (shortcut)
bm go proj                      # cd to bookmark
bm path proj                    # Print path only
bm rm proj                      # Remove bookmark
bm help                         # Help
```

## Bookmark Storage

By default, bookmarks are saved to:

```sh
~/.local/share/shell-bookmarks/bookmarks.tsv
```

You can override it with:

```sh
export BOOKMARKS_FILE="$HOME/.bookmarks.tsv"
```
