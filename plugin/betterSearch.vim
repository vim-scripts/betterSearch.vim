" ============================================================================
" File:        betterSearch.vim
" Description: provide better search functionality in vim
" Maintainer:  Ng Khian Nam
" Email:       ngkhiannam@gmail.com 
" Last Change: 24 September 2012
" License:     We grant permission to use, copy modify, distribute, and sell this
"              software for any purpose without fee, provided that the above copyright
"              notice and this text are not removed. We make no guarantee about the
"              suitability of this software for any purpose and we are not liable
"              for any damages resulting from its use. Further, we are under no
"              obligation to maintain or extend this software. It is provided on an
"              "as is" basis without any expressed or implied warranty.
" ============================================================================
let s:betterSearch_version = '0.0.1'

" initialization {{{

if v:version < 700
    echoerr "Need Vim version >= 7 "
    finish
endif

if exists('loaded_BetterSearch')
    finish
endif
let loaded_BetterSearch = 1
let s:next_buf_number = 1
let s:content_window_nr = 0
let s:isHighlightOn = 1
let s:isCopyToClipboard = 0
let s:search_token_copy = []
let s:pattern_name = ['String', 'Number', 'Function', 'Keyword', 'Directory', 'Type', 'rubyRegexpDelimiter', 'PmenuSel', 'MatchParen', 'rubyStringDelimiter', 'javaDocSeeTag']
" content window and search window mapping, for the use of switching between 
" window
let s:win_mapping = {}

