" SearchSpecial.vim: Generic functions for special search modes.
"
" DEPENDENCIES:
"   - ingo/avoidprompt.vim autoload script
"   - ingo/err.vim autoload script
"   - ingo/msg.vim autoload script
"   - ingo/pos.vim autoload script
"
" Copyright: (C) 2009-2014 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.00.014	02-May-2014	BUG: Used wrong variable name.
"	013	30-Apr-2014	Use ingo/pos.vim.
"	012	26-Apr-2014	Do not print the pattern not found error
"				message; instead, use ingo#err#Set() and let
"				clients :echoerr it.
"				Use ingo#msg#WarningMsg().
"   	011	07-Jun-2013	Move EchoWithoutScrolling.vim into ingo-library.
"	010	17-Jul-2009	BF: Wrap message disappeared when jumping to a
"				match in a closed fold (so that the restore of
"				the view caused scrolling). Now echoing all
"				messages after winrestview().
"				Changed interface to allow passing additional
"				options in a dictionary.
"				Added 'isStarSearch' option for
"				SearchAlternateStar and SearchAsQuickJump
"				plugins.
"				Added 'keepfolds' option to avoid opening the
"				fold at the search result.
"				Now adding the original cursor position to the
"				jump list, like the built-in [/?*#nN] commands.
"				This can be disabled via the 'keepjumps' option.
"	009	12-Jul-2009	ENH: a:Predicate can now be empty to accept
"				every match. This avoids having to pass in a
"				dummy predicate (for SearchAlternateStar and
"				SearchAsQuickJump plugins).
"				ENH: Added optional a:currentMatchPosition
"				argument to support jumping to text entities
"				like <cword>, where the current entity should be
"				skipped during a backward search. Modified
"				algorithm according to s:Search() in mark.vim.
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
	call ingo#avoidprompt#EchoAsSingleLine(l:searchIndicator . a:searchPattern)
    else
	call s:EchoPredicateId(a:predicateId)
	echon ingo#avoidprompt#Truncate(ingo#avoidprompt#TranslateLineBreaks(l:searchIndicator . a:searchPattern), strlen(a:predicateId))
    endif
endfunction

function! SearchSpecial#WrapMessage( predicateId, searchPattern, isBackward, ... )
    if &shortmess !~# 's'
	let l:message = (a:0 ? a:1 : (a:isBackward ? 'search hit TOP, continuing at BOTTOM' : 'search hit BOTTOM, continuing at TOP'))
	call ingo#msg#WarningMsg(a:predicateId . ' ' . l:message)
    else
	call SearchSpecial#EchoSearchPattern(a:predicateId, a:searchPattern, a:isBackward)
    endif
endfunction
function! SearchSpecial#ErrorMessage( searchPattern, isBackward, ... )
    " No need for ingo#avoidprompt#TranslateLineBreaks() here, :echomsg
    " translates everything on its own.

    let l:hasDescription = (a:0 > 0 && ! empty(a:1))
    let l:searchDescription = (l:hasDescription ? ' ' . a:1 : '')
    if &wrapscan
	let l:errorMessage = printf('%sPattern not found%s: %s',
	\   (l:hasDescription ? '' : 'E486: '),
	\   l:searchDescription,
	\   a:searchPattern
	\)
    else
	let l:errorMessage = printf('%ssearch%s hit %s without match for: %s',
	\   (l:hasDescription ? '' : (a:isBackward ? 'E384: ' : 'E385: ')),
	\   l:searchDescription,
	\   (a:isBackward ? 'TOP' : 'BOTTOM'), a:searchPattern
	\)
    endif

    call ingo#err#Set(l:errorMessage)
endfunction

