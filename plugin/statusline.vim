"------------------------------------------------------------------------------
" Author: Luke Davis (lukelbd@gmail.com)
" Date:   2018-09-03
" A minimal, informative, black-and-white statusline that helps keep focus
" on the content in each window and integrates with other useful plugins.
"------------------------------------------------------------------------------
" Global settings
scriptencoding utf-8  " required for s:mode_names
set showcmd  " show command line below statusline
set noshowmode  " no mode indicator in command line (use the statusline instead)
set laststatus=2  " always show status line even in last window
set statusline=%{StatusLeft()}\ %=%{StatusRight()}

" Autocommands for highlighting
" Note: For some reason statusline_color must always search b:statusline_filechanged
" passing expand('<afile>') then using getbufvar colors statusline in wrong window.
augroup statusline_color
  au!
  au BufEnter,TextChanged,InsertEnter * silent! checktime
  au BufReadPost,BufWritePost,BufNewFile * call setbufvar(expand('<afile>'), 'statusline_filechanged', 0)
  au FileChangedShell * call setbufvar(expand('<afile>'), 'statusline_filechanged', 1)
  au FileChangedShell * call s:statusline_color(mode() =~? '^[ir]')  " triggers after
  au BufEnter,TextChanged * call s:statusline_color(mode() =~? '^[ir]')
  au InsertEnter * call s:statusline_color(1)
  au InsertLeave * call s:statusline_color(0)
augroup END

