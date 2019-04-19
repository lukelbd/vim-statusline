# Statusline
This VIM plugin provides a simple, minimal, black-and-white "statusline" with some handy features. The statusline will look something like the following:

```
/path/to/file (git branch) [filetype:filesize] [mode] [caps_lock_indicator]     [ctags_location] [line/nlines] (percent)
```

It optionally integrates with the [tagbar](https://github.com/majutsushi/tagbar) plugin, which uses the [exuberant ctags](http://ctags.sourceforge.net/) command-line tool, along with the [fugitive](https://github.com/tpope/vim-fugitive) plugin.

See the source code for details.



  # Installation
  Install with your favorite [plugin manager](https://vi.stackexchange.com/questions/388/what-is-the-difference-between-the-vim-plugin-managers).
  I highly recommend the [`vim-plug`](https://github.com/junegunn/vim-plug)` manager,
  in which case you can install this plugin by adding
  ```
  Plug 'lukelbd/vim-statusline'
  ```
  to your `.vimrc`.
  
