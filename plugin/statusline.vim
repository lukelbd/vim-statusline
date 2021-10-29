"------------------------------------------------------------------------------"
" Name:   statusline.vim
" Author: Luke Davis (lukelbd@gmail.com)
" Date:   2018-09-03
" A simple, minimal, black-and-white statusline that helps keep focus on the
" content and syntax coloring in the *document*.
"------------------------------------------------------------------------------
" Autocommand
function! s:statusline_color(insert)
  let cterm = 'NONE'
  if getbufvar('%', 'statusline_filechanged', 0)
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
  au BufEnter,InsertEnter,TextChanged * silent! checktime
  au BufReadPost,BufWritePost,BufNewFile * let b:statusline_filechanged = 0
  au FileChangedShell * call setbufvar(expand('<afile>'), 'statusline_filechanged', 1)
  au BufEnter,TextChanged * call s:statusline_color(mode() =~# '^i')
  au InsertEnter * call s:statusline_color(1)
  au InsertLeave * call s:statusline_color(0)
augroup END

" Define all the different modes
" Show whether in pastemode
function! PrintMode()
  let currentmode = {
    \ 'n':  'Normal',  'no': 'N-Operator Pending',
    \ 'v':  'Visual',  'V' : 'V-Line',  '': 'V-Block',
    \ 's':  'Select',  'S' : 'S-Line',  '': 'S-Block',
    \ 'i':  'Insert',  'R' : 'Replace', 'Rv': 'V-Replace',
    \ 'c':  'Command', 'r' : 'Prompt',
    \ 'cv': 'Vim Ex',  'ce': 'Ex',
    \ 'rm': 'More',    'r?': 'Confirm', '!' : 'shell',
    \ 't':  'Terminal',
    \}
  let string = currentmode[mode()]
  if &paste
    let string .= ':Paste'
  endif
  return '  [' . string . ']'
endfunction

" Caps lock (are language maps enabled?)
" iminsert is the option that enables/disables language remaps (lnoremap) that
" I use for caps-lock, and if it is on, we have turned on the caps-lock remaps
function! CapsLock()
  if &iminsert
    return '  [CapsLock]'
  else
    return ''
  endif
endfunction

" Git branch
function! Git()
  if exists('*fugitive#head') && !empty(fugitive#head())
    return '  (' . fugitive#head() . ')'
  else
    return ''
  endif
endfunction

" Shorten a given filename by truncating path segments.
" https://github.com/blueyed/dotfiles/blob/master/vimrc#L396
function! ShortName() " {{{
  " Necessary args
  let bufname = @%
  let maxlen = 20
  " Replace home directory
  if bufname =~ $HOME
    let bufname = '~' . split(bufname,$HOME)[-1]
  endif
  " Body
  let maxlen_of_parts = 7 " including slash/dot
  let maxlen_of_subparts = 5 " split at dot/hypen/underscore; including split
  let s:PS = exists('+shellslash') ? (&shellslash ? '/' : '\') : '/'
  let parts = split(bufname, '\ze[' . escape(s:PS, '\') . ']')
  let i = 0
  let n = len(parts)
  let wholepath = '' " used for symlink check
  while i < n
    let wholepath .= parts[i]
    " Shorten part, if necessary:
    if i<n-1 && len(bufname) > maxlen && len(parts[i]) > maxlen_of_parts
    " Let's see if there are dots or hyphens to truncate at, e.g.
    " 'vim-pkg-debian' => 'v-p-d…'
    let w = split(parts[i], '\ze[._-]')
    if len(w) > 1
      let parts[i] = ''
      for j in w
      if len(j) > maxlen_of_subparts-1
        let parts[i] .= j[0:maxlen_of_subparts-2] . '·'
      else
        let parts[i] .= j
      endif
      endfor
    else
      let parts[i] = parts[i][0:maxlen_of_parts-2] . '·'
    endif
    endif
    " add indicator if this part of the filename is a symlink
    if getftype(wholepath) ==# 'link'
    if parts[i][0] == s:PS
      let parts[i] = parts[i][0] . '↪ ./' . parts[i][1:]
    else
      let parts[i] = '↪ ./' . parts[i]
    endif
    endif
    let i += 1
  endwhile
  let r = join(parts, '')
  return r
endfunction " }}}

" Find out current buffer's size and output it.
" Also add git branch if available
function! FileInfo() " {{{
  " File type
  if empty(&filetype)
    let string = 'unknown:'
  else
    let string = &filetype . ':'
  endif
  " File size
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
    let string .= (mbytes . 'MB')
  elseif exists('kbytes')
    let string .= (kbytes . 'KB')
  else
    let string .= (bytes . 'B')
  endif
  return '  [' . string . ']'
endfunction " }}}

" Whether UK english (e.g. Nature), or U.S. english
function! PrintLanguage()
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

" Location
function! Location()
  return '  [' . col('.') . ':' . line('.') . '/' . line('$') . '] (' . (100 * line('.') / line('$')) . '%)' " current line and percentage
endfunction

" Tags using tagbar
" Note: See :help tagbar-statusline for info
function! Tag()
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
set showcmd " command line below statusline
set noshowmode
set laststatus=2 " always show
let &statusline = ''
let &statusline .= '%{ShortName()}'     " current buffer's file name
let &statusline .= '%{Git()}'           " output buffer's file size
let &statusline .= '%{FileInfo()}'      " output buffer's file size
let &statusline .= '%{PrintMode()}'     " normal/insert mode
let &statusline .= '%{PrintLanguage()}' " show language setting: UK english or US enlish
let &statusline .= '%{CapsLock()}'      " check if language maps enabled
let &statusline .= '%='            " right side of statusline, and perserve space between sides
let &statusline .= '%{Tag()}'      " ctags tag under cursor
let &statusline .= '%{Location()}' " cursor's current line, total lines, and percentage
highlight StatusLine ctermbg=Black ctermfg=White cterm=NONE
