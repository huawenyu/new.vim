if !exists("s:init")
    let s:init = 1
    silent! let s:log = logger#getLogger(expand('<sfile>:t'))
endif

function! new#state#Set(ctrlName, stateName, handler)
    if !has_key(g:vmwRuntime.control, a:ctrlName)
        let g:vmwRuntime.control[a:ctrlName] = {}
    endif

    let control = g:vmwRuntime.control[a:ctrlName]
    let control[a:stateName] = a:handler
endfunc


function! new#state#Get(ctrlName, stateName)
    if has_key(g:vmwRuntime.control, a:ctrlName)
        let control = g:vmwRuntime.control[a:ctrlName]
        if has_key(control, a:stateName)
            return control[a:stateName]
        endif
    endif
    return v:null
endfunc


function! new#state#CreateControl(ctrlName) abort
    let l:__func__ = substitute(expand('<sfile>'), '.*\(\.\.\|\s\)', '', '')

    if !has_key(g:new#control, a:ctrlName)
        throw printf("%s() controller '%s' not exist.", l:__func__, a:ctrlName)
    endif

    if !has_key(g:new#control[a:ctrlName], 'init')
        throw printf("%s() controller '%s' should have 'init' state.", l:__func__, a:ctrlName)
    endif

    " Load Controller
    for [stateName, handler_arr] in items(g:new#control[a:ctrlName])
        let patterns = []
        for handler in handler_arr
            let handler.ctrlName = a:ctrlName
            let handler.stateName = stateName
            let match_arr = handler.match

            if type(match_arr) != type([])
                throw printf("new#state#CreateControl: state '%s' match '%s' should be list"
                        \ , stateName, string(match_arr))
            endif

            for one_pattern in match_arr
                call add(patterns, [one_pattern, 'stateHandler', handler])
            endfor
        endfor

        let handler = new#expect#State(stateName, patterns)
        call new#state#Set(a:ctrlName, stateName, handler)
        unlet stateName handler_arr
    endfor
endfunc


" @mode 0 switch, 1 push, 2 pop
function! state#Switch(viewName, stateName, mode) abort
    let l:__func__ = 'state#Switch'

    if !has_key(g:vmwRuntime.models, a:viewName)
        throw l:__func__. " model '". a:viewName . "' not exist"
    endif

    silent! call s:log.debug("State => ", a:stateName)
    let l:model = g:vmwRuntime.models[a:viewName]
    if a:mode == 0
        let handler = new#state#Get(l:model.control, a:stateName)
        if handler isnot v:null
            call l:model._parser.switch(handler)
        endif
    elseif a:mode == 1
        let handler = new#state#Get(l:model.control, a:stateName)
        if handler isnot v:null
            call l:model._parser.push(handler)
        endif
    elseif a:mode == 2
        call l:model._parser.pop()
    endif
endfunc

function! new#state#CurrState(viewName) abort
    let l:__func__ = 'state#CurrState() '

    if !has_key(g:vmwRuntime.models, a:viewName)
        throw l:__func__. "model '". a:viewName . "' not exist"
    endif

    let l:model = g:vmwRuntime.models[a:viewName]
    return l:model._parser.state()
endfunc

function! new#state#GetStateNameByState(state) abort
    if has_key(a:state, 'stateName')
        let l:stateName = a:state.stateName
    elseif has_key(a:state, 'name')
        let l:stateName = a:state.name
    else
        let l:stateName = ''
    endif
    return l:stateName
endfunc

function! new#state#GetStateName(viewName) abort
    let l:state = new#state#CurrState(a:viewName)
    return new#state#GetStateNameByState(l:state)
endfunc
