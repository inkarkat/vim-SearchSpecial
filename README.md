SEARCH SPECIAL
===============================================================================
_by Ingo Karkat_

DESCRIPTION
------------------------------------------------------------------------------

The built-in search via /, n, and N does its job. But sometimes, it
would be nice to have a custom search that is limited to a certain range, or
the first match in a line, or certain syntax groups, or a search that doesn't
open folds. This plugin offers generic functions that can be used to easily
build such custom search mappings for special searches. A predicate function
can specify which matches are skipped, and options control the behavior with
regards to folding and jumps.

### SEE ALSO

- The SearchRepeat.vim ([vimscript #4949](http://www.vim.org/scripts/script.php?script_id=4949)) plugin provides an integration
  facility for custom searches (such as ones implemented via
  SearchSpecial.vim) that repeats the last type of used search via n/N, and
  can list all defined custom searches.

The following custom searches use this plugin:

- SearchAsQuickJump.vim ([vimscript #5619](http://www.vim.org/scripts/script.php?script_id=5619)):
  Quick search without affecting 'hlsearch', search pattern and history.

USAGE
------------------------------------------------------------------------------

    This plugin defines several functions. The following is an overview; you'll
    find the details directly in the implementation files in the .vim/autoload/
    directory.

    SearchSpecial#SearchWithout( searchPattern, isBackward, Predicate, predicateId, predicateDescription, count, ... )

    The main helper function that jumps to the next match of a:searchPattern,
    skipping all those matches where a:Predicate returns false.

EXAMPLE
------------------------------------------------------------------------------

Here's a simple search mapping that emulates the default search (because it
doesn't pass a predicate that limits the matches, nor are there any options):

    nnoremap <silent> ,n
    \   :<C-u>if SearchSpecial#SearchWithout(@/, 0, '', 'default', '', v:count1)<Bar>
    \   if &hlsearch<Bar>set hlsearch<Bar>endif<Bar>
    \   else<Bar>echoerr ingo#err#Get()<Bar>endif<CR>

The 'hlsearch' handling cannot be done in a function; and any "Pattern not
found" error is raised directly from the mapping; that's the boilerplate code
at the end of the mapping.

INSTALLATION
------------------------------------------------------------------------------

The code is hosted in a Git repo at
    https://github.com/inkarkat/vim-SearchSpecial
You can use your favorite plugin manager, or "git clone" into a directory used
for Vim packages. Releases are on the "stable" branch, the latest unstable
development snapshot on "master".

This script is also packaged as a vimball. If you have the "gunzip"
decompressor in your PATH, simply edit the \*.vmb.gz package in Vim; otherwise,
decompress the archive first, e.g. using WinZip. Inside Vim, install by
sourcing the vimball or via the :UseVimball command.

    vim SearchSpecial*.vmb.gz
    :so %

To uninstall, use the :RmVimball command.

### DEPENDENCIES

- Requires Vim 7.0 or higher.
- Requires the ingo-library.vim plugin ([vimscript #4433](http://www.vim.org/scripts/script.php?script_id=4433)), version 1.019 or
  higher.

CONTRIBUTING
------------------------------------------------------------------------------

Report any bugs, send patches, or suggest features via the issue tracker at
https://github.com/inkarkat/vim-SearchSpecial/issues or email (address below).

HISTORY
------------------------------------------------------------------------------

##### 1.21    RELEASEME
- Add a:options.isShowPredicateSkips flag to include the number of skipped
  matches in the predicate prefix. Depending on the type of a:Predicate, this
  information can be useful to the user, and handling this here avoids
  cumbersome counting and overriding of a:EchoFunction inside the client
  plugin.
- BUG: A search error when a search offset is used prints the literal List
  [{pattern}, {offset}] instead of just {pattern}.

##### 1.20    08-Dec-2017
- ENH: Extract search {offset} from the last search history element and apply
  it after jumping if the passed a:searchPattern is also the last element in
  the history. This can be turned off via a:options.isAutoOffset. The
  implementation even handles another search (//;), even though this is only
  considered for an initial search, not for subsequent searches (only the last
  pattern is stored in @/, not the full search sequence).
- a:options.EchoFunction and a:options.ErrorFunction now get supplied
  a:searchPattern which is either a String of a List of [searchPattern,
  searchOffset] if such is specified (via a:options.isAutoOffset).
- ENH: Add a:options.searchOffset to allow clients set the search offset.

##### 1.10    19-Nov-2017
- ENH: Allow to configure the echoing of successful matches via
  a:options.EchoFunction.
- ENH: Allow to configure the error messages when there are no matches via
  a:options.ErrorFunction.
- ENH: Allow to return more search information via a:options.isReturnMoreInfo.
- ENH: Allow to run commands before and after the first search via
  a:options.BeforeFirstSearchAction and a:options.AfterFirstSearchAction.
  Needed for SearchManyLocations.vim.
- ENH: Allow to run commands after each search via
  a:options.AfterAnySearchAction and after the final search jump via
  a:options.AfterFinalSearchAction. Allow to specify
  a:options.additionalSearchFlags. Both required for SearchAsQuickJump.vim
  offset enhancement.

##### 1.00    24-May-2014
- First published version.

##### 0.01    05-May-2009
- Started development.

------------------------------------------------------------------------------
Copyright: (C) 2009-2022 Ingo Karkat -
The [VIM LICENSE](http://vimdoc.sourceforge.net/htmldoc/uganda.html#license) applies to this plugin.

Maintainer:     Ingo Karkat &lt;ingo@karkat.de&gt;
