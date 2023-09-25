"------------------------------------------------------------------------------
" Author: Luke Davis (lukelbd@gmail.com)
" Date:   2018-09-03
" A minimal, informative, black-and-white statusline that helps keep focus
" on the content in each window and integrates with other useful plugins.
"------------------------------------------------------------------------------
" Global settings
scriptencoding utf-8  " required for s:mode_names
highlight StatusLine ctermbg=Black ctermfg=White cterm=None
set showcmd  " show command line below statusline
set noshowmode  " no mode indicator in command line (use the statusline instead)
set laststatus=2  " always show status line even in last window
set statusline=%{StatusLeft()}\ %=\ %{StatusRight()}

" Script variables
let s:path_slash = exists('+shellslash') ? (&shellslash ? '/' : '\') : '/'
let s:maxlen_raw = 20
let s:maxlen_trunc = 50
let s:maxlen_parts = 7  " truncate path parts (directories and filename)
let s:maxlen_subs = 7  " truncate path pieces (seperated by dot/hypen/underscore)
let s:mode_names = {
  \ 'n':  'Normal',
  \ 'no': 'N-Operator Pending',
  \ 'v':  'Visual',
  \ 'V' : 'V-Line',
  \ '': 'V-Block',
  \ 's':  'Select',
  \ 'S' : 'S-Line',
  \ '': 'S-Block',
  \ 'i':  'Insert',
  \ 'R' : 'Replace',
  \ 'Rv': 'V-Replace',
  \ 'c':  'Command',
  \ 'r' : 'Prompt',
  \ 'cv': 'Vim Ex',
  \ 'ce': 'Ex',
  \ 'rm': 'More',
  \ 'r?': 'Confirm',
  \ '!' : 'Shell',
  \ 't':  'Terminal',
  \ }

" Get automatic statusline colors
" Note: This is needed for GUI vim color schemes since they do not use cterm codes.
" Also some schemes use named colors so have to convert into hex by appending '#'.
" See: https://stackoverflow.com/a/27870856/4970632
" See: https://vi.stackexchange.com/a/20757/8084
function! s:default_color(code, ...) abort
  let hex = synIDattr(hlID('Normal'), a:code . '#')
  if empty(hex) || hex[0] !=# '#' | return | endif  " unexpected output
  let shade = a:0 ? a:1 ? 0.3 : 0.0 : 0.0  " shade toward neutral gray
  let color = '#'  " default hex color
  for idx in range(1, 5, 2)
    " vint: -ProhibitUsingUndeclaredVariable
    let value = str2nr(hex[idx:idx + 1], 16)
    let value = value - shade * (value - 128)
    let color .= printf('%02x', float2nr(value))
  endfor
  return color
endfunction

" Autocommands for highlighting
" Note: Redraw required for CmdlineEnter,CmdlinLeave slow for large files and can
" trigger for maps, so leave alone. See: https://github.com/neovim/neovim/issues/7583
" Note: For some reason statusline_color must always search b:statusline_filechanged
" and trying to be clever by passing expand('<afile>') then using getbufvar will color
" the statusline in the wrong window when a file is changed. No idea why.
function! s:statusline_color(highlight) abort
  let s = has('gui_running') ? 'gui' : 'cterm'
  let flag = has('gui_running') ? '#be0119' : 'Red'  " copied from xkcd scarlet
  let black = has('gui_running') ? s:default_color('bg', 1) : 'Black'
  let white = has('gui_running') ? s:default_color('fg', 0) : 'White'
  if getbufvar('%', 'statusline_filechanged', 0)
    let fgcolor = white
    let bgcolor = flag
  elseif a:highlight
    let fgcolor = black
    let bgcolor = white
  else
    let fgcolor = white
    let bgcolor = black
  endif
  let colors = s . 'bg=' . bgcolor . ' ' . s . 'fg=' . fgcolor . ' ' . s . '=None'
  exe 'highlight StatusLine ' . colors
  if mode() =~? '^c' | redraw | endif
endfunction
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

" Get path relative to working directory using '..'
" See: https://stackoverflow.com/a/26650027/4970632
" See: https://docs.python.org/3/library/os.path.html#os.path.relpath
function! s:relative_path(arg) abort
  let dots = ''
  let path = fnamemodify(a:arg, ':p')
  let common = getcwd()
  while path ==# substitute(path, escape(common, '~'), '', '')
    let parent = fnamemodify(common, ':h')
    if parent ==# common  " unsure if possible
      return a:arg  " return original path
    endif
    let dots = '..' . (empty(dots) ? '' : '/' . dots)
    let common = parent
  endwhile
  let forward = substitute(path, escape(common, '~'), '', '')
  if !empty(dots) && !empty(forward)
    return dots . forward
  elseif !empty(forward)
    return forward[1:]
  endif
endfunction

" Shorten a given filename by truncating path segments.
" https://github.com/blueyed/dotfiles/blob/master/vimrc#L396
function! s:path_name() abort
  let rawname = '' " used for symlink check
  let bufname = s:relative_path(@%)
  let parts = split(bufname, '\ze[' . escape(s:path_slash, '\') . ']')
  for idx in range(len(parts))
    let rawname .= parts[idx]  " unfiltered parts
    if len(bufname) > s:maxlen_raw && len(parts[idx]) > s:maxlen_parts  " shorten path
      let subparts = split(parts[idx], '\ze[._]')  " groups to truncate
      if len(subparts) > 1
        let parts[idx] = ''
        for string in subparts  " e.g. ta_Amon_LONG-MODEL-NAME.nc
          if len(string) > s:maxlen_subs - 1
            let parts[idx] .= string[0:s:maxlen_subs - 2] . '·'
          else
            let parts[idx] .= string
          endif
        endfor
      else
        let parts[idx] = parts[idx][0:s:maxlen_parts - 2] . '·'
      endif
    endif
    if getftype(rawname) ==# 'link'  " indicator if this part of filename is symlink
      if s:path_slash ==# parts[idx][0]
        let parts[idx] = s:path_slash . '↪ ' . parts[idx][1:]
      else
        let parts[idx] = '↪ ' . parts[idx]
      endif
    endif
  endfor
  let truncname = join(parts, '')
  if len(truncname) > s:maxlen_trunc
    " vint: -ProhibitUsingUndeclaredVariable
    let truncname = '·' . truncname[1 - s:maxlen_trunc:]
  endif
  return truncname
endfunction

" Current git branch using fugitive
function! s:git_branch() abort
  if exists('*FugitiveHead') && !empty(FugitiveHead())
    return ' (' . FugitiveHead() . ')'
  else
    return ''
  endif
endfunction

" Current file type and size in human-readable units
function! s:file_info() abort
  if empty(&filetype)
    let string = 'unknown:'
  else
    let string = &filetype . ':'
  endif
  let bytes = getfsize(expand('%:p'))
  if bytes >= 1024
    let kbytes = bytes / 1024
  endif
  if exists('kbytes') && kbytes >= 1000
    let mbytes = kbytes / 1000
  endif
  if bytes <= 0
    let string .= 'null'
  endif
  if exists('mbytes')
    let string .= mbytes . 'MB'
  elseif exists('kbytes')
    let string .= kbytes . 'KB'
  else
    let string .= bytes . 'B'
  endif
  return ' [' . string . ']'
endfunction

" Current mode including indicator if in paste mode
" Note: iminsert and imsearch controls whether lmaps are activated, which
" corresponds to caps lock mode in personal setup.
function! s:vim_mode() abort
  if &paste  " paste mode indicator
    let string = 'Paste'
  elseif exists('b:caps_lock') && b:caps_lock
    let string = 'CapsLock'
  else
    let string = get(s:mode_names, mode(), 'Unknown')
  endif
  return ' [' . string . ']'
endfunction

" Whether spell checking is US or UK english
" Todo: Add other languages?
function! s:vim_spell() abort
  if &spell
    if &spelllang ==? 'en_us'
      return ' [US]'
    elseif &spelllang ==? 'en_gb'
      return ' [UK]'
    else
      return ' [Spell]'
    endif
  else
    return ''
  endif
endfunction

" Print the session status using obsession
" Note: This was adapted from ObsessionStatus. Previously we tested existence
" of ObsessionStatus below but that caused race condition issue.
function! s:vim_session() abort
  if empty(v:this_session)  " should always be set by vim-obsession
    return ''
  elseif exists('g:this_obsession')
    return ' [$]'  " vim-obsession session
  else
    return ' [S]'  " regular vim session
  endif
endfunction

" Tag kind and name using lukelbd/vim-tags
function! s:loc_tag() abort
  let maxlen = 20  " can be changed
  if exists('*tags#current_tag')
    let string = tags#current_tag()
  elseif exists('*tagbar#currenttag')
    let string = tagbar#currenttag()
  else
    let string = ''
  endif
  if empty(string)
    return ''
  endif
  if len(string) >= maxlen
    let string = string[:maxlen - 1] . '···'
  endif
  return ' [' . string . ']'
endfunction

" Current column number, current line number, total line number, and percentage
function! s:loc_info() abort
  if &l:foldenable && &l:foldlevel < 10
    let folds = ':' . &l:foldlevel
  else
    let folds = ''
  endif
  let cursor = col('.') . ':' . line('.') . '/' . line('$')
  let ratio = (100 * line('.') / line('$')) . '%'
  return ' [' . cursor . folds . '] (' . ratio . ')'
endfunction

" Driver functions used to fill the statusline
" Also make useful 'path' function public
function! RelativePath(...) abort
  return call('s:relative_path', a:000)
endfunction
function! StatusRight() abort
  return s:loc_tag() . s:loc_info()
endfunction
function! StatusLeft() abort
  let names = [
    \ 's:path_name', 's:git_branch', 's:file_info',
    \ 's:vim_mode', 's:vim_spell', 's:vim_session'
    \ ]
  let line = ''
  let maxlen = winwidth(0) - len(StatusRight()) - 1
  for name in names  " note cannot use function() handles for locals
    let part = call(name, [])
    if len(line . part) > maxlen
      return line
    endif
    let line .= part
  endfor
  return line
endfunction
