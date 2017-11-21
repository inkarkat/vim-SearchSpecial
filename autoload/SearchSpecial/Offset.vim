" SearchSpecial/Offset.vim: Generic functions to handle search offsets.
"
" DEPENDENCIES:
"
" Copyright: (C) 2017 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

function! SearchSpecial#Offset#GetAction( offset )
    if empty(a:offset)
	return ['', '']
    elseif a:offset =~# '^;'
	return s:GetSecondSearchAction(a:offset[1:])
    endif

    let [l:anchor, l:num] = matchlist(a:offset, '^\([esb]\)\?\([+-]\?\d*\)')[1:2]
    let l:num = (empty(l:num) ? 1 : str2nr(l:num))

    if empty(l:anchor)
	return ['', printf('call cursor(line(".") + %s, 1)', l:num)]
    else
	return [
	\   (l:anchor ==# 'e' ? 'e' : ''),
	\   (l:num < 0 ?
	\       printf('call search("\\_.\\{,%d\\}\\%%#", "bW")', -1 * l:num) :
	\       printf('call search("\\%%#\\_.\\{,%d\\}", "eW")', l:num)
	\   )
	\]
    endif
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
