scriptencoding utf-8

if exists('g:loaded_img_search')
    finish
endif
let g:loaded_img_search = 1

nnoremap <silent> <Esc>i img_search#search_image('normal')<CR>
nnoremap <silent> <Esc>b img_search#show_prev_image()<CR>
nnoremap <silent> <Esc>n img_search#show_next_image()<CR>
nnoremap <silent> <Esc>j img_search#clear_image()<CR>

xnoremap <silent> <Esc>i img_search#search_image('visual')<CR>
