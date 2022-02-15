"------------------------------------------------------------------------------"
" Name:   statusline.vim
" Author: Luke Davis (lukelbd@gmail.com)
" Date:   2018-09-03
" A simple, minimal, black-and-white statusline that helps keep focus on the
" content and syntax coloring in the *document*.
"------------------------------------------------------------------------------
" Script variable for mode
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

" Autocommand
" Todo: Fix tagbar current tag issues
" Note: expand('<afile>') is required but expand('%') is not
" Note: autocmds with same name are called in order (try adding echom commands)
function! s:statusline_color(buffer, insert)
  let cterm = 'NONE'
  if getbufvar(a:buffer, 'statusline_filechanged', 0)
    let ctermfg = 'White'
    let ctermbg = 'Red'
  elseif a:insert
    let ctermfg = 'Black'
    let ctermbg = 'White'
  else
    let ctermfg = 'White'
    let ctermbg = 'Black'
  endif
  exe 'hi StatusLine ctermbg=' . ctermbg . ' ctermfg=' . ctermfg . ' cterm=' . cterm
endfunction
augroup statusline_color
  au!
  au BufEnter,TextChanged,InsertEnter * silent! checktime
  au BufReadPost,BufWritePost,BufNewFile * call setbufvar(expand('<afile>'), 'statusline_filechanged', 0)
  au FileChangedShell * call setbufvar(expand('<afile>'), 'statusline_filechanged', 1)
  au FileChangedShell * call s:statusline_color(expand('<afile>'), mode() =~# '^i')
  au BufEnter,TextChanged * call s:statusline_color('%', mode() =~# '^i')
  au InsertEnter * call s:statusline_color('%', 1)
  au InsertLeave * call s:statusline_color('%', 0)
augroup END

" Shorten a given filename by truncating path segments.
" https://github.com/blueyed/dotfiles/blob/master/vimrc#L396
function! PrintName()
  let bufname = @%
  let maxlen = 20
  if bufname =~ $HOME  " replace home directory with tilde
    let bufname = '~' . split(bufname, $HOME)[-1]
  endif
  let maxlen_of_parts = 7  " truncate path parts (directories and filename)
  let maxlen_of_subparts = 5  " truncate path pieces (seperated by dot/hypen/underscore)
  let s:slash = exists('+shellslash') ? (&shellslash ? '/' : '\') : '/'
  let parts = split(bufname, '\ze[' . escape(s:slash, '\') . ']')
  let i = 0
  let n = len(parts)
  let wholepath = '' " used for symlink check
  while i < n
    let wholepath .= parts[i]
    if i < n - 1 && len(bufname) > maxlen && len(parts[i]) > maxlen_of_parts  " shorten path
      let strings = split(parts[i], '\ze[._-]')  " see if there are dots or hyphens to truncate
      if len(strings) > 1
        let parts[i] = ''
        for string in strings  " e.g. 'vim-pkg-debian' => 'v-p-d…'
          if len(string) > maxlen_of_subparts - 1
            let parts[i] .= string[0:maxlen_of_subparts - 2] . '·'
          else
            let parts[i] .= string
          endif
        endfor
      else
        let parts[i] = parts[i][0:maxlen_of_parts - 2] . '·'
      endif
    endif
    if getftype(wholepath) ==# 'link'  " indicator if this part of filename is symlink
      if parts[i][0] == s:slash
        let parts[i] = parts[i][0] . '↪ ./' . parts[i][1:]
      else
        let parts[i] = '↪ ./' . parts[i]
      endif
    endif
    let i += 1
  endwhile
  return join(parts, '')
endfunction

" Current git branch using fugitive
function! PrintBranch()
  if exists(':Git') && !empty(fugitive#head())
    return '  (' . fugitive#head() . ')'
  else
    return ''
  endif
endfunction

" Current file type and size in human-readable units
function! PrintInfo()
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
  return '  [' . string . ']'
endfunction

" Current mode including indicator if in paste mode
function! PrintMode()
  let string = get(s:mode_names, mode(), 'Unknown')
  if &paste  " paste mode indicator
    let string .= ':Paste'
  endif
  return '  [' . string . ']'
endfunction

" Whether spell checking is US or UK english
function! PrintSpell()
  if &spell
    if &spelllang ==? 'en_us'
      return '  [US]'
    elseif &spelllang ==? 'en_gb'
      return '  [UK]'
    else
      return '  [??]'
    endif
  else
    return ''
  endif
endfunction

" Whether so-called lmaps are enabled (corresponds to caps lock in personal setup)
function! PrintLang()
  if &iminsert > 0 || &imsearch > 0
    return '  [LangMap]'
  else
    return ''
  endif
endfunction

" Current column number, current line number, total line number, and percentage
function! PrintLoc()
  return '  ['
    \ . col('.')
    \ . ':' . line('.') . '/' . line('$')
    \ . '] ('
    \ . (100 * line('.') / line('$')) . '%'
    \ . ')'
endfunction

" Tags using tagbar
" Note: See :help tagbar-statusline for info
function! PrintTag()
  let maxlen = 15  " can change this
  if !exists('*tagbar#currenttag')
    return ''
  endif
  let string = tagbar#currenttag('%s', '', 'f')  " f is for full hiearchy (incl. parent)
  if empty(string)
    return ''
  endif
  if len(string) >= maxlen
    let string = string[:maxlen-1] . '···'
  endif
  return '  [' . string . ']'
endfunction

" Settings and highlight groups
set showcmd  " show command line below statusline
set noshowmode  " no mode indicator in command line (use the statusline instead)
set laststatus=2  " always show status line even in last window
let &statusline = ''
let &statusline .= '%{PrintName()}'  " current buffer's file name
let &statusline .= '%{PrintBranch()}'  " git branch info
let &statusline .= '%{PrintInfo()}'  " output buffer's file size
let &statusline .= '%{PrintMode()}'  " normal/insert mode
let &statusline .= '%{PrintSpell()}'  " show language setting: UK english or US enlish
let &statusline .= '%{PrintLang()}'  " check if language maps enabled
if exists('*ObsessionStatus') | let &statusline .= ' %{ObsessionStatus()}' | endif
let &statusline .= '%='  " right side of statusline, and perserve space between sides
let &statusline .= '%{PrintTag()}'  " ctags tag under cursor
let &statusline .= '%{PrintLoc()}'  " cursor's current line, total lines, and percentage
highlight StatusLine ctermbg=Black ctermfg=White cterm=NONE
