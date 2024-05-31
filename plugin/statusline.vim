"------------------------------------------------------------------------------
" A minimal, informative, black-and-white statusline
"------------------------------------------------------------------------------
" Global settings
" Author: Luke Davis (lukelbd@gmail.com)
" This plugin uses a simple black-and-white style that helps retain focus on the syntax
" highlighting in your window, shows filenames relative to base fugitive or gutentags
" root directories, and provides info on folding, unstaged changes, and nearby tags.
scriptencoding utf-8  " {{{{
set showcmd  " show command line below statusline
set noshowmode  " no mode indicator in command line (use the statusline instead)
set laststatus=2  " always show status line even in last window
set statusline=%{StatusLeft()}\ %=%{StatusRight()}
let s:slash_str = !has('win32') && !has('win64') || exists('+shellslash') && &shellslash ? '/' : '\'
let s:maxlen_abs = 40  " maximum length after truncation
let s:maxlen_raw = 20  " maximum length without truncation
let s:maxlen_part = 15  " truncate path parts (directories and filename)
let s:maxlen_piece = 10  " truncate path pieces (seperated by dot/hypen/underscore)
let s:mode_strings = {
  \ 'n':  'N', 'no': 'O', 'i':  'I', 'R' : 'R', 'Rv': 'RV', '!' : '!', 't':  'T',
  \ 'v':  'V', 'V' : 'VL', '': 'VB', 's':  'S', 'S' : 'SL', '': 'SB',
  \ 'c':  'C', 'ce': 'CE', 'cv': 'CV', 'r' : 'CP', 'r?': 'CI', 'rm': 'M'}  " }}}

" Global autocommands
" Note: For some reason statusline_update must always search b:statusline_filechanged
" passing expand('<afile>') then using getbufvar colors statusline in wrong window.
silent! au! statusline_color
augroup statusline_update
  au!
  au BufEnter,TextChanged,InsertEnter * silent! checktime
  au BufReadPost,BufWritePost,BufNewFile * call setbufvar(expand('<afile>'), 'statusline_filechanged', 0)
  au FileChangedShell * call setbufvar(expand('<afile>'), 'statusline_filechanged', 1)
  au FileChangedShell * call s:statusline_update(mode() =~? '^[ir]')  " triggers after
  au BufEnter,TextChanged * call s:statusline_update(mode() =~? '^[ir]')
  au InsertEnter * call s:statusline_update(1)
  au InsertLeave * call s:statusline_update(0)
augroup END

" Public functions used to fill the statusline.
" Note: Add public relative path function for dotfiles repo
function! RelativePath(...) abort
  return call('s:relative_path', a:000)
endfunction
function! StatusRight() abort
  return s:statusline_loc()
endfunction
function! StatusLeft() abort
  let line = ''
  let funcs = ['s:statusline_path', 's:statusline_git', 's:statusline_file', 's:statusline_vim']
  let maxsize = winwidth(0) - strwidth(StatusRight()) - 1
  for ifunc in funcs  " note cannot use function() handles for locals
    let part = call(ifunc, [])
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

" Generate default statusline colors using colorsheme
" Note: This is needed for GUI vim color schemes since they do not use cterm codes. See
" https://vi.stackexchange.com/a/20757/8084 https://stackoverflow.com/a/27870856/4970632
function! s:statusline_color(code, ...) abort
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

" Highlight statusline dependent on various settings
" Note: Redraw required for CmdlineEnter,CmdlinLeave slow for large files and can
" trigger for maps, so leave alone. See: https://github.com/neovim/neovim/issues/7583
function! s:statusline_update(invert) abort
  let name = has('gui_running') ? 'gui' : 'cterm'
  let flag = has('gui_running') ? '#be0119' : 'Red'  " copied from xkcd scarlet
  let gray = has('gui_running') ? s:statusline_color('bg', 1.0) : 'Gray'
  let black = has('gui_running') ? s:statusline_color('bg', 1) : 'Black'
  let white = has('gui_running') ? s:statusline_color('fg', 0) : 'White'
  let none = has('gui_running') ? 'background' : 'None'  " see :help guibg
  if getbufvar('%', 'fugitive_type', '') ==# 'blob'
    let front = black
    let back = flag
  elseif getbufvar('%', 'statusline_filechanged', 0)
    let front = white
    let back = flag
  elseif a:invert  " inverted
    let front = black
    let back = white
  else  " standard
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

" Return path base using gutentags or fugitive
" Note: This shows paths relative to root and with truncated git hashes
function! s:symlink_base(path, ...) abort
  let cwd = getcwd()
  let glob = a:0 ? fnamemodify(a:1, ':p') : expand('~')
  let pairs = []  " matching links
  for head in globpath(glob, '*', 1, 1)
    let base = resolve(head)  " resolve symlinks
    if base ==# head | continue | endif  " not a symlink
    let link_in_cwd = strpart(base, 0, len(cwd)) ==# cwd
    let path_in_link = strpart(a:path, 0, len(base)) ==# base
    if path_in_link && !link_in_cwd
      call add(pairs, [base, head])
    endif
  endfor
  let size = max(map(copy(pairs), 'len(v:val[0])'))
  let idx = indexof(pairs, {_, val -> len(val[0]) == size})
  if idx < 0  " point from working directory
    let base = cwd
    let head = ''
  else  " point from relative-path symlink
    let [base, head] = pairs[idx]
    let head = s:relative_path(head, cwd)
  endif
  return [base, head]
endfunction

