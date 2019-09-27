" new.vim core
if !exists("s:init")
    let s:init = 1
    silent! let s:log = logger#getLogger(expand('<sfile>:t'))

    " Initialize new.vim
    call NewNormalize()
    call new#init()
    let g:vmwRuntime.active = 1

    silent! call s:log.info("============================================")
    silent! call s:log.info("===============new starting=================")
    silent! call s:log.info("============================================")
endif


"----------------------------------------------Imports----------------------------------------------
" Imports from new#util. Can easliy generalize later if need be
fun! s:import(...)
    if a:000 != [v:null] && len(a:000)
        let l:util_snr = new#util#SID()

        for l:fname in a:000
            execute('let s:' . l:fname . ' = function("<SNR>' . l:util_snr . '_' . l:fname . '")')
        endfor

    endif
endfun

fun! new#init()
    call s:import('execute', 'get', 'buf_active', 'wipe_aux_bufs', 'get_active_bufs')
endfun

"------------------------------------------Command backers------------------------------------------
fun! new#close(...)
    for l:target in a:000
        call s:close(l:target)
    endfor
endfun

fun! new#open(...)
    if g:vmwRuntime.wid_main == 0
        let g:vmwRuntime.wid_main = win_getid()
    endif

    if a:000 != [v:null] && len(a:000)
        call call('s:open', a:000)
    endif
endfun

fun! new#toggle(...)
    if a:000 != [v:null] && len(a:000)
        call call('s:toggle', a:000)
    endif
endfun

fun! new#resize(...)
    for l:target in a:000
        call s:resize(l:target)
    endfor
endfun

fun! new#refresh()
    let l:active = new#util#active()

    call call('new#close', l:active)
    call call('new#open', l:active)
endfun

"-----------------------------------------Layout population-----------------------------------------
" Target can be a root model or root model name
" TODO: Indictate the autocmd replacement available for safe_mode. QuitPre autocmd event
fun! s:close(target)
    let l:target = type(a:target) == 1 ? new#util#lookup(a:target) : a:target
    let g:vmwRuntime.request.layout = l:target
    call new#util#traverse(l:target, l:target.clsBfr, function('s:close_helper')
                \, v:true, v:true, v:true, 0, {})

    let l:target.active = 0
    if exists('a:target.clsAftr') && !empty(a:target.clsAftr)
        call s:execute(s:get(a:target.clsAftr))
    endif
endfun


" Because the originating buffer is considered a root model, closing it blindly is undesirable.
fun! s:close_helper(model, type, cache)
    if s:buf_active(a:model["_buf_id"])
        execute(bufwinnr(a:model._buf_id) . 'wincmd w')
        hide
    endif
endfun

fun! s:_check_valid(layout)
    for layout in g:new#layouts
        if a:layout == layout.name
            return 1
        endif
    endfor
    return 0
endfunc

" Opens layout model by name or by dictionary def. DIRECTLY MUTATES DICT
fun! s:open(...) abort
    let l:__func__ = "s.open() "
    let l:cache = {}

    if win_gotoid(g:vmwRuntime.wid_main) == 1
        execute('silent! only')
    else
        silent! call s:log.info(l:__func__, "Backto 'main' window fail with window-id=", g:vmwRuntime.wid_main)
    endif

    for l:t in a:000
        if !s:_check_valid(l:t)
            echoerr "new#open layout '". l:t. "' not exist."
            silent! call s:log.info(l:__func__, "open not exist layout=", l:t)
            return
        else
            let g:vmwRuntime.layoutname = l:t
        endif
    endfor

    if g:new#pop_order == 'both'
        for l:t in a:000
            let l:target = type(l:t) == 1 ? new#util#lookup(l:t) : l:t
            let l:target.active = 1

            let g:vmwRuntime.request.layout = l:target
            call s:execute(s:get(l:target.opnBfr))
            " If both populate layout in one traversal. Else do either vert or horizontal before the other
            call new#util#traverse(l:target, function('s:open_helper_bfr'), function('s:open_helper_aftr')
                        \, v:true, v:true, v:true, 0, l:cache)
            call s:execute(s:get(l:target.opnAftr))
        endfor
    else
        let l:vert = g:new#pop_order == 'vert'

        for l:t in a:000
            let l:target = type(l:t) == 1 ? new#util#lookup(l:t) : l:t
            let g:vmwRuntime.request.layout = l:target
            call s:execute(s:get(l:target.opnBfr))
            call new#util#traverse(l:target, function('s:open_helper_bfr'), function('s:open_helper_aftr')
                        \,!l:vert, l:vert, v:false, 0, l:cache)
        endfor

        for l:t in a:000
            let l:target = type(l:t) == 1 ? new#util#lookup(l:t) : l:t
            let l:target.active = 1
            let g:vmwRuntime.request.layout = l:target
            call new#util#traverse(l:target, function('s:open_helper_bfr'), function('s:open_helper_aftr')
                        \, l:vert, !l:vert, v:true, 0, l:cache)
            call s:execute(s:get(l:target.opnAftr))
        endfor
    endif

    if exists('l:cache.focus')
        execute(bufwinnr(l:cache.focus) . 'wincmd w')
    endif
