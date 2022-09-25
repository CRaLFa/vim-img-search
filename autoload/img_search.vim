scriptencoding utf-8

let s:TMP_DIR = expand('~/.vim/img-search')
let s:URL_FILE = s:TMP_DIR .. '/url.txt'
let s:REG_TMP = '"'

let s:window = {}
let s:imgidx = 1

let s:save_cpo = &cpo
set cpo&vim

function! img_search#search_image(mode) abort
    if !exists('g:img_search_api_key') || !exists('g:img_search_engine_id')
        echo 'Both g:img_search_api_key and g:img_search_engine_id are required'
        return
    endif

    let l:searchword = ''
    if a:mode ==# 'normal'
        let l:searchword = expand('<cword>')
    elseif a:mode ==# 'visual'
        let l:searchword = s:get_selected_word()
    else
        echoerr 'Invalid mode'
    endif

    if empty(l:searchword)
        return
    endif

    let l:urls = s:get_image_urls(l:searchword)
    call s:save_url_file(l:searchword, l:urls)

    let s:imgidx = 1
    call s:show_image()
endfunction

function! img_search#clear_image() abort
    if empty(s:window)
        return
    endif

    call echoraw(printf("\x1b[%d;%dH\x1b[J", s:window.row, s:window.col))
    call win_execute(s:window.id, 'close')
    redraw

    let s:window = {}
endfunction

function! img_search#show_prev_image() abort
    if s:imgidx <= 1
        echo 'No image'
        return
    endif

    let s:imgidx -= 1

    call img_search#clear_image()
    call s:show_image()
endfunction

function! img_search#show_next_image() abort
    if s:imgidx > 10
        echo 'No image'
        return
    endif

    let s:imgidx += 1

    call img_search#clear_image()
    call s:show_image()
endfunction

function! s:show_image() abort
    if !filereadable(s:URL_FILE)
        return
    endif

    let l:urls = readfile(s:URL_FILE)
    let l:url = get(l:urls, s:imgidx, '')

    if empty(l:url)
        echo 'No image'
        return
    endif

    call setreg(s:REG_TMP, l:url)

    let l:sixelfile = printf('%s/%d.sixel', s:TMP_DIR, s:imgidx)
    let l:sixel = ''

    if filereadable(l:sixelfile)
        let l:sixel = join(readfile(l:sixelfile), "\n")
    else
        let l:maxwidth = exists('g:img_search_max_width') ? g:img_search_max_width : 480
        let l:maxheight = exists('g:img_search_max_height') ? g:img_search_max_height : 270

        let l:sixel = system(printf("set -o pipefail; curl -s '%s' | convert - -resize '%dx%d>' jpg:- | img2sixel",
            \ l:url, l:maxwidth, l:maxheight))
        if v:shell_error
            echo 'Cannot show image'
            return
        endif

        call writefile([l:sixel], l:sixelfile)
    endif

    let l:winname = printf('%s (%d／%d)', trim(get(l:urls, 0, '')), s:imgidx, len(l:urls) - 1)
    let s:window = s:open_window(l:winname)

    call echoraw(printf("\x1b[%d;%dH%s", s:window.row, s:window.col, l:sixel))
endfunction

function! s:get_selected_word() abort
    execute 'normal! gv"' .. s:REG_TMP .. 'y'
    return substitute(trim(getreg(s:REG_TMP), " \t"), '[\r\n]\+', ' ', 'g')
endfunction

function! s:get_image_urls(query) abort
    let l:encodedquery = trim(system('jq -Rr @uri', a:query))
    let l:url = printf('https://www.googleapis.com/customsearch/v1?key=%s&cx=%s&searchType=image&q=%s',
        \ g:img_search_api_key, g:img_search_engine_id, l:encodedquery)

    try
        let l:res = json_decode(system(printf("curl -s '%s'", l:url)))
        let l:links = map(l:res.items, 'v:val.link')
        return filter(l:links, 'match(tolower(v:val), ''\.\(png\|jpg\|jpeg\)$'') >= 0')
    catch
        echoerr v:exception
    endtry

    return []
endfunction

function! s:save_url_file(searchword, urls) abort
    if !isdirectory(s:TMP_DIR)
        call mkdir(s:TMP_DIR, 'p')
    endif

    call map(split(glob(s:TMP_DIR .. '/*.sixel'), "\n"), 'delete(v:val)')

    call insert(a:urls, a:searchword)
    call writefile(a:urls, s:URL_FILE)
endfunction

function! s:open_window(winname) abort
    execute 'silent new +set\ nonumber ' .. a:winname

    let l:winid = win_getid()
    let l:pos = screenpos(l:winid, 1, 1)

    silent! wincmd p
    redraw

    return #{
    \   id: l:winid,
    \   row: l:pos.row,
    \   col: l:pos.col,
    \ }
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
