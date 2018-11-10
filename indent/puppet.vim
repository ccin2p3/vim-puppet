" Vim indent file
" Language: Puppet
" Maintainer:   Todd Zullinger <tmz@pobox.com>
" Last Change:  2009 Aug 19
" vim: set sw=4 sts=4:

if exists("b:did_indent")
    finish
endif
let b:did_indent = 1

setlocal autoindent smartindent
setlocal indentexpr=GetPuppetIndent()
setlocal indentkeys+=0],0)
setlocal formatexpr=puppet#format#Format()

if exists("*GetPuppetIndent")
    finish
endif

" Check if a line is part of an include 'block', e.g.:
"   include foo,
"       bar,
"       baz
function! s:PartOfInclude(lnum)
    let lnum = a:lnum
    while lnum
        let lnum = lnum - 1
        let line = getline(lnum)
        if line !~ ',$'
            break
        endif
        if line =~ '^\s*include\s\+[^,]\+,$'
            return 1
        endif
    endwhile
    return 0
endfunction

function! s:OpenBrace(lnum)
    call cursor(a:lnum, 1)
    return searchpair('{\|\[\|(', '', '}\|\]\|)', 'nbW',
      \ 'synIDattr(synID(line("."), col("."), 0), "name") =~? "comment\\|string"')
endfunction

""
" Get indent number for line, line can be given as params, otherwise function
" use line where cursor is
" @param a:1 (optional) line number in current buffer
" @return integer
function! GetPuppetIndent(...)
    let l:lnum = get(a:, 1, v:lnum)

    let pnum = prevnonblank(l:lnum - 1)
    if pnum == 0
       return 0
    endif

    let line = getline(l:lnum)
    let pline = getline(pnum)
    let ind = indent(pnum)

    " Avoid cases of closing braces or parens on the current line: returning
    " the same indent here would be premature since for that particular case
    " we want to instead get the indent level of the matching opening brace or
    " parenthenses.
    if pline =~ '^\s*#' && line !~ '^\s*\(}\(,\|;\)\?$\|]:\|],\|}]\|];\?$\|)\)'
        return ind
    endif

    " We are inside a multi-line string: if we interfere with indentation here
    " we're actually changing the contents of of the string!
    if synIDattr(synID(l:lnum, 1, 0), 'name') =~? 'string'
        return indent(l:lnum)
    endif

    if pline =~ '\({\|\[\|(\|:\)\s*\(#.*\)\?$'
        let ind += &sw
    elseif pline =~ ';$' && pline !~ '[^:]\+:.*[=+]>.*'
        let ind -= &sw
    elseif pline =~ '^\s*include\s\+.*,$' && pline !~ '[=+]>'
        let ind += &sw
    endif

    if pline !~ ',$' && s:PartOfInclude(pnum)
        let ind -= &sw
    endif

    " Match } }, }; ] ]: ], ]; )
    if line =~ '^\s*\(}\(,\|;\)\?$\|]:\|],\|}]\|];\?$\|)\)'
        let ind = indent(s:OpenBrace(v:lnum))
    endif

    " Don't actually shift over for } else {
    if line =~ '^\s*}\s*els\(e\|if\).*{\s*$'
        let ind -= &sw
    endif
    " Don't indent resources that are one after another with a ->(ordering arrow)
    " file {'somefile':
    "    ...
    " } ->
    "
    " package { 'mycoolpackage':
    "    ...
    " }
    if line =~ '->$'
        let ind -= &sw
    endif


    return ind
endfunction
