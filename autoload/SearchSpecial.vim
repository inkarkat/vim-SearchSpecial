" SearchSpecial.vim: Generic functions for special search modes.
"
" DEPENDENCIES:
"   - ingo/actions.vim autoload script
"   - ingo/avoidprompt.vim autoload script
"   - ingo/err.vim autoload script
"   - ingo/msg.vim autoload script
"   - ingo/pos.vim autoload script
"
" Copyright: (C) 2009-2017 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
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
function! SearchSpecial#Echo( predicateId, searchPattern, isBackward, isWrapped, lnum, col )
    if a:isWrapped
	redraw
	call SearchSpecial#WrapMessage(a:predicateId, a:searchPattern, a:isBackward)
    else
	call SearchSpecial#EchoSearchPattern(a:predicateId, a:searchPattern, a:isBackward)
    endif
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
"   EchoFunction            Funcref to a function that gets passed (predicateId,
"			    searchPattern, isBackward, isWrapped, lnum, col)
"			    when the current successful match should be echoed.
"   ErrorFunction	    Funcref to a function that gets passed
"			    (searchPattern, isBackward) in case of no matches at
"			    all, and (searchPattern, isBackward,
"			    predicateDescription) in case of no matches selected
"			    by the predicate.
"   isReturnMoreInfo        Flag to return Dictionary of {
"				'isFound': Boolean,
"				'remainingCount': number of matches not found
"			    }
"   BeforeFirstSearchAction Funcref or commands to execute before the first
"			    search is performed.
"   AfterFirstSearchAction  Funcref or commands to execute after the first
"			    search (that satisfies the predicate) has been
"			    performed. Only executed for the first count, not on
"			    subsequent ones.
"   AfterFinalSearchAction  Funcref or commands to execute after the final
"			    search (that satisfies the predicate) has been
"			    performed. Only executed for the final jump that
"			    arrives on the target match, not the intermediate
"			    jumps for counts.
"   AfterAnySearchAction    Funcref or commands to execute after any search
"			    (that satisfies the predicate) jump has been
"			    performed, for all counts.
"   additionalSearchFlags   Additional {flags} to be passed to searchpos(),
"* RETURN VALUES:
"   0 if pattern not found; ingo#err#Get() then has the appropriate error
"   message, 1 if a suitable match was found and jumped to.
"*******************************************************************************
    let l:save_view = winsaveview()

    let l:count = a:count

    let l:options = (a:0 ? a:1 : {})
    let l:currentMatchPosition = get(l:options, 'currentMatchPosition', [])
    let l:Echo = get(l:options, 'EchoFunction', 'SearchSpecial#Echo')
    let l:Error = get(l:options, 'ErrorFunction', 'SearchSpecial#ErrorMessage')
    let l:additionalSearchFlags = get(l:options, 'additionalSearchFlags', '')

    let l:BeforeFirstSearchAction = get(l:options, 'BeforeFirstSearchAction', '')
    let l:AfterFirstSearchAction = get(l:options, 'AfterFirstSearchAction', '')
    let l:AfterFinalSearchAction = get(l:options, 'AfterFinalSearchAction', '')
    let l:AfterAnySearchAction = get(l:options, 'AfterAnySearchAction', '')
    if ! empty(l:BeforeFirstSearchAction)
	call ingo#actions#ExecuteOrFunc(l:BeforeFirstSearchAction)
    endif

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
	    let [l:line, l:col] = searchpos(a:searchPattern, (a:isBackward ? 'b' : '') . l:additionalSearchFlags)
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

	if ! empty(l:AfterFirstSearchAction)
	    call ingo#actions#ExecuteOrFunc(l:AfterFirstSearchAction)
	    let l:AfterFirstSearchAction = ''
	endif
	if ! empty(l:AfterAnySearchAction)
	    call ingo#actions#ExecuteOrFunc(l:AfterAnySearchAction)
	endif

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
	if ! empty(l:AfterFinalSearchAction)
	    call ingo#actions#ExecuteOrFunc(l:AfterFinalSearchAction)
	endif

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

	call call(l:Echo, [a:predicateId, a:searchPattern, a:isBackward, l:isWrapped, l:line, l:matchPosition[2]])
    else
	" The view may have been changed by moving through unsuitable matches.
	" Restore the view to the state before the search.
	call winrestview(l:save_view)

	if l:isExcludedMatch && ! empty(a:predicateDescription)
	    " Notify that there is no a:count'th predicate match; this implies
	    " that there *are* matches at positions excluded by the predicate.
	    call call(l:Error, [a:searchPattern, a:isBackward, a:predicateDescription])
	else
	    " No matches at all; show the common error message without
	    " mentioning the predicate.
	    call call(l:Error, [a:searchPattern, a:isBackward])
	endif
    endif

    if l:isStarSearch
	let &smartcase = l:save_smartcase
    endif

    return (get(l:options, 'isReturnMoreInfo', 0) ? {'isFound': l:isFound, 'remainingCount': l:count} : l:isFound)
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
