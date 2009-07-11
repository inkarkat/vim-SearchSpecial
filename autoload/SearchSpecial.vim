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
"	008	10-Jul-2009	BF: Wrap message vanished (with
"				SearchAlternateStar.vim client) when next match
"				was outside the current view. Now :redraw'ing
"				first. 
"	007	04-Jul-2009	SearchSpecial#ErrorMessage() now takes
"				a:isBackward argument to build proper error
"				message when 'nowrapscan'. The optional argument
"				is now only the search type description, not the
"				entire error message. 
"				Removed superfluous l:save_cursor; the restore
"				of the cursor position when the predicate
"				excludes all matches is already done by
"				winrestview(). 
"				Refactored algorithm to determine whether there
"				were excluded matches: 
"				- The communication whether there were excluded
"				matches is now done via the separate
"				l:isExcludedMatch, not as a magic value of -1
"				for l:line. 
"				- The differentiation now also works with
"				'nowrapscan', because the predicate call has
"				been moved into the while loop and its return
"				value is evaluated for l:isExcludedMatch. 
"	006	31-May-2009	Message to SearchSpecial#WrapMessage() is now
"				optional; the canonical one is generated from
"				a:isBackward. Streamlined
"				SearchSpecial#ErrorMessage() interface. 
"	005	30-May-2009	Changed interface to allow reuse by
"				SearchAlternateStar.vim: Removed hardcoded @/;
"				a:searchPattern must now be passed in. 
"				Changed interface to add (optional) predicateId for
"				easy identification of the current special
"				search type. 
"				BF: Search pattern was always echo'ed with /
"				indicator; now using ? for backward search. 
"				Exposing SearchSpecial#EchoSearchPattern(), 
"				SearchSpecial#WrapMessage() and
"				SearchSpecial#ErrorMessage(). 
"	004	15-May-2009	BF: Translating line breaks in search pattern
"				via EchoWithoutScrolling#TranslateLineBreaks()
"				to avoid echoing only the last part of the
"				search pattern when it contains line breaks. 
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
let s:save_cpo = &cpo
set cpo&vim

function! s:EchoPredicateId( predicateId )
    echohl SearchSpecialSearchType
    echo a:predicateId
    echohl None
endfunction
function! SearchSpecial#EchoSearchPattern( predicateId, searchPattern, isBackward )
    let l:searchIndicator = (a:isBackward ? '?' : '/')
    if empty(a:predicateId)
	call EchoWithoutScrolling#Echo(EchoWithoutScrolling#TranslateLineBreaks(l:searchIndicator . a:searchPattern))
    else
	call s:EchoPredicateId(a:predicateId)
	echon EchoWithoutScrolling#Truncate(EchoWithoutScrolling#TranslateLineBreaks(l:searchIndicator . a:searchPattern), strlen(a:predicateId))
    endif
endfunction

function! SearchSpecial#WrapMessage( predicateId, searchPattern, isBackward, ... )
    if &shortmess !~# 's'
	let l:message = (a:0 ? a:1 : (a:isBackward ? 'search hit TOP, continuing at BOTTOM' : 'search hit BOTTOM, continuing at TOP'))
	echohl WarningMsg
	let v:warningmsg = a:predicateId . ' ' . l:message
	echomsg v:warningmsg
	echohl None
    else
	call SearchSpecial#EchoSearchPattern(a:predicateId, a:searchPattern, a:isBackward)
    endif
endfunction
function! SearchSpecial#ErrorMessage( searchPattern, isBackward, ... )
    " No need for EchoWithoutScrolling#TranslateLineBreaks() here, :echomsg
    " translates everything on its own. 

    let l:hasDescription = (a:0 > 0 && ! empty(a:1))
    let l:searchDescription = (l:hasDescription ? ' ' . a:1 : '')
    if &wrapscan
	let v:errmsg = printf('%sPattern not found%s: %s',
	\   (l:hasDescription ? '' : 'E486: '),
	\   l:searchDescription,
	\   a:searchPattern
	\)
    else
	let v:errmsg = printf('%ssearch%s hit %s without match for: %s',
	\   (l:hasDescription ? '' : (a:isBackward ? 'E384: ' : 'E385: ')),
	\   l:searchDescription,
	\   (a:isBackward ? 'TOP' : 'BOTTOM'), a:searchPattern
	\)
    endif
    echohl ErrorMsg
    echomsg v:errmsg
    echohl None
