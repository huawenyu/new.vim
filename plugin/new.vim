if exists("g:vmwRuntime") || &cp
    finish
endif

let g:vmwRuntime = {}
let g:vmwRuntime.layoutname = ""
let g:vmwRuntime.active = 0
let g:vmwRuntime.buf_count = 1
let g:vmwRuntime.wid_main = 0
let g:vmwRuntime.viewname2bid = {}
let g:vmwRuntime.layouts = {}
let g:vmwRuntime.models = {}
let g:vmwRuntime.control = {}
let g:vmwRuntime.post_cmds = []
let g:vmwRuntime.state = {}
let g:vmwRuntime.ctx = {}
let g:vmwRuntime.request = {}
let g:vmwRuntime.request.model = v:null
let g:vmwRuntime.result = {}
let g:vmwRuntime.result.job_id = -1
let g:vmwRuntime.result.win_id = -1

if !has("nvim")
    finish
endif

if !exists("s:init")
    let s:init = 1
    silent! let s:log = logger#getLogger(expand('<sfile>:t'))
endif

" NEW main user interface

"-------------------------------------------Init globals-------------------------------------------
if !exists('g:new#pop_order')
    let g:new#pop_order = 'both'
endif

if !exists('g:new#eager_render')
    let g:new#eager_render = v:false
endif

if !exists('g:new#layouts')
    let g:new#layouts = []
endif

if !exists('g:new#control')
    let g:new#control = {}
endif

"------------------------------------Normalize model attribrutes-------------------------------------
" Root must be normalized before any child models
fun! s:normalize_root(model)

    if !exists('a:model.name')
        let a:model['name'] = ''
    endif
    if !exists('a:model.opnBfr')
        let a:model['opnBfr'] = []
    endif
    if !exists('a:model.opnAftr')
        let a:model['opnAftr'] = []
    endif
    if !exists('a:model.clsBfr')
        let a:model['clsBfr'] = []
    endif
    if !exists('a:model.clsAftr')
        let a:model['clsAftr'] = []
    endif
    if !exists('a:model.active')
        let a:model['active'] = 0
    endif
    if !exists('a:model.viewname')
        let a:model['viewname'] = "__buf_". string(g:vmwRuntime.buf_count)
        let g:vmwRuntime.buf_count += 1
    endif
    if !exists('a:model.control')
        let a:model['control'] = ""
    endif
    if !exists('a:model._buf_id')
        let a:model['_buf_id'] = -1
    endif
    if !exists('a:model._job_id')
        let a:model['_job_id'] = -1
    endif
    if !exists('a:model._win_id')
        let a:model['_win_id'] = -1
    endif
    if !exists('a:model.focus')
        let a:model['focus'] = 0
    endif
    if !exists('a:model.init')
        let a:model['init'] = []
    endif
    if !exists('a:model.restore')
        let a:model['restore'] = []
    endif
    if !exists('a:model.set')
        let a:model['set'] = []
    endif
    if !exists('a:model.set_all')
        let a:model['set_all'] = []
    endif
    "TODO: Cache is the same as setlocal bh=wipe, make that clear.
    if util#node_has_child(a:model, 'left')
        call s:inject_abs(a:model.left)
    endif
    if util#node_has_child(a:model, 'right')
        call s:inject_abs(a:model.right)
    endif
    if util#node_has_child(a:model, 'top')
        call s:inject_abs(a:model.top)
    endif
    if util#node_has_child(a:model, 'bot')
        call s:inject_abs(a:model.bot)
    endif

endfun

fun! s:normalize_child(model)
    if !exists('a:model.v_sz')
        let a:model['v_sz'] = 0
    endif
    if !exists('a:model.h_sz')
        let a:model['h_sz'] = 0
    endif
    if !exists('a:model.viewname')
        let a:model['viewname'] = "__buf_". string(g:vmwRuntime.buf_count)
        let g:vmwRuntime.buf_count += 1
    endif
    if !exists('a:model.control')
        let a:model['control'] = ""
    endif
    if !exists('a:model._buf_id')
        let a:model['_buf_id'] = -1
    endif
    if !exists('a:model._job_id')
        let a:model['_job_id'] = -1
    endif
    if !exists('a:model._win_id')
        let a:model['_win_id'] = -1
    endif
    if !exists('a:model.init')
        let a:model['init'] = []
    endif
    if !exists('a:model.restore')
        let a:model['restore'] = []
    endif
    if !exists('a:model.focus')
        let a:model['focus'] = 0
    endif
    " set is just a convience wrapper for setlocal cmd
    if !exists('a:model.set')
        let a:model['set'] = ['bh=hide', 'nobl']
    endif
    if !exists('a:model.abs')
        let a:model['abs'] = 0
    endif
