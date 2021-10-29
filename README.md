Statusline
==========

Vim plugin providing minimalist black-and-white "statusline" with some handy
features. The statusline will look something like this:

```
/path/to/file (git_branch) [filetype:filesize] [mode:paste_indicator] [caps_lock_indicator]     [ctags_location] [column:line/nlines] (percent)
```

The statusline will be colored white in insert mode, black in normal mode, and red
if the buffer file has been changed on disk. This plugin optionally integrates with the
[fugitive](https://github.com/tpope/vim-fugitive) and
[tagbar](https://github.com/majutsushi/tagbar) plugins
by showing the current git branch and closest ctag name.

Installation
============

Install with your favorite [plugin manager](https://vi.stackexchange.com/q/388/8084).
I highly recommend the [vim-plug](https://github.com/junegunn/vim-plug) manager.
To install with vim-plug, add
```
Plug 'lukelbd/vim-statusline'
```
to your `~/.vimrc`.
