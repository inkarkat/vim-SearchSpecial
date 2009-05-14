" SearchSpecial.vim: Generic functions for special search modes. 
"
" DEPENDENCIES:
"   - EchoWithoutScrolling.vim autoload script. 
"
" Copyright: (C) 2009 by Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'. 
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS 
"	003	07-May-2009	The view (especially the horizontal window view)
"				may have been changed by moving to unsuitable
"				matches. Save and restore the original view. 
"	002	05-May-2009	BF: Endless loop when there are matches, but the
"				predicate is never true. Now checking against
"				first match and restoring cursor position if the
"				match is re-encountered. 
"				Added a:predicateDescription to distinguish
"				between no matches and no suitable matches in
"				error message. 
"				Implemented [count] number of search
"				repetitions. 
"	001	05-May-2009	Split off generic function from
"				SearchWithoutClosedFolds.vim. 
"				file creation

function! s:WrapMessage( message )
    if &shortmess !~# 's'
	echohl WarningMsg
	let v:warningmsg = a:message
	echomsg v:warningmsg
	echohl None
    else
	call EchoWithoutScrolling#Echo( '/' . @/ )
    endif
endfunction
function! s:ErrorMessage( ... )
    echohl ErrorMsg
    let v:errmsg = (a:0 > 0 && ! empty(a:1) ? a:1 : 'E486: Pattern not found: ' . @/)
    echomsg v:errmsg
    echohl None
endfunction

function! SearchSpecial#SearchWithout( isBackward, Predicate, predicateDescription, count )
"*******************************************************************************
"* PURPOSE:
"   Search for the next match of the current search pattern (@/), skipping all
"   those matches where a:Predicate returns false. 
"
"* ASSUMPTIONS / PRECONDITIONS:
"	? List of any external variable, control, or other element whose state affects this procedure.
"* EFFECTS / POSTCONDITIONS:
"   Positions cursor on the next match. 
"
"* INPUTS:
"   a:isBackward    Flag whether to do backward search. 
"   a:Predicate	    Function reference that is called on each match location;
"		    must take a Boolean isBackward argument and return whether
"		    the match should be included. 
"   a:predicateDescription  Text describing the predicate selector. If not
"			    empty, this is included in the error message when no
"			    suitable matches were found. E.g. "outside closed
"			    folds". 
"   a:count	    Number of search repetitions, as in the [count]n command. 
"
"* RETURN VALUES: 
"   0 if pattern not found, 1 if a suitable match was found and jumped to. 
"*******************************************************************************
    let l:save_cursor = getpos('.')

    let l:count = a:count
    let l:isWrapped = 0
    let l:save_view = winsaveview()

    while l:count > 0
	let [l:prevLine, l:prevCol] = [line('.'), col('.')]
	let [l:firstMatchLine, l:firstMatchCol] = [0, 0]
	let l:line = 0
	while l:line == 0 || ! call(a:Predicate, [a:isBackward])
	    " Search for next match, 'wrapscan' applies. 
	    let [l:line, l:col] = searchpos( @/, (a:isBackward ? 'b' : '') )
	    if l:line == 0
		" There are no (more) matches. 
		break
	    elseif [l:firstMatchLine, l:firstMatchCol] == [0, 0]
		" Record the first match to avoid endless loop. 
		let [l:firstMatchLine, l:firstMatchCol] = [l:line, l:col]
	    elseif [l:firstMatchLine, l:firstMatchCol] == [l:line, l:col]
		" We've already encountered this match; this means that there is at
		" least one match, but the predicate is never true: All matches
		" should be skipped.  
		let l:line = -1
		call setpos('.', l:save_cursor)
		break
	    endif
	endwhile
	if l:line > 0
	    " We found a suitable match. 
	    let l:count -= 1

	    " Note: No need to check 'wrapscan'; the wrapping can only occur if
	    " 'wrapscan' is actually on. 
	    if ! a:isBackward && (l:prevLine > l:line || l:prevLine == l:line && l:prevCol >= l:col)
		let l:isWrapped = 1
	    elseif a:isBackward && (l:prevLine < l:line || l:prevLine == l:line && l:prevCol <= l:col)
		let l:isWrapped = -1
	    endif
	else
	    break
	endif
    endwhile

    if l:line > 0
	normal! zv

	if l:isWrapped == 1
	    call s:WrapMessage('search hit BOTTOM, continuing at TOP')
	elseif l:isWrapped == -1
	    call s:WrapMessage('search hit TOP, continuing at BOTTOM')
	else
	    call EchoWithoutScrolling#Echo( '/' . @/ )
	endif

	" The view (especially the horizontal window view) may have been changed
	" by moving to unsuitable matches. This may irritate the user, who is
	" not aware that the implementation also searched invisible parts of the
	" buffer. 
	" To fix that, we memorize the match position, restore the view to the
	" state before the search, then jump straight back to the match
	" position. 
	let l:matchPosition = getpos('.')
	call winrestview(l:save_view)
	call setpos('.', l:matchPosition)

	return 1
    else
	if l:line < 0 && ! empty(a:predicateDescription)
	    call s:ErrorMessage('Pattern not found ' . a:predicateDescription . ': ' . @/)
	else
	    call s:ErrorMessage()
	endif

	" The view may have been changed by moving through unsuitable matches.
	" Restore the view to the state before the search. 
	call winrestview(l:save_view)

	return 0
    endif
endfunction

" vim: set sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