" Return path base using $HOME symlinks
" See: https://github.com/vim/vim/issues/4942
function! s:root_base(path) abort
  let bnr = bufnr(a:path)
  let root = getbufvar(bnr, 'gutentags_root', '')  " see also tags.vim
  if empty(root) && exists('*gutentags#get_project_root')
    let root = gutentags#get_project_root(a:path)  " standard gutentags algorithm
  endif
  if empty(root) && exists('*FugitiveExtractGitDir')
    let root = FugitiveExtractGitDir(a:path)  " fallback vim-fugitive algorithm
    let root = empty(root) ? '' : fnamemodify(root, ':h')  " .git head
  endif
  if !empty(root)  " fallback to actual
    let root = substitute(root, '[/\\]$', '', '')  " ensure no trailing slash
    let path_in_cwd = strpart(getcwd(), 0, len(root)) ==# root
    let path_in_root = strpart(a:path, 0, len(root)) ==# root
    let root = path_in_root && !path_in_cwd ? root : ''
  endif
  let [base, head] = s:symlink_base(a:path)
  let root = empty(root) ? '' : fnamemodify(root, ':h')
  return strwidth(base) > strwidth(root) ? [base, head] : [root, '']
endfunction

" Return path relative to root or relative to working directory using '..'
" See: https://stackoverflow.com/a/26650027/4970632
function! s:relative_path(path, ...) abort
  let disk = '^fugitive:[/\\]\{2}'
  let blob = '\.git[/\\]\{2}\x\{33}\(\x\{7}\)'
  let path = substitute(a:path, disk, '', '')
  let path = substitute(path, blob, '\1', '')
  let path = fnamemodify(expand(path), ':p')
  let path = substitute(path, '[/\\]$', '', '')
  let [base, head, tail] = ['', '', '']
  if a:0 && type(a:1)  " relative to arbitrary directory
    let base = substitute(a:1, '[/\\]$', '', '')
  elseif a:0 && !type(a:1) && a:1  " e.g. repo/foo/bar/baz for git repository
    let [base, head] = s:root_base(path)
  else  " e.g. ~/icloud for icloud files or getcwd() otherwise
    let [base, head] = s:symlink_base(path)
  endif
  while strpart(path, 0, len(base)) !=# base  " false if link was fond
    let ibase = fnamemodify(base, ':h')
    if ibase ==# base  " root or disk
      let [base, head] = ['', ''] | break
    endif
    let base = ibase  " ascend to shared directory
    let head .= (empty(head) ? '' : s:slash_str) . '..'
  endwhile
  if strpart(expand('~'), 0, len(base)) ==# base
    let base = ''  " base inside or above home
  endif
  if empty(base)  " fallback expansion
    return fnamemodify(path, ':~:.')
  endif
  let tail = strpart(path, len(base))  " then remove slash
  let tail = substitute(tail, '\(^[/\\]*\|[/\\]*$\)', '', 'g')
  let head .= !empty(head) && !empty(tail) ? s:slash_str : ''
  return head . tail
endfunction

" Current path name relative to base with truncated segments
" See: https://github.com/blueyed/dotfiles/blob/master/vimrc#L396
function! s:statusline_path() abort
  let raw = '' " used for symlink check
  let path = s:relative_path(expand('%'), 1)
  let parts = split(path, '\ze\' . s:slash_str)
  for idx in range(len(parts))
    let part = parts[idx]
    let maxlen = s:maxlen_part + (idx > 0)
    let raw .= part  " unfiltered parts
    if strwidth(part) > maxlen && strwidth(path) > s:maxlen_raw
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
    if getftype(expand(raw)) ==# 'link'  " symlink redirect
      if s:slash_str ==# part[0]
        let part = s:slash_str . '↪' . part[1:]
      else
        let part = '↪' . part
      endif
      let parts[idx] = part
    endif
  endfor
  let path = join(parts, '')
  let path .= &modified ? '*' : ''
  let width = strwidth(path)
  if width > s:maxlen_abs  " including multi-byte characters e.g. symlink
    let path = strcharpart(path, width - s:maxlen_abs)
    let path = '·' . path
  endif | return path
endfunction

" Return column number, current line number, total line number, and percentage
" Include 'current' tag kind and name from lukelbd/vim-tags or preservim/tagbar
function! s:statusline_loc() abort
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

" Return git branch and unstaged modification hunks
" Note: This was adapated from tpope/vim-fugitive and airblade/vim-gitgutter
function! s:statusline_git() abort
  if !exists('*FugitiveHead')
    let info = ''
  else  " show length-7 hash if head is detached
    let info = FugitiveHead(7)
  endif
  if !exists('*GitGutterGetHunkSummary')
    let [acnt, mcnt, rcnt] = [0, 0, 0]
  else  " show non-empty change types
    let [acnt, mcnt, rcnt] = GitGutterGetHunkSummary()
  endif
  for [key, cnt] in [['+', acnt], ['~', mcnt], ['-', rcnt]]
    let info .= empty(cnt) ? '' : key . cnt
  endfor
  return empty(info) ? info : ' (' . info . ')'
endfunction

" Return file type and size in human-readable units
" Note: Returns zero bytes for buffers not associated with files
function! s:statusline_file() abort
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

" Return mode including paste mode indicator and session status
" Previously tested existence of ObsessionStatus but this caused race condition
function! s:statusline_vim() abort
  let code = &l:spelllang
  if &l:paste  " 'p' for paste
    let info = 'P'
  elseif &l:iminsert  " 'l' for langmap
    let info = 'L'
  else  " default mode
    let info = get(s:mode_strings, mode(), '?')
  endif
  if &l:foldenable && &l:foldlevel < 10
    let info .= ':Z' . (&l:foldlevel + 1)
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