endfun

fun! s:open_helper_bfr(model, type, cache)
    if a:type == 0
        let a:cache.set_all = a:model.set_all
    " Create new windows as needed. Float is a special case that cannot be handled here.
    elseif a:type >= 1 && a:type <= 4
        " If abs use absolute positioning else use relative
        if a:model.abs
            call s:new_abs_win(a:type)
        else
            call s:new_std_win(a:type)
        endif

        " Make window proper size
        call s:mk_tmp()
        call s:resize_node(a:model, a:type)
    endif
endfun

" Force the result of commands to go in to the desired window
fun! s:open_helper_aftr(model, type, cache)
    let l:__func__ = "s:open_helper_aftr() "
    silent! call s:log.debug(l:__func__, " type=", a:type, " cache=", a:cache, " model=", a:model)

    let l:init_buf = bufnr('%')

    " Set first model as our main model-window
    if empty(g:vmwRuntime.models)
        let a:model._win_id = g:vmwRuntime.wid_main
        silent! call s:log.debug(l:__func__, " wilson set win_id=", a:model)
    endif

    if !has_key(g:vmwRuntime.models, a:model.viewname)
        let g:vmwRuntime.models[a:model.viewname] = a:model
    endif

    if has_key(g:vmwRuntime.viewname2bid, a:model.viewname)
        silent! call s:log.debug(l:__func__, " found existed buffer ". string(a:model.viewname))
        let a:model._buf_id = g:vmwRuntime.viewname2bid[a:model.viewname]
    endif

    " If buf exists, place it in current window and kill tmp buff
    if bufexists(a:model._buf_id)
        call s:restore_content(a:model, a:type)
    " Otherwise capture the buffer and move it to the current window
    else
        execute(bufwinnr(l:init_buf) . 'wincmd w')
        let a:model._buf_id = s:capture_buf(a:model, a:type)
        let g:vmwRuntime.viewname2bid[a:model.viewname] = a:model._buf_id

        if !s:buf_active(a:model._buf_id)
            call s:place_buf(a:model, a:type)
        endif
    endif


    " apply model.set as setlocal
    if !empty(a:model.set)
        call s:set_buf(a:model.set)
    endif

    if !empty(a:cache.set_all)
        call s:set_buf(a:cache.set_all)
    endif

    " Whatever the last occurrence of focus is will be focused
    if s:get(a:model.focus)
        let a:cache.focus = a:model._buf_id
    endif

    if a:type == 0 && g:new#eager_render
        redraw
    endif

    return bufnr('%')
endfun

fun! s:toggle(...)
    let l:on = []
    let l:off = []

    for l:entry in a:000
        let l:target = type(l:entry) == 1 ? new#util#lookup(l:entry) : l:entry

        if l:target.active
            let l:on += [l:target]
        else
            let l:off += [l:target]
        endif
    endfor

    if !empty(l:on)
        call call('new#close', l:on)
    endif

    if !empty(l:off)
        call call('new#open', l:off)
    endif
endfun

" Resize a root model and all of its children
fun! s:resize(target)
    let l:target = type(a:target) == 1 ? new#util#lookup(a:target) : a:target
    let g:vmwRuntime.request.layout = l:target
    call new#util#traverse(l:target, function('s:resize_helper'), v:null, v:true, v:true, 0, {})
endfun

"---------------------------------------------Auxiliary---------------------------------------------
fun! s:new_abs_win(type)
    if a:type == 1
        vert to new
    elseif a:type == 2
        vert bo new
    elseif a:type == 3
        to new
    elseif a:type == 4
        bo new
    else
        echoerr "unexpected val passed to new#open"
        return -1
    endif
endfun

