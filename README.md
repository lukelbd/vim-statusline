# Statusline
This vim plugin provides a minimalist black-and-white "statusline" with some handy features. The statusline will look something like the following:

```
/path/to/file (git branch) [filetype:filesize] [mode:paste_indicator] [caps_lock_indicator]     [ctags_location] [line/nlines] (percent)
```

This plugin optionally integrates with the [fugitive](https://github.com/tpope/vim-fugitive) and [tagbar](https://github.com/majutsushi/tagbar) plugins, using which the current git branch and closest ctag name are shown in the statusline.

# Installation
Install with your favorite [plugin manager](https://vi.stackexchange.com/questions/388/what-is-the-difference-between-the-vim-plugin-managers).
I highly recommend the [vim-plug](https://github.com/junegunn/vim-plug) manager. To install with vim-plug, add
```
Plug 'lukelbd/vim-statusline'
```
to your `~/.vimrc`.