" === command === "
command! -n=0 -bar BetterSearchPromptOn :call s:BetterSearchPrompt()
command! -n=0 -bar BetterSearchVisualSelect :exe "normal! gvy" <CR> :call s:BetterSearch("<C-R>"")
command! -n=0 -bar BetterSearchSwitchWin :call s:SwitchBetweenWin()
command! -n=1 -bar BetterSearchHighlightLimit :let g:BetterSearchTotalLine=<args>
command! -n=0 -bar BetterSearchHighlighToggle :let s:isHighlightOn=!s:isHighlightOn
command! -n=0 -bar BetterSearchCopyToClipBoard :let s:isCopyToClipboard=!s:isCopyToClipboard

function s:SetDefaultVariable(name, default)
    if !exists(a:name)
        let {a:name} = a:default
    endif
endfunction

call s:SetDefaultVariable("g:BetterSearchMapHelp", "?")
call s:SetDefaultVariable("g:BetterSearchMapHighlightSearch", "h")
call s:SetDefaultVariable("g:BetterSearchTotalLine", 5000)


" }}}

" function {{{
function s:SwitchBetweenWin()
    let s:current_buf_nr = bufnr("")
    if has_key(s:win_mapping, s:current_buf_nr)
        let l:jump_win = bufwinnr(s:win_mapping[s:current_buf_nr])
        exe l:jump_win."wincmd w"
    else
        echo "buffer ".s:current_buf_nr." not found"
    endif
endfunction

function s:GoToLine()
    let lineNum = matchstr(getline("."), '^ *[[:digit:]]\+')
    if lineNum != ""
        call s:SwitchBetweenWin()
        exe ":".lineNum
    endif
endfunction

function s:BetterSearchBindMapping()
    exec "nnoremap <silent> <buffer> <2-leftmouse> :call <SID>GoToLine()<cr>"
    exec "nnoremap <silent> <buffer> <cr> :call <SID>GoToLine()<cr>"
    exec "nnoremap <silent> <buffer> ". g:BetterSearchMapHelp ." :call <SID>displayHelp()<cr>"
    exec "nnoremap <silent> <buffer> ". g:BetterSearchMapHighlightSearch ." :call <SID>HighlightSearchWord()<cr>"
endfunction

" --- help description ---
function s:displayHelp()
    exe "vnew"
    setlocal buftype=nofile
    setlocal bufhidden=wipe
    setlocal noswapfile
    setlocal nobuflisted
    exec "nnoremap <silent> <buffer> ". g:BetterSearchMapHelp ." :q<cr>"

    let l:help_text = "Press ". g:BetterSearchMapHelp ." to close this help window\n\n"
    let l:help_text = l:help_text . "Press <ENTER> on that particular line to jump to the content window.\n"
    let l:help_text = l:help_text . "':BetterSearchSwitchWin'       - to switch between the 'Search Window' and the 'Content Window'\n"
    let l:help_text = l:help_text . "':BetterSearchVisualSelect'    - to search based on the visually selected word\n"
    let l:help_text = l:help_text . "':BetterSearchHighlighToggle'  - to toggle keyword highlight on off (default is on)\n"
    let l:help_text = l:help_text . "':BetterSearchHighlightLimit'  - to toggle line limit to switch off keyword highlight, for efficiency purpose, \n"
    let l:help_text = l:help_text . "                               - especially for large matched, default is 5000 line\n"
    let l:help_text = l:help_text . "':BetterSearchCopyToClipBoard' - to toggle whether to save to the search words to clipboard, default is off\n\n"
    let l:help_text = l:help_text . "Suggest to map following in .vimrc, e.g: \n"
    let l:help_text = l:help_text . "nnoremap <A-F7> :BetterSearchPromptOn<CR>\n"
    let l:help_text = l:help_text . "vnoremap <A-F7> :BetterSearchVisualSelect<CR>\n"
    let l:help_text = l:help_text . "nnoremap <A-w>  :BetterSearchSwitchWin<CR>\n"
    let @g = l:help_text
    exe "1put! g"
    setlocal nomodifiable
endfunction


" --- for search highlight toggle on/off ---
function s:HighlightSearchWord()
    "syn match search1
    let s:isHighlightOn = !s:isHighlightOn
    call s:BetterSearchSyntaxHighlight(s:search_token_copy)
endfunction

" --- for search highlight toggle 
function s:BetterSearchSyntaxHighlight(search_token)
    execute "syn match helpText #Press ". g:BetterSearchMapHelp ." for help#"
    execute "hi link helpText Comment"
    let l:index = 0
    if s:isHighlightOn && (line('$') < g:BetterSearchTotalLine)
        echo "search highlight on"
        while index < len(a:search_token)
            if (index < len(s:pattern_name))
                execute "syn match search_word".index. " #". a:search_token[index] ."#"
                execute "hi link search_word".index. " ".s:pattern_name[index]
                let l:index = l:index + 1
            endif
        endwhile
    elseif !s:isHighlightOn
        echo "search highlight off"
        while index < len(a:search_token)
            if (index < len(s:pattern_name))
                "execute "syn match search_word".index. " #". a:search_token[index] ."#"
                execute "hi link search_word".index. " Normal"
                let l:index = l:index + 1
            endif
        endwhile
    endif
endfunction

" --- main function of search ----
function s:BetterSearch(...)
	let list_len = a:0
	let str=""
	let cur_line = line(".")
	if list_len !=0
		" if argument list is not empty
        if ( match(a:1, "|"))
            let str = ""
            let ori_str = a:1
            let l:search_token = []
            for myword in split(a:1, '|')
                call add(l:search_token, myword)
                if (str!="")
                    " add the escape '|'
                    let str = str.'\|'.myword
                else
                    let str = myword
                endif
                "echom "str is ". str
            endfor
        else
		    let str=a:1
        endif

        if s:isCopyToClipboard
            let @+=a:1
        endif
        "echo "search term ".str
	else
		let str=expand("<cword>")
	endif
	" clear register g
	let @g="\"  Press ". g:BetterSearchMapHelp ." for help\n\n"
	let @g=@g."search term: \n". ori_str."\n\n"
	" redirect global search output to register g
	silent exe "redir @g>>"
	silent exe "g /". str
	silent exe "redir END"
    if ( list_len == 2)
        call cursor(a:2, 1)
    else
        let s:content_window_nr = bufnr("")
        let s:next_buf_number += 1
        " open a new buffer
        exe "new BetterSearch". s:next_buf_number
        " set this buffer attribute
        setlocal buftype=nofile
        setlocal bufhidden=wipe
        setlocal noswapfile
        setlocal nobuflisted
        call s:BetterSearchBindMapping()
        let s:win_mapping[s:content_window_nr]=bufnr("")
        let s:win_mapping[bufnr("")]=s:content_window_nr

    endif
    " paste the content of register g before line 1
    exe "1put! g"
    " ---- syntax highlight ----
    call s:BetterSearchSyntaxHighlight(l:search_token)
    let s:search_token_copy = copy(l:search_token)
    setlocal nomodifiable
endfunction

" --- give the user a prmopt to key the search ----
" --- each search term can be separate by a bar '|' ----
" --- e.g.: search_term1|search_term2|search_term3 ----
function s:BetterSearchPrompt()
	let mm = inputdialog("search term", "", "cancel pressed")
    if mm != "" && mm != "cancel pressed"
        :exe 'silent call s:BetterSearch(mm)'
        if s:isCopyToClipboard
            :let @"=mm
        endif
    else
        if mm != "cancel pressed"
            :exe 'silent call s:BetterSearch(expand("<cword>"))'
        endif
    endif
endfunction
" }}}

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"                                                                              "
" vim:foldmethod=marker:tabstop=4
"                                                                              "
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