fun! s:new_std_win(type)
    if a:type == 1
        vert abo new
    elseif a:type == 2
        vert bel new
    elseif a:type == 3
        abo new
    elseif a:type == 4
        bel new
    else
        echoerr "unexpected val passed to new#open"
        return -1
    endif
endfun

fun! s:restore_content(model, type)
    if a:type == 5
        call s:open_float_win(a:model)
    endif

    execute(a:model._buf_id . 'b')
    call s:execute(s:get(a:model.restore))
endfun

" Create the buffer, close it's window, and capture it!
" Using tabnew prevents unwanted resizing
fun! s:capture_buf(model, type)
    "If there are no commands to run, stop
    if empty(a:model.init)
        "If the root has no init, assume it's not meant to be part of the layout def.
        if !a:type
            return -1
        endif

        return bufnr('%')
    endif

    tabnew
    let l:init_bufs = s:get_active_bufs()
    let l:tmp_bid = bufnr('%')

    let l:init_win = winnr()
    let l:init_last = bufwinnr('$')

    let g:vmwRuntime.request.model = a:model
    let g:vmwRuntime.result.job_id = -1
    let g:vmwRuntime.result.win_id = -1
        call s:execute(s:get(a:model.init))
    let a:model._job_id = g:vmwRuntime.result.job_id
    let a:model._win_id = g:vmwRuntime.result.win_id

    let l:final_last = bufwinnr('$')

    if l:init_last != l:final_last
        let l:ret = winbufnr(l:final_last)
        execute(l:tmp_bid . 'bw')
    else
        let l:ret = winbufnr(l:init_win)
    endif

    let l:t_v = s:get_tab_vars()

    set ei=BufDelete
    let l:ei = &ei
    call s:close_tab()
    call s:wipe_aux_bufs(l:init_bufs, l:ret)
    execute('set ei=' . l:ei)

    call s:apply_tab_vars(l:t_v)

    return l:ret
endfun

" Places the target model buffer in the current window
fun! s:place_buf(model, type)
    " If the root model is not part of layout do not place
    if !a:type && empty(a:model.init)
        return 0
    endif

    if a:type == 5
        call s:open_float_win(a:model)
    else
        execute(a:model._buf_id . 'b')
    endif
endfun

fun! s:open_float_win(model)
    call nvim_open_win(a:model._buf_id, s:get(a:model.focus),
                \   { 'relative': s:get(a:model.relative)
                \   , 'row': s:get(a:model.y)
                \   , 'col': s:get(a:model.x)
                \   , 'width': s:get(a:model.width)
                \   , 'height': s:get(a:model.height)
                \   , 'focusable': s:get(a:model.focusable)
                \   , 'anchor': s:get(a:model.anchor)
                \   }
                \ )
endfun

fun! s:mk_tmp()
    setlocal bt=nofile bh=wipe noswapfile
endfun

" Apply setlocal entries
fun! s:set_buf(set)
    let l:set_cmd = 'setlocal'
    for val in s:get(a:set)
        let l:set_cmd = l:set_cmd . ' ' . val
    endfor
    execute(l:set_cmd)
endfun

" Resize some or all models.
fun! s:resize_node(model, type)
    if s:get(a:model.v_sz)
        execute('vert resize ' . s:get(a:model.v_sz))
    endif

    if s:get(a:model.h_sz)
        execute('resize ' . s:get(a:model.h_sz))
    endif
endfun

" Resize as the driving traverse and do
fun! s:resize_helper(model, type, cache)
    if  a:type >= 1 && a:type <= 4
        if s:buf_active(a:model._buf_id)
            execute(bufwinnr(a:model._buf_id) . 'wincmd w')
            call s:resize_node(a:model, a:type)
        endif
    endif
endfun

fun! s:get_tab_vars()
    let l:tab_raw = execute('let t:')
    let l:tab_vars = split(l:tab_raw, '\n')
    let l:ret = {}

    for l:v in l:tab_vars
        let l:v_name = substitute(l:v, '\(\S\+\).*', '\1', 'g')
        execute('let l:tmp = ' . l:v_name)
        let l:ret[l:v_name] = l:tmp
    endfor

    return l:ret
endfun

fun! s:apply_tab_vars(vars)
    for l:v in keys(a:vars)
        execute('let ' . l:v . ' = a:vars[l:v]')
    endfor
endfun

fun! s:close_tab()
    let l:tid = tabpagenr()

    for l:buf_id in tabpagebuflist()
        execute(bufwinnr(l:buf_id) . 'hide')
    endfor

    if l:tid == tabpagenr()
        tabclose
    endif
endfun
