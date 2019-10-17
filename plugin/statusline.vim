"------------------------------------------------------------------------------"
" Name:   statusline.vim
" Author: Luke Davis (lukelbd@gmail.com)
" Date:   2018-09-03
" A simple, minimal, black-and-white statusline that helps keep focus on the
" content and syntax coloring in the *document*.
"------------------------------------------------------------------------------
" Options and statusline funcs
set showcmd " command line below statusline
set noshowmode
set laststatus=2 " always show
let g:nostatus = 'tagbar,nerdtree'
let &stl = ''
let &stl .= '%{ShortName()}'     " current buffer's file name
let &stl .= '%{Git()}'           " output buffer's file size
let &stl .= '%{FileInfo()}'      " output buffer's file size
let &stl .= '%{PrintMode()}'     " normal/insert mode
let &stl .= '%{PrintLanguage()}' " show language setting: UK english or US enlish
let &stl .= '%{CapsLock()}'      " check if language maps enabled
let &stl .= '%='            " right side of statusline, and perserve space between sides
let &stl .= '%{Tag()}'      " ctags tag under cursor
let &stl .= '%{Location()}' " cursor's current line, total lines, and percentage

" Define all the different modes
" Show whether in pastemode
function! PrintMode()
  if &ft && g:nostatus =~? &ft
    return ''
  endif
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
  if &ft && g:nostatus =~? &ft
    return ''
  endif
  if &iminsert
    return '  [CapsLock]'
  else
    return ''
  endif
endfunction

" Git branch
function! Git()
  if exists('*fugitive#head') && fugitive#head() != ''
    return '  (' . fugitive#head() . ')'
  else
    return ''
  endif
endfunction

" Shorten a given filename by truncating path segments.
" https://github.com/blueyed/dotfiles/blob/master/vimrc#L396
function! ShortName() " {{{
  if &ft && g:nostatus =~? &ft
    return ''
  endif
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
  let s:PS = exists('+shellslash') ? (&shellslash ? '/' : '\') : "/"
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
    if getftype(wholepath) == 'link'
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
  if &ft && g:nostatus =~? &ft
    return ''
  endif
  " File type
  if &ft=='' | let string = 'unknown:'
  else | let string = &ft . ':'
  endif
  " File size
  let bytes = getfsize(expand('%:p'))
  if (bytes >= 1024)
    let kbytes = bytes / 1024
  endif
  if (exists('kbytes') && kbytes >= 1000)
    let mbytes = kbytes / 1000
  endif
  if bytes <= 0
    let string .= 'null'
  endif
  if (exists('mbytes'))
    let string .= (mbytes . 'MB')
  elseif (exists('kbytes'))
    let string .= (kbytes . 'KB')
  else
    let string .= (bytes . 'B')
  endif
  if &ft && g:nostatus =~? &ft
    return ''
  endif
  return '  [' . string . ']'
endfunction " }}}

" Whether UK english (e.g. Nature), or U.S. english
function! PrintLanguage()
  if &ft && g:nostatus =~? &ft
    return ''
  endif
  if &spell
    if &spelllang=='en_us'
      return '  [US]'
    elseif &spelllang=='en_gb'
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
  if &ft && g:nostatus =~? &ft
    return ''
  endif
  return '  [' . line('.') . '/' . line('$') . '] (' . (100*line('.')/line('$')) . '%)' " current line and percentage
endfunction

" Tags using tagbar
function! Tag()
  let maxlen = 10 " can change this
  if &ft && g:nostatus =~? &ft
    return ''
  endif
  if !exists('*tagbar#currenttag') | return '' | endif
  let string = tagbar#currenttag('%s','')
  if string == '' | return '' | endif
  if len(string) >= maxlen | let string = string[:maxlen-1] . '···' | endif
  return '  [' . string . ']'
endfunction

