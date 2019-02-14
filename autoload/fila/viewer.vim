let s:Config = vital#fila#import('Config')

function! fila#viewer#open(bufname, options) abort
  call fila#buffer#open(a:bufname, a:options)
        \.catch({ e -> fila#error#handle(e) })
endfunction

function! fila#viewer#BufReadCmd(factory) abort
  doautocmd <nomodeline> BufReadPre

  let bufnr = str2nr(expand('<abuf>'))
  let helper = fila#helper#new(bufnr)

  if !exists('b:fila_ready') || v:cmdbang
    let b:fila_ready = 1
    setlocal buftype=nofile bufhidden=unload
    setlocal noswapfile nobuflisted nomodifiable readonly

    augroup fila_viewer_internal
      autocmd! * <buffer>
      autocmd BufEnter <buffer> setlocal nobuflisted
    augroup END

    call fila#action#_init()
    call fila#action#_define()

    if !g:fila#viewer#skip_default_mappings
      nmap <buffer><nowait> <Backspace> <Plug>(fila-action-leave)
      nmap <buffer><nowait> <C-h>       <Plug>(fila-action-leave)
      nmap <buffer><nowait> <Return>    <Plug>(fila-action-enter-or-open)
      nmap <buffer><nowait> <C-m>       <Plug>(fila-action-enter-or-open)
      nmap <buffer><nowait> <F5>        <Plug>(fila-action-reload)
      nmap <buffer><nowait> l           <Plug>(fila-action-expand-or-open)
      nmap <buffer><nowait> h           <Plug>(fila-action-collapse)
      nmap <buffer><nowait> -           <Plug>(fila-action-mark-toggle)
      vmap <buffer><nowait> -           <Plug>(fila-action-mark-toggle)
      nmap <buffer><nowait> !           <Plug>(fila-action-hidden-toggle)
      nmap <buffer><nowait> e           <Plug>(fila-action-open)
      nmap <buffer><nowait> t           <Plug>(fila-action-open-tabedit)
      nmap <buffer><nowait> E           <Plug>(fila-action-open-side)
    endif

    let winid = win_getid()
    let project_root = fila#scheme#file#create_root(gina#core#get().worktree)
    let root = a:factory()

    let dirs = fila#viewer#node_list(project_root, root)
    call helper.init(project_root)
    call helper.expand_node(project_root)
          \.then({ h -> h.redraw() })
          \.then({ h -> h.cursor_node(winid, project_root, 1) })
          \.then({ h -> s:notify(h.bufnr) })
          \.then({ h -> fila#viewer#expand_recursive(dirs, a:factory, helper) })
          \.catch({ e -> fila#error#handle(e) })

    doautocmd <nomodeline> User FilaViewerInit
  else
    let winid = win_getid()
    let project_root = fila#scheme#file#create_root(gina#core#get().worktree)
    let root = helper.get_root_node()

    let dirs = fila#viewer#node_list(project_root, root)
    call helper.set_marks([])
    call helper.reload_node(root)
          \.then({ h -> h.redraw() })
          \.then({ h -> h.cursor_node(winid, root, 1) })
          \.then({ h -> s:notify(h.bufnr) })
          \.then({ h -> fila#viewer#expand_recursive(dirs, a:factory, helper) })
          \.catch({ e -> fila#error#handle(e) })
  endif
  setlocal filetype=fila

  doautocmd <nomodeline> BufReadPost
endfunction

function! s:notify(bufnr) abort
  let notifier = getbufvar(a:bufnr, 'fila_notifier', v:null)
  if notifier isnot# v:null
    call notifier.notify()
    call setbufvar(a:bufnr, 'fila_notifier', v:null)
  endif
  doautocmd <nomodeline> User FilaViewerRead
endfunction

function! fila#viewer#expand_recursive(dirs, factory, helper) abort
  let project_root = fila#scheme#file#create_root(gina#core#get().worktree)
  let root = a:factory()
  call a:helper.expand_node(a:dirs[-1])
        \.then({ h -> h.redraw() })
        \.then({ h -> s:notify(h.bufnr) })
        \.then({ h -> a:helper.cursor_node(win_getid(), a:dirs[-1], 1) })
        \.then({ h -> remove(a:dirs, -1) })
        \.then({ h -> len(a:dirs) > 0 ? fila#viewer#expand_recursive(a:dirs, a:factory, a:helper) : v:false })
        \.catch({ e -> fila#error#handle(e) })
endfunction

function! fila#viewer#node_list(project_root, root) abort
  let dirs = []
  let node = a:root
  while v:true
    let node = fila#scheme#file#node#new(node.__path)
    let node.parent = fila#scheme#file#node#new(fnamemodify(node.__path, ':p:h:h'))
    call add(dirs, node)

    if a:project_root.__path ==# node.__path
      break
    endif

    let node = node.parent
  endwhile

  return dirs
endfunction

augroup fila_viewer_internal
  autocmd! *
  autocmd User FilaViewerInit :
  autocmd User FilaViewerRead :
  autocmd BufReadPre  fila://*   :
  autocmd BufReadPost fila://* :
augroup END

call s:Config.config(expand('<sfile>:p'), {
      \ 'skip_default_mappings': 0,
      \})
