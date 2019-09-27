" Utility functions for vim window manager
if !exists("s:init")
    let s:init = 1
    silent! let s:log = logger#getLogger(expand('<sfile>:t'))
endif

"------------------------------------------Layout traversal-----------------------------------------

" Traversal funcref signatures:
" bfr    :: dict -> int -> a
" aftr   :: dict -> int -> a

" Right recursive traverse and do
" If horz is true traverse top and bot, if vert is true traverse left and right
" node_type = { 0: 'root', 1: 'left', 2: 'right', 3: 'top', 4: 'bot', 5: 'float }
" Cache is an empty dictionary for saving special info through recursion
fun! new#util#traverse(target, bfr, aftr, horz, vert, float, node_type, cache)
    if !(a:bfr is v:null)
        call s:execute(a:bfr, a:target, a:node_type, a:cache)
    endif

    let l:bnr = bufnr('%')

    " Save the buffer id at each level
    if a:vert
        if util#node_has_child(a:target, 'left')
            call new#util#traverse(a:target.left, a:bfr, a:aftr, v:true, v:true, v:true, 1, a:cache)
            execute(bufwinnr(l:bnr) . 'wincmd w')
        endif

        if util#node_has_child(a:target, 'right')
            call new#util#traverse(a:target.right, a:bfr, a:aftr, v:true, v:true, v:true, 2, a:cache)
            execute(bufwinnr(l:bnr) . 'wincmd w')
        endif
    endif

    if a:horz
        if util#node_has_child(a:target, 'top')
            call new#util#traverse(a:target.top, a:bfr, a:aftr, v:true, v:true, v:true, 3, a:cache)
            execute(bufwinnr(l:bnr) . 'wincmd w')
        endif

        if util#node_has_child(a:target, 'bot')
            call new#util#traverse(a:target.bot, a:bfr, a:aftr, v:true, v:true, v:true, 4, a:cache)
            execute(bufwinnr(l:bnr) . 'wincmd w')
        endif
    endif

    if a:float
        if util#node_has_child(a:target, 'float')
            call new#util#traverse(a:target.float, a:bfr, a:aftr, v:true, v:true, v:true, 5, a:cache)
        endif
    endif

    if !(a:aftr is v:null)
        call s:execute(a:aftr, a:target, a:node_type, a:cache)
        execute(bufwinnr(l:bnr) . 'wincmd w')
    endif
endfun


fun! util#node_has_child(model, pos)
    if eval("exists('a:model." . a:pos . "')")
        return eval('len(a:model.' . a:pos . ')') ? 1 : 0
    endif
    return 0
endfun

"-----------------------------------------------Misc------------------------------------------------

" If a funcref is given, execute the function. Else assume list of strings
" Arity arg represents a list of arguments to be passed to the funcref
fun! s:execute(target, ...) abort
    let l:__func__ = "s:execute()"

    " is Funcref:
    silent! call s:log.debug(l:__func__, " type=", type(a:target), " target=", a:target, " args=", a:000)
    if type(a:target) == 2
        let l:New_Target = s:apply_funcref(a:target, a:000)
        call l:New_Target()
    else
        for l:Cmd in a:target
            let l:model = g:vmwRuntime.request.model
            let l:model.name = g:vmwRuntime.request.layout.name

            if type(l:Cmd) == 2
                let l:New_Target = s:apply_funcref(l:Cmd, a:000)
                call l:New_Target()
            elseif !empty(l:model.control) && l:Cmd ==? "termopen"
                " The only kind of 'init' which support expect&state
                let l:arg = "bash"
                if len(a:target) > 1
                    let l:arg = a:target[1]
                endif

                "silent! call s:log.debug(l:__func__, " state=", g:vmwRuntime.control, " model=", l:model)
                if !has_key(g:vmwRuntime.control, l:model.control)
                    call new#state#CreateControl(l:model.control)
                endif

                if has_key(g:vmwRuntime.control, l:model.control)
                    let l:control = copy(g:vmwRuntime.control[l:model.control])

                    let l:state = l:control['init']
                    "let state = copy(l:state)
                    let target = new#expect#Parser(l:state, l:model)
                    let g:vmwRuntime.result.job_id = termopen(l:arg, target)
                    let g:vmwRuntime.result.win_id = win_getid()
                    silent! call s:log.info(l:__func__, " with state support, job_id=", g:vmwRuntime.result.job_id, " win_id=", g:vmwRuntime.result.win_id)
                else
                    let g:vmwRuntime.result.job_id = termopen(l:arg)
                    let g:vmwRuntime.result.win_id = win_getid()
                    silent! call s:log.info(l:__func__, " without state support, job_id=", g:vmwRuntime.result.job_id, " win_id=", g:vmwRuntime.result.win_id)
                endif
                return
            else
                execute(l:Cmd)
            endif
        endfor
    endif
endfun