endfun

fun! s:normalize_float(model)

    if !exists('a:model.x')
        echoerr "Missing key x"
    endif
    if !exists('a:model.y')
        echoerr "Missing key y"
    endif
    if !exists('a:model.width')
        echoerr "Missing key width"
    endif
    if !exists('a:model.height')
        echoerr "Missing key height"
    endif
    if !exists('a:model.relative')
        let a:model['relative'] = 'editor'
    endif
    if !exists('a:model.viewname')
        let a:model['viewname'] = "__buf_". string(g:vmwRuntime.buf_count)
        let g:vmwRuntime.buf_count += 1
    endif
    if !exists('a:model.control')
        let a:model['control'] = ""
    endif
    if !exists('a:model._buf_id')
        let a:model['_buf_id'] = -1
    endif
    if !exists('a:model._job_id')
        let a:model['_job_id'] = -1
    endif
    if !exists('a:model._win_id')
        let a:model['_win_id'] = -1
    endif
    if !exists('a:model.init')
        let a:model['init'] = []
    endif
    if !exists('a:model.restore')
        let a:model['restore'] = []
    endif
    if !exists('a:model.focus')
        let a:model['focus'] = 0
    endif
    if !exists('a:model.focusable')
        let a:model['focusable'] = 1
    endif
    if !exists('a:model.anchor')
        let a:model['anchor'] = 'NW'
    endif
    if !exists('a:model.set')
        let a:model['set'] = ['bh=hide', 'nobl']
    endif

endfun

" Make abs = v:true default for first layer of child models
fun! s:inject_abs(model)
    if !exists('a:model.abs')
        let a:model.abs = v:true
    endif
endfun

fun! s:normalize_helper(model, type, cache)
    if a:type == 0
        call s:normalize_root(a:model)
    elseif 1 <= a:type && 4 >= a:type
        call s:normalize_child(a:model)
    elseif a:type == 5
        call s:normalize_float(a:model)
    endif
endfun

" @todo wilson should just normalize current open layout
fun! NewNormalize()
    let l:layouts = []

    for l:layout in g:new#layouts
        if has_key(g:vmwRuntime.layouts, l:layout.name)
            continue
        endif

        call add(l:layouts, l:layout)
        let g:vmwRuntime.layouts[l:layout.name] = l:layout

        let g:new#layouts = l:layouts
    endfor

    for l:layout in g:new#layouts
        if !has_key(g:vmwRuntime.layouts, l:layout.name)
            let g:vmwRuntime.layouts[l:layout.name] = l:layout
        endif

        let g:vmwRuntime.request.layout = l:layout
        call new#util#traverse(l:layout, function('s:normalize_helper'), v:null
                    \, v:true, v:true, v:true, 0, {})
    endfor
endfun

fun! NewAddLayout(custom_layt, custom_control, custom_ops)
    if !exists('g:new#layouts')
        let g:new#layouts = []
    endif
    call add(g:new#layouts, a:custom_layt)

    if !exists('g:new#control')
        let g:new#control = {}
    endif

    if !exists('g:new#ops')
        let g:new#ops = {}
    endif

    for [next_key, next_val] in items(a:custom_control)
        if !has_key(g:new#control, next_key)
            let g:new#control[next_key] = next_val
        endif
    endfor

    if !has_key(g:new#ops, a:custom_layt.name)
        let g:new#ops[a:custom_layt.name] = a:custom_ops
    endif
endfun

fun! NewListLayout(A,L,P)
    let l:retStr = ""
    for l:model in g:new#layouts
        let l:retStr .= l:model.name. "\n"
    endfor
    return l:retStr
endfun


"------------------------------------------public commands------------------------------------------
command! NewReinit call NewNormalize()
command! -complete=custom,NewListLayout -nargs=+ NewOpen call new#open(<f-args>)
command! -complete=custom,NewListLayout -nargs=+ NewClose call new#close(<f-args>)
command! -complete=custom,NewListLayout -nargs=+ NewToggle call new#toggle(<f-args>)
command! -nargs=0 NewCloseAll call call('new#close', new#util#active())
command! -nargs=0 NewRefresh call new#refresh()