" Configuration variables
let s:current_mode = {
  \ 'n':  'N', 'no': 'O', 'i':  'I', 'R' : 'R', 'Rv': 'RV',
  \ 'v':  'V', 'V' : 'VL', '': 'VB', 's':  'S', 'S' : 'SL', '': 'SB',
  \ 'c':  'C', 'ce': 'CE', 'cv': 'CV', 'r' : 'CP', 'r?': 'CI', 'rm': 'M', '!' : '!', 't':  'T',
\ }
let s:maxlen_abs = 40  " maximum length after truncation
let s:maxlen_raw = 20  " maximum length without truncation
let s:maxlen_part = 15  " truncate path parts (directories and filename)
let s:maxlen_piece = 10  " truncate path pieces (seperated by dot/hypen/underscore)
let s:slash_string = !exists('+shellslash') ? '/' : &shellslash ? '/' : '\'
let s:slash_regex = escape(s:slash_string, '\')

" Get statusline color defaults from current colorsheme
" Note: This is needed for GUI vim color schemes since they do not use cterm codes. See
" https://vi.stackexchange.com/a/20757/8084 https://stackoverflow.com/a/27870856/4970632
function! s:default_color(code, ...) abort
  let default = a:code ==# 'fg' ? '#ffffff' : '#000000'
  let hex = synIDattr(hlID('Normal'), a:code . '#')  " request conversion to hex
  let hex = empty(hex) ? default : hex
  if empty(hex) || hex[0] !=# '#' | return hex | endif  " unexpected output
  let shade = a:0 && a:1 > 0 ? type(a:1) ? a:1 : 0.3 : 0.0  " shade toward neutral gray
  let color = '#'  " default hex color
  for idx in range(1, 5, 2)
    " vint: -ProhibitUsingUndeclaredVariable
    let value = str2nr(hex[idx:idx + 1], 16)
    let value = value - shade * (value - 128)
    let color .= printf('%02x', float2nr(value))
  endfor
  return color
endfunction

" Get statusline color dependent on various settings
" Note: Redraw required for CmdlineEnter,CmdlinLeave slow for large files and can
" trigger for maps, so leave alone. See: https://github.com/neovim/neovim/issues/7583
function! s:statusline_color(highlight) abort
  let name = has('gui_running') ? 'gui' : 'cterm'
  let flag = has('gui_running') ? '#be0119' : 'Red'  " copied from xkcd scarlet
  let gray = has('gui_running') ? s:default_color('bg', 1.0) : 'Gray'
  let black = has('gui_running') ? s:default_color('bg', 1) : 'Black'
  let white = has('gui_running') ? s:default_color('fg', 0) : 'White'
  let none = has('gui_running') ? 'background' : 'None'  " see :help guibg
  if getbufvar('%', 'fugitive_type', '') ==# 'blob'
    let front = black
    let back = flag
  elseif getbufvar('%', 'statusline_filechanged', 0)
    let front = white
    let back = flag
  elseif a:highlight
    let front = black
    let back = white
  else
    let front = white
    let back = black
  endif
  let focus = name . 'bg=' . back . ' ' . name . 'fg=' . front . ' ' . name . '=None'
  let nofocus = name . 'bg=' . none . ' ' . name . 'fg=' . black . ' ' . name . '=None'
  exe 'highlight StatusLine ' . focus
  exe 'highlight StatusLineNC ' . nofocus
  let g:statusline_gray = gray
  let g:statusline_black = black
  let g:statusline_white = white
  if mode() =~? '^c' | redraw | endif
endfunction

" Get path relative to working directory using successive '..' directives
" See: https://stackoverflow.com/a/26650027/4970632
" See: https://docs.python.org/3/library/os.path.html#os.path.relpath
function! s:relative_path(arg, ...) abort
  let head = '^fugitive:' . repeat(s:slash_regex, 2)
  let init = substitute(a:arg, head, '', '')
  let blob = '\.git' . repeat(s:slash_regex, 2) . '\x\{33}\(\x\{7}\)'
  let init = substitute(init, blob, '\1', '')
  let path = fnamemodify(init, ':p')
  let dots = ''  " header '..' dots
  let head = a:0 && type(a:1) ? a:1 : getcwd()
  if a:0 && !empty(a:1) && !type(a:1) && exists('*FugitiveGitDir')  " repo/foo/bar/baz
    let head = fnamemodify(FugitiveGitDir(), ':h')
    let icwd = getcwd()[:len(head) - 1] ==# head
    let head = icwd ? '' : fnamemodify(head, ':h')
  endif
  let head = empty(head) ? getcwd() : head
  let regex = '^' . escape(head, '[]\.*$~')
  while path !~# regex
    let ihead = fnamemodify(head, ':h')
    if ihead ==# head | return init | endif  " fallback to original
    let head = ihead  " alternative common
    let dots = '..' . (empty(dots) ? '' : s:slash_string . dots)
    let regex = '^' . escape(head, '[]\.*$~')
  endwhile
  let tail = substitute(path, regex, '', '')
  if empty(tail)
    return path
  elseif !empty(dots)
    return dots . tail
  else  " remove header slash
    return substitute(tail, '^' . s:slash_regex, '', '')
  endif
endfunction

" Shorten a given filename by truncating both path segments and leading
" directory name. Also indicate symlink redirects when relevant.
" See: https://github.com/blueyed/dotfiles/blob/master/vimrc#L396
function! s:path_name() abort
  let rawname = '' " used for symlink check
  let bufname = s:relative_path(expand('%'), 1)
  let parts = split(bufname, '\ze' . s:slash_regex)
  for idx in range(len(parts))
    let part = parts[idx]
    let maxlen = s:maxlen_part + (idx > 0)
    let rawname .= part  " unfiltered parts
    if strwidth(part) > maxlen && strwidth(bufname) > s:maxlen_raw
      let chars = idx == len(parts) - 1 ? '._-' : '_-'
      let pieces = split(part, '\ze[' . chars . ']')  " pieces to truncate
      if len(pieces) == 1
        let part = strcharpart(part, 0, maxlen - 1) . '·'
        let parts[idx] = part
      else
        let part = ''
        for jdx in range(len(pieces))
          let piece = pieces[jdx]
          let maxlen = s:maxlen_piece + (jdx > 0)
          if strwidth(piece) > maxlen  " include leading delimiter
            let part .= strcharpart(piece, 0, maxlen - 1) . '·'
          else
            let part .= piece
          endif
        endfor
        let parts[idx] = part
      endif
    endif
    if getftype(rawname) ==# 'link'  " indicator if this part of filename is symlink
      if s:slash_string ==# part[0]
        let part = s:slash_string . '↪ ' . part[1:]
      else
        let part = '↪ ' . part
      endif
      let parts[idx] = part
    endif
  endfor
  let path = join(parts, '')
  let width = strwidth(path)
  if width > s:maxlen_abs  " including multi-byte characters e.g. symlink
    let path = strcharpart(path, width - s:maxlen_abs)
    let path = '·' . path
  endif
  return path
endfunction

" Current git branch using fugitive
function! s:git_info() abort
  if exists('*FugitiveHead')
    let info = FugitiveHead()  " possibly empty
  else
    let info = ''
  endif
  if exists('*GitGutterGetHunkSummary')
    let [acnt, mcnt, rcnt] = GitGutterGetHunkSummary()
    let pairs = [['+', acnt], ['~', mcnt], ['-', rcnt]]
    for [key, cnt] in pairs
      if empty(cnt) | continue | endif
      let info .= key . cnt
    endfor
  endif
  if empty(info)
    return info
  else
    return ' (' . info . ')'
  endif
endfunction

" Current file type and size in human-readable units
function! s:file_info() abort
  if empty(&l:filetype)
    let info = 'unknown:'
  else
    let info = &l:filetype . ':'
  endif
  let bytes = getfsize(expand('%:p'))
  if bytes >= 1024
    let kbytes = bytes / 1024
  endif
  if exists('kbytes') && kbytes >= 1000
    let mbytes = kbytes / 1000
  endif
  if exists('mbytes')
    let info .= mbytes . 'MB'
  elseif exists('kbytes')
    let info .= kbytes . 'KB'
  else
    let info .= max([bytes, 0]) . 'B'
  endif
  return ' [' . info . ']'
endfunction

" Current mode including indicator if in paste mode
" Note: This was adapted from ObsessionStatus. Previously we tested existence
" of ObsessionStatus below but that caused race condition issue.
function! s:vim_info() abort
  let code = &l:spelllang
  if &l:paste  " 'p' for paste
    let info = 'P'
  elseif &l:iminsert  " 'l' for langmap
    let info = 'L'
  else  " default mode
    let info = get(s:current_mode, mode(), '?')
  endif
  if &l:foldenable && &l:foldlevel < 10
    let info .= ':Z' . &l:foldlevel
  endif
  if &l:spell && code =~? 'en_[a-z]\+'
    let info .= ':' . substitute(code, '\c^en_\([a-z]\+\).*$', '\1', '')
  elseif &l:spell
    let info .= ':' . substitute(code, '\c[^a-z].*$', '', '')
  endif
  if empty(v:this_session)
    let flag = ''
  elseif exists('g:this_obsession')
    let flag = ' [$]'
  else
    let flag = ' [S]'
  endif
  return  toupper(' [' . info . ']' . flag)
endfunction

" Current column number, current line number, total line number, and
" percentage. Also prepend tag kind and name using lukelbd/vim-tags
function! s:loc_info() abort
  let maxlen = 20  " can be changed
  if exists('*tags#current_tag')
    let info = tags#current_tag()
  elseif exists('*tagbar#currenttag')
    let info = tagbar#currenttag()
  else
    let info = ''
  endif
  if strwidth(info) > maxlen
    let info = strcharpart(info, 0, maxlen - 1) . '·'
  endif
  if !empty(info)
    let info = '[' . info . '] '
  endif
  let absolute = line('.') . '/' . line('$') . ':' . col('.')
  let relative = (100 * line('.') / line('$')) . '%'
  return info . '[' . absolute . '] (' . relative . ')'
endfunction

" Public functions used to fill the statusline. Also make the
" path function public (used across personal dotfiles repo).
function! RelativePath(...) abort
  return call('s:relative_path', a:000)
endfunction
function! StatusRight() abort
  return s:loc_info()
endfunction
function! StatusLeft() abort
  let names = ['s:path_name', 's:git_info', 's:file_info', 's:vim_info']
  let line = ''
  let maxsize = winwidth(0) - strwidth(StatusRight()) - 1
  for name in names  " note cannot use function() handles for locals
    let part = call(name, [])
    let size = strwidth(part)
    let trunc = strcharpart(part, 0, 1) !=# '·'
    if !trunc && empty(line) && size > maxsize && maxsize > 0
      let part = '·' . strcharpart(part, size - maxsize + 1)
    endif
    if strwidth(line . part) <= maxsize
      let line .= part
    endif
  endfor
  return line
endfunction