fun! s:apply_funcref(f, args)
    if a:args != [v:null] && len(a:args)
        let l:F = function(eval(string(a:f)), a:args)
    else
        let l:F = a:f
    endif
    return l:F
endfun

" If Target is a funcref, return it's result. Else return Target.
fun! s:get(Target)
    if type(a:Target) == 2
        return a:Target()
    else
        return a:Target
    endif
endfun

" Returns the first model in g:new#layouts with a matching name
fun! new#util#lookup(name)
    for l:model in g:new#layouts
        if a:name == l:model.name
            return l:model
        endif
    endfor

    echoerr a:name . " not in dictionary"
    return -1
endfun

" Returns true if the buffer exists in a currently visable window
fun! s:buf_active(_buf_id)
    return bufwinnr(a:_buf_id) == -1 ? v:false : v:true
endfun

" Retruns a list of all active layouts
fun! new#util#active()
    let l:active = []
    for model in g:new#layouts
        if model.active
            let l:active += [model]
        endif
    endfor
    return l:active
endfun

" ... = ignore
fun! s:wipe_aux_bufs(ls_init, ...)
    for l:buf_id in s:get_active_bufs()
        if index(a:ls_init, l:buf_id) < 0 && index(a:000, l:buf_id) < 0
            execute(l:buf_id . 'bw')
        endif
    endfor
endfun

fun! s:get_active_bufs()
    let l:ret = []
    for l:buf_id in range(1, bufnr('$'))
        if bufexists(l:buf_id)
            let l:ret += [l:buf_id]
        endif
    endfor

    return l:ret
endfun

" So I can break up the script into multiple parts without exposing multiple public functions
fun! new#util#SID()
    return s:SID()
endfun

fun! s:SID()
    return matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze_SID$')
endfun

fun! new#util#send(viewname, cmdstr)
    let l:__func__ = "new#util#send() "
    "silent! call s:log.debug(l:__func__, " viewname=", a:viewname, " cmdstr=", a:cmdstr)

    if !has_key(g:vmwRuntime.models, a:viewname)
        silent! call s:log.debug(l:__func__, "the model [", a:viewname, "] not exist!")
        return
    endif

    let l:model = g:vmwRuntime.models[a:viewname]
    if l:model._job_id >= 0
        call jobsend(l:model._job_id, a:cmdstr)
    endif
endfun

fun! new#util#post(viewname, cmdstr)
    let l:__func__ = "new#util#post() "
    silent! call s:log.debug(l:__func__, " viewname=", a:viewname, " cmdstr=", a:cmdstr)

    let one_cmd = {}
    let one_cmd[a:viewname] = a:cmdstr
    call add(g:vmwRuntime.post_cmds, one_cmd)
endfun

fun! new#util#_post_execute()
    let l:__func__ = "new#util#_post_execute() "
    silent! call s:log.debug(l:__func__, " viewname=", a:viewname, " cmdstr=", a:cmdstr)

    for one_cmd in g:vmwRuntime.post_cmds
        for [viewname, cmdstr] in items(one_cmd)
            call new#util#send(viewname, cmdstr)
        endfor
    endfor
    let g:vmwRuntime.post_cmds = []
endfun


function! new#util#MarkActiveWindow()
    let t:curWinnr = winnr()
    " We need to restore the previous-window also at the end.
    silent! wincmd p
    let t:prevWinnr = winnr()
    silent! wincmd p
endfunction

function! new#util#RestoreActiveWindow()
    if !exists('t:curWinnr')
        return
    endif

    " Restore the original window.
    if winnr() != t:curWinnr
        exec t:curWinnr'wincmd w'
    endif
    if t:curWinnr != t:prevWinnr
        exec t:prevWinnr'wincmd w'
        wincmd p
    endif
endfunction

"Returns the visually selected text
function! new#util#get_visual_selection()
    "Shamefully stolen from http://stackoverflow.com/a/6271254/794380
    " Why is this not a built-in Vim script function?!
    let [lnum1, col1] = getpos("'<")[1:2]
    let [lnum2, col2] = getpos("'>")[1:2]
    if lnum1 == lnum2
        let curline = getline('.')
        return curline[col1-1:col2+1]
    else
        let lines = getline(lnum1, lnum2)
        let lines[-1] = lines[-1][: col2 - (&selection == 'inclusive' ? 1 : 2)]
        let lines[0] = lines[0][col1 - 1:]
        return join(lines, "\n")
    endif
endfunction

function! new#util#get_curr_expression()
    let save_cursor = getcurpos()

    let text = getline('.')
    normal! be
    let end_pos = getcurpos()
    call search('\s\|[,;\(\)]','b')
    call search('\S')
    let start_pos = getcurpos()

    call setpos('.', save_cursor)
    return text[ (start_pos[2] -1) : (end_pos[2] - 1)]
endfunction

