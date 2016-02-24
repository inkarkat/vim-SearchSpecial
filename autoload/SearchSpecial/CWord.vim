" SearchSpecial/CWord.vim: Generic functions for the matches of the current word.
"
" DEPENDENCIES:
"
" Copyright: (C) 2009-2014 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.00.001	12-Jul-2009	file creation

function! SearchSpecial#CWord#GetStartPosition( pattern )
"*******************************************************************************
"* PURPOSE:
"   If a:pattern matches in the current line so that the cursor is positioned
"   inside the match, returns the start position of the match.
"* ASSUMPTIONS / PRECONDITIONS:
"	? List of any external variable, control, or other element whose state affects this procedure.
"* EFFECTS / POSTCONDITIONS:
"	? List of the procedure's effect on each external variable, control, or other element.
"* INPUTS:
"   a:pattern	Regular expression to match.
"* RETURN VALUES:
"   [line, column] of the start position of the match if the cursor is inside
"   the match, [0, 0] otherwise.
"*******************************************************************************
    let l:line = getline('.')

    " Note: col() is 1-based, all other indexes zero-based!
    let l:start = 0
    while l:start >= 0 && l:start < len(l:line) && l:start < col('.')
	let l:begin = match(l:line, a:pattern, l:start)
	let l:end = matchend(l:line, a:pattern, l:start)
	if l:begin < col('.') && col('.') <= l:end
	    return [line('.'), (l:begin + 1)]
	endif
	let l:start = l:end
    endwhile
    return [0, 0]
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