function! SearchSpecial#SearchWithout( searchPattern, isBackward, Predicate, predicateId, predicateDescription, count, ... )
"*******************************************************************************
"* PURPOSE:
"   Search for the next match of the a:searchPattern, skipping all
"   those matches where a:Predicate returns false.
"
"* ASSUMPTIONS / PRECONDITIONS:
"   This function uses search(), so the 'ignorecase', 'smartcase' and 'magic'
"   settings are obeyed.
"
"* EFFECTS / POSTCONDITIONS:
"   Positions cursor on the next match.
"   Prints wrap warning message or used search pattern.
"   Does not print "pattern not found" error messages; the client should do this
"   (via :echoerr ingo#err#Get()) if the function returns 0.
"
"* INPUTS:
"   a:searchPattern Regular expression to search for.
"   a:isBackward    Flag whether to do backward search.
"   a:Predicate	    Function reference that is called on each match location;
"		    must take a Boolean isBackward argument and return whether
"		    the match should be included. Or pass an empty value to
"		    accept all matches.
"   a:predicateId   Identifier text for the predicate selection. If not empty,
"		    this is prepended to echo'ed search pattern, wrap and error
"		    messages (to indicate the current type of special search).
"   a:predicateDescription  Text describing the predicate selector. If not
"			    empty, this is included in the error message when no
"			    suitable matches were found. E.g. "outside closed
"			    folds".
"   a:count	    Number of search repetitions, as in the [count]n command.
"   Optional:
"   You can pass in a dictionary with advanced options; these keys are
"   supported:
"   currentMatchPosition    In case the search should jump to text entities like
"			    <cword> (i.e. in an emulation of the '*' and '#'
"			    commands), the current entity should be skipped
"			    during a backward search. Pass the start position of
"			    the current text entity the cursor is on, and the
"			    function will skip the current entity. Omit this
"			    argument or pass an empty list (or a position which
"			    is always invalid like [0, 0]) to include the
"			    current entity in a search.
"   isStarSearch	    The search function in here uses the 'ignorecase'
"			    and 'smartcase' settings. For searches similar to
"			    the '*' and '#' commands, the 'smartcase' setting
"			    doesn't make sense: Executed on an all-lowercase
"			    <cword>, a case-insensitive search would be started,
"			    but when repeated on a <cword> containing uppercase
"			    characters, the search would suddenly change to
"			    being case-sensitive. Set this flag to ignore
"			    'smartcase' during the search.
"   keepfolds		    When set, the fold state is kept. By default, any
"			    folds at the search result are opened, like the
"			    built-in [/?*#nN] commands.
"   keepjumps		    When set, the previous cursor position is not added
"			    to the jump list. By default, the original cursor
"			    position is added to the jump list, like the
"			    built-in [/?*#nN] commands.
"
"* RETURN VALUES:
"   0 if pattern not found; ingo#err#Get() then has the appropriate error
"   message, 1 if a suitable match was found and jumped to.
"*******************************************************************************
    let l:save_view = winsaveview()

    let l:count = a:count

    let l:options = (a:0 ? a:1 : {})
    let l:currentMatchPosition = get(l:options, 'currentMatchPosition', [])
    let l:isStarSearch = get(l:options, 'isStarSearch', 0)
    if l:isStarSearch
	let l:save_smartcase = &smartcase
	set nosmartcase
    endif

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

		if a:isBackward && [l:line, l:col] == l:currentMatchPosition && l:count == a:count && ! l:isExcludedMatch
		    " On a search in backward direction, the first match is the
		    " start of the current match (if the cursor was positioned
		    " inside the current match text but not at the start of the
		    " match text).
		    " In case of an entity search, this is not considered the
		    " first match. The match text is one entity; if the cursor
		    " is positioned anywhere inside the match text, the match
		    " text is considered the current match. The built-in '*' and
		    " '#' commands behave in the same way; the entire <cword>
		    " text is considered the current match, and jumps move
		    " outside that text.

		    " Thus, the search is retried (i.e. l:count is increased),
		    " but only if this was the first match (l:count == a:count);
		    " repeat visits during wrapping around count as a regular
		    " match. The search also must not be retried when this is
		    " the first match, but we've been here before (i.e.
		    " l:isExcludedMatch is set): This means that there is only
		    " the current match in the buffer, and we must break out of
		    " the loop and indicate that no other match was found.
		    let l:count += 1

		    " The l:isExcludedMatch flag is set so if the final match
		    " cannot be reached, the original cursor position is
		    " restored. This flag also allows us to detect whether we've
		    " been here before, which is checked above.
		    let l:isExcludedMatch = 1
		endif
	    elseif [l:firstMatchLine, l:firstMatchCol] == [l:line, l:col]
		" We've already encountered this match; this means that there is at
		" least one match, but the predicate is never true: All matches
		" should be skipped.
		let l:line = 0
		break
	    endif

	    if empty(a:Predicate) || call(a:Predicate, [a:isBackward])
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
	    if ! a:isBackward && ingo#pos#IsOnOrAfter([l:prevLine, l:prevCol], [l:line, l:col])
		let l:isWrapped = 1
	    elseif a:isBackward && ingo#pos#IsOnOrBefore([l:prevLine, l:prevCol], [l:line, l:col])
		let l:isWrapped = 1
	    endif
	else
	    " We've failed; no more matches were found.
	    break
	endif
    endwhile

    let l:isFound = (l:line > 0)
    if l:isFound
	let l:matchPosition = getpos('.')

	if ! get(l:options, 'keepfolds', 0)
	    " Open fold at the search result, like the built-in commands.
	    normal! zv
	endif

	" The view (especially the horizontal window view) may have been changed
	" by moving to unsuitable matches. This may irritate the user, who is
	" not aware that the implementation also searched invisible parts of the
	" buffer.
	" To fix that, we memorize the match position, restore the view to the
	" state before the search, then jump straight back to the match
	" position. This also allows us to set a jump only if a match was found.
	" (:call setpos("''", ...) doesn't work in Vim 7.2)
	call winrestview(l:save_view)

	if ! get(l:options, 'keepjumps', 0)
	    " Add the original cursor position to the jump list, like the
	    " [/?*#nN] commands.
	    normal! m'
	endif

	call setpos('.', l:matchPosition)

	if l:isWrapped
	    redraw
	    call SearchSpecial#WrapMessage(a:predicateId, a:searchPattern, a:isBackward)
	else
	    call SearchSpecial#EchoSearchPattern(a:predicateId, a:searchPattern, a:isBackward)
	endif
    else
	" The view may have been changed by moving through unsuitable matches.
	" Restore the view to the state before the search.
	call winrestview(l:save_view)

	if l:isExcludedMatch && ! empty(a:predicateDescription)
	    " Notify that there is no a:count'th predicate match; this implies
	    " that there *are* matches at positions excluded by the predicate.
	    call SearchSpecial#ErrorMessage(a:searchPattern, a:isBackward, a:predicateDescription)
	else
	    " No matches at all; show the common error message without
	    " mentioning the predicate.
	    call SearchSpecial#ErrorMessage(a:searchPattern, a:isBackward)
	endif
    endif

    if l:isStarSearch
	let &smartcase = l:save_smartcase
    endif

    return l:isFound
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
