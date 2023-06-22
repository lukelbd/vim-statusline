"------------------------------------------------------------------------------
" Name:   statusline.vim
" Author: Luke Davis (lukelbd@gmail.com)
" Date:   2018-09-03
" A simple, minimal, black-and-white statusline that helps keep focus on the
" content in each window and integrates with various plugins.
"------------------------------------------------------------------------------
" Script variable for mode
scriptencoding utf-8
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
highlight StatusLine ctermbg=Black ctermfg=White cterm=None

" Autocommands for highlighting
" Note: Redraw required for CmdlineEnter,CmdlinLeave slow for large files and can
" trigger for maps, so leave alone. See: https://github.com/neovim/neovim/issues/7583
" Note: For some reason statusline_color must always search b:statusline_filechanged
" and trying to be clever by passing expand('<afile>') then using getbufvar will color
" the statusline in the wrong window when a file is changed. No idea why.
function! s:statusline_color(highlight) abort
  if getbufvar('%', 'statusline_filechanged', 0)
    let colorfg = 'White'
    let colorbg = 'Red'
  elseif a:highlight
    let colorfg = 'Black'
    let colorbg = 'White'
  else
    let colorfg = 'White'
    let colorbg = 'Black'
  endif
  let cterm = 'ctermbg=' . colorbg . ' ctermfg=' . colorfg . ' cterm=None'
  exe 'highlight StatusLine ' . cterm
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

" Shorten a given filename by truncating path segments.
" https://github.com/blueyed/dotfiles/blob/master/vimrc#L396
function! s:file_name() abort
  let bufname = @%
  let maxlen_of_raw = 20
  let maxlen_of_trunc = 50
  if bufname =~ $HOME  " replace home directory with tilde
    let bufname = '~' . split(bufname, $HOME)[-1]
  endif
  let maxlen_of_parts = 7  " truncate path parts (directories and filename)
  let maxlen_of_subparts = 7  " truncate path pieces (seperated by dot/hypen/underscore)
  let s:slash = exists('+shellslash') ? (&shellslash ? '/' : '\') : '/'
  let parts = split(bufname, '\ze[' . escape(s:slash, '\') . ']')
  let rawname = '' " used for symlink check
  for i in range(len(parts))
    let rawname .= parts[i]  " unfiltered parts
    if len(bufname) > maxlen_of_raw && len(parts[i]) > maxlen_of_parts  " shorten path
      let subparts = split(parts[i], '\ze[._]')  " groups to truncate
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
    if getftype(rawname) ==# 'link'  " indicator if this part of filename is symlink
      if parts[i][0] == s:slash
        let parts[i] = parts[i][0] . '↪ ./' . parts[i][1:]
      else
        let parts[i] = '↪ ./' . parts[i]
      endif
    endif
  endfor
  let truncname = join(parts, '')
  if len(truncname) > maxlen_of_trunc  " vint: -ProhibitUsingUndeclaredVariable
    let truncname = '·' . truncname[1 - maxlen_of_trunc:]
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
  let maxlen = 15  " can be changed
  if exists('*tags#current_tag')
    let string = tags#current_tag()
  elseif exists('*tagbar#currenttag')
    let string = tagbar#currenttag()
  else
    return ''
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
    let part = call(name, [])
    if len(line . part) > maxlen
      return line
    endif
    let line .= part
  endfor
  return line
endfunction
function! StatusRight() abort
  return s:loc_tag() . s:loc_info()
endfunction
