" SearchSpecial.vim: Generic functions for special search modes.
"
" DEPENDENCIES:
"   - SearchSpecial.vim autoload script
"
" Copyright: (C) 2009-2014 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.00.001	30-May-2009	file creation

" Default highlighting for the special search type.
" You can override this by defining / linking the 'SearchSpecialSearchType'
" highlight group before this script is sourced.
highlight def link SearchSpecialSearchType MoreMsg

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