endfunction

function! SearchSpecial#SearchWithout( searchPattern, isBackward, Predicate, predicateId, predicateDescription, count )
"*******************************************************************************
"* PURPOSE:
"   Search for the next match of the a:searchPattern, skipping all
"   those matches where a:Predicate returns false. 
"
"* ASSUMPTIONS / PRECONDITIONS:
"	? List of any external variable, control, or other element whose state affects this procedure.
"* EFFECTS / POSTCONDITIONS:
"   Positions cursor on the next match. 
"
"* INPUTS:
"   a:searchPattern Regular expression to search for. 
"   a:isBackward    Flag whether to do backward search. 
"   a:Predicate	    Function reference that is called on each match location;
"		    must take a Boolean isBackward argument and return whether
"		    the match should be included. 
"   a:predicateId   Identifier text for the predicate selection. If not empty,
"		    this is prepended to echo'ed search pattern, wrap and error
"		    messages (to indicate the current type of special search). 
"   a:predicateDescription  Text describing the predicate selector. If not
"			    empty, this is included in the error message when no
"			    suitable matches were found. E.g. "outside closed
"			    folds". 
"   a:count	    Number of search repetitions, as in the [count]n command. 
"
"* RETURN VALUES: 
"   0 if pattern not found, 1 if a suitable match was found and jumped to. 
"*******************************************************************************
    let l:save_view = winsaveview()

    let l:count = a:count
    let l:isWrapped = 0
    let l:isExcludedMatch = 0

    while l:count > 0
	let [l:prevLine, l:prevCol] = [line('.'), col('.')]
	let [l:firstMatchLine, l:firstMatchCol] = [0, 0]
	let l:line = 0

	" Search for the next included match while skipping excluded ones. 
	while 1
	    " Search for next match, 'wrapscan' applies. 
	    let [l:line, l:col] = searchpos( a:searchPattern, (a:isBackward ? 'b' : '') )
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
		let l:line = 0
		break
	    endif

	    if call(a:Predicate, [a:isBackward])
		" Okay, this match is included in the search. 
		break
	    else
		" This match is rejected, continue searching. 
		let l:isExcludedMatch = 1
	    endif
	endwhile
	if l:line > 0
	    " We found an accepted match. 
	    let l:count -= 1

	    " Note: No need to check 'wrapscan'; the wrapping can only occur if
	    " 'wrapscan' is actually on. 
	    if ! a:isBackward && (l:prevLine > l:line || l:prevLine == l:line && l:prevCol >= l:col)
		let l:isWrapped = 1
	    elseif a:isBackward && (l:prevLine < l:line || l:prevLine == l:line && l:prevCol <= l:col)
		let l:isWrapped = 1
	    endif
	else
	    " We've failed; no more matches were found. 
	    break
	endif
    endwhile

    if l:line > 0
	normal! zv

	if l:isWrapped
	    redraw
	    call SearchSpecial#WrapMessage(a:predicateId, a:searchPattern, a:isBackward)
	else
	    call SearchSpecial#EchoSearchPattern(a:predicateId, a:searchPattern, a:isBackward)
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
	if l:isExcludedMatch && ! empty(a:predicateDescription)
	    " Notify that there is no a:count'th predicate match; this implies
	    " that there *are* matches at positions excluded by the predicate. 
	    call SearchSpecial#ErrorMessage(a:searchPattern, a:isBackward, a:predicateDescription)
	else
	    " No matches at all; show the common error message without
	    " mentioning the predicate. 
	    call SearchSpecial#ErrorMessage(a:searchPattern, a:isBackward)
	endif

	" The view may have been changed by moving through unsuitable matches.
	" Restore the view to the state before the search. 
	call winrestview(l:save_view)

	return 0
    endif
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
