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

let s:offsetExpr =  '\([esb]\)\?\%(\([+-]\?\)\(\d*\)\)'

function! SearchSpecial#Offset#GetAction( offset )
    if empty(a:offset)
	return ['', '', '']
    elseif a:offset =~# '^;'
	return s:GetSecondSearchAction(a:offset[1:])
    endif

    let l:parse = matchlist(a:offset, '^' . s:offsetExpr . '$')[1:3]
    if empty(l:parse)
	return ['', '', '']
    endif

    let [l:anchor, l:sign, l:count] = l:parse
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

function! s:GetSecondSearchAction( offset )
    if empty(a:offset) | return '' | endif
    let l:remainder = a:offset

    let l:commands = []
    while ! empty(l:remainder)
	let l:parse =
	\   matchlist(l:remainder, '^\([/?]\)\(\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!\%(\1\@!\&.\)*\)\%(\1' .
	\       '\(' . substitute(s:offsetExpr, '\\(', '\\%(', 'g') . '\)\?\%(;\(.*\)\)\?\)\?$'
	\   )
	if ! empty(l:parse)
	    let [l:direction, l:pattern, l:offset, l:remainder] = l:parse[1:4]
	else
	    let l:parse =
	    \   matchlist(l:remainder, '^\([/?]\)\(\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!\%(\1\@!\&.\)*\)\%(\1.*\)\?$')
	    if ! empty(l:parse)
		let [l:direction, l:pattern] = l:parse[1:2]
		let [l:offset, l:remainder] = ['', '']
	    else
		break
	    endif
	endif

	let l:flags = ''
	if ! empty(l:offset)
	    let [l:flags, l:ignored, l:offsetCommand] = SearchSpecial#Offset#GetAction(l:offset)
	endif

	let l:searchCommand = printf('call search(%s, %s)', string(l:pattern), string(l:flags . (l:direction ==# '?' ? 'b' : '')))
	call add(l:commands, l:searchCommand)
	if ! empty(l:offset) | call add(l:commands, l:offsetCommand) | endif
    endwhile

    " With a simple command concatenation with "|", a failing search would not
    " stop further searches. To achieve that, turn the commands into a (lazily
    " evaluated) expression of and-ed branches, which will only be evaluated
    " until the first search returns 0. A little complication is that the offset
    " commands are either search(), which returns 0 on failure, or cursor(),
    " which returns 0 on success.
    return 'let dummy = ' . join(
    \   map(
    \       l:commands,
    \       'substitute(v:val, "^call \\ze\\(\\w\\+\\)", "\\=(submatch(1) ==# \"cursor\" ? \"!\" : \"\")", "")'
    \   ),
    \   ' && '
    \)
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
