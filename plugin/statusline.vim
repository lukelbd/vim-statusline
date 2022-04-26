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

" Global settings and highlight groups
set showcmd  " show command line below statusline
set noshowmode  " no mode indicator in command line (use the statusline instead)
set laststatus=2  " always show status line even in last window
set statusline=%{StatusLeft()}\ %=\ %{StatusRight()}
highlight StatusLine ctermbg=Black ctermfg=White cterm=NONE

" Autocommands for highlighting
" Note: Autocommands with same name are called in order (try adding echom commands)
" Note: For some reason statusline_color must always search b:statusline_filechanged
" and trying to be clever by passing expand('<afile>') then using getbufvar will color
" the statusline in the wrong window when a file is changed. No idea why.
function! s:statusline_color(insert) abort
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
  au BufEnter,TextChanged,InsertEnter * silent! checktime
  au BufReadPost,BufWritePost,BufNewFile * call setbufvar(expand('<afile>'), 'statusline_filechanged', 0)
  au FileChangedShell * call setbufvar(expand('<afile>'), 'statusline_filechanged', 1)
  au FileChangedShell * call s:statusline_color(mode() =~# '^i')
  au BufEnter,TextChanged * call s:statusline_color(mode() =~# '^i')
  au InsertEnter * call s:statusline_color(1)
  au InsertLeave * call s:statusline_color(0)
augroup END

" Shorten a given filename by truncating path segments.
" https://github.com/blueyed/dotfiles/blob/master/vimrc#L396
function! s:file_name() abort
  let bufname = @%
  let maxlen = 20
  if bufname =~ $HOME  " replace home directory with tilde
    let bufname = '~' . split(bufname, $HOME)[-1]
  endif
  let maxlen_of_parts = 7  " truncate path parts (directories and filename)
  let maxlen_of_subparts = 7  " truncate path pieces (seperated by dot/hypen/underscore)
  let s:slash = exists('+shellslash') ? (&shellslash ? '/' : '\') : '/'
  let parts = split(bufname, '\ze[' . escape(s:slash, '\') . ']')
  let i = 0
  let n = len(parts)
  let wholepath = '' " used for symlink check
  for i in range(len(parts))
    if len(bufname) > maxlen && len(parts[i]) > maxlen_of_parts  " shorten path
      let subparts = split(parts[i], '\ze[._]')  " groups to truncate
      echom string(subparts)
      if len(subparts) > 1
        let parts[i] = ''
        for string in subparts  " e.g. ta_Amon_LONG-MODEL-NAME.nc
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
    let wholepath .= parts[i]
  endfor
  return join(parts, '')
endfunction
function! FileName() abort
  return s:file_name()
endfunction

" Current git branch using fugitive
function! s:git_branch() abort
  if exists(':Git') && !empty(fugitive#head())
    return ' (' . fugitive#head() . ')'
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
  let string = get(s:mode_names, mode(), 'Unknown')
  if &paste  " paste mode indicator
    let string .= ':Paste'
  endif
  if &iminsert > 0 || &imsearch > 0
    let string .= ':LangMap'
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
  let maxlen = 15  " can be changed
  if !exists('*tags#current_tag')
    return ''
  endif
  let string = tags#current_tag()
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
  return ' ['
    \ . col('.')
    \ . ':' . line('.') . '/' . line('$')
    \ . '] ('
    \ . (100 * line('.') / line('$')) . '%'
    \ . ')'
endfunction

" The driver functions used to fill the statusline
function! StatusLeft() abort
  let names = [
    \ 's:file_name', 's:git_branch', 's:file_info',
    \ 's:vim_mode', 's:vim_spell', 's:vim_session'
    \ ]
  let line = ''
  let maxlen = winwidth(0) - len(StatusRight()) - 1
  for name in names  " note cannot use function() handles for locals
    exe 'let part = ' name . '()'
    if len(line . part) > maxlen | return line | endif
    let line .= part
  endfor
  return line
endfunction
function! StatusRight() abort
  return s:loc_tag() . s:loc_info()
endfunction
