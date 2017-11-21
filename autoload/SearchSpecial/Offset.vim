" SearchSpecial/Offset.vim: Generic functions to handle search offsets.
"
" DEPENDENCIES:
"
" Copyright: (C) 2017 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
let s:save_cpo = &cpo
set cpo&vim

function! SearchSpecial#Offset#GetAction( offset )
    if empty(a:offset)
	return ['', '', '']
    elseif a:offset =~# '^;'
	return s:GetSecondSearchAction(a:offset[1:])
    endif

    let [l:anchor, l:sign, l:count] = matchlist(a:offset, '^\([esb]\)\?\%(\([+-]\?\)\(\d*\)\)')[1:3]
    let l:count = (empty(l:count) ? 0 : str2nr(l:count))
    let l:count1 = max([1, l:count])
    let l:isBackward = (l:sign ==# '-')

    if empty(l:anchor)
	return [
	\   '',
	\   '',
	\   printf('call cursor(line(".") %s %s, 1)', (l:isBackward ? '-' : '+'), l:count1)
	\]
    else
	return [
	\   (l:anchor ==# 'e' ? 'e' : ''),
	\   (l:isBackward ? s:GetForwardOffset(l:count) : s:GetBackwardOffset(l:count)),
	\   (l:isBackward ? s:GetBackwardOffset(l:count) : s:GetForwardOffset(l:count)),
	\]
    endif
endfunction
function! s:GetForwardOffset( count )
    return (a:count < 1 ? '' : printf('call search("\\%%#\\_.\\{,%d\\}", "eW")', a:count + 1))
endfunction
function! s:GetBackwardOffset( count )
    return (a:count < 1 ? '' : printf('call search("\\_.\\{,%d\\}\\%%#", "bW")', a:count))
endfunction

function! s:GetSecondSearchAction()
    " TODO
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
