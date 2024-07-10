vim9script noclear

# Termdebug settings for microcontroller applications
# Maintainer: Ubaldo Tiberi
# License: BSD3-Clause
#
# Debugger for microcontrollers built on top of Termdebug and that uses
# open-ocd.
#
#
if !has('vim9script') ||  v:version < 900
  finish
endif

# if exists('g:microdebugger_loaded')
#     Echoerr('Plugin already loaded.')
#     finish
# endif
g:microdebugger_loaded = true

def Echoerr(msg: string)
  echohl ErrorMsg | echom $'[microdebugger] {msg}' | echohl None
enddef

def Echowarn(msg: string)
  echohl WarningMsg | echom $'[microdebugger] {msg}' | echohl None
enddef

# Script global variables
var openocd_bufname: string
var openocd_bufnr: number
var openocd_win: number

var monitor_bufname: string
var monitor_bufnr: number
var monitor_win: number

var gdb_bufname: string
var gdb_bufnr: number
var gdb_win: number

var var_bufname: string
var var_bufnr: number
var var_win: number

var asm_bufname: string
var asm_bufnr: number
var asm_win: number

var source_win: number
var aux_windows: dict<func>

def InitScriptVars()
  openocd_bufname = 'OPENOCD'
  openocd_bufnr = 0
  openocd_win = 0

  monitor_bufname = 'Monitor'
  monitor_bufnr = 0
  monitor_win = 0

  gdb_bufname = 'gdb'
  gdb_bufnr = 0
  gdb_win = 0

  var_bufname = "Termdebug-variables-listing"
  var_bufnr = 0
  var_win = 0

  asm_bufname = "Termdebug-asm-listing"
  asm_bufnr = 0
  asm_win = 0

  source_win = 0

  aux_windows = {variables: SetVarWindow, monitor: SetMonitorWindow, asm: SetAsmWindow, openocd: SetOpenocdWindow}
enddef

def SanityCheck(): bool
  var is_check_ok = true

  if !executable('openocd')
    Echoerr("'openocd' not found. Cannot start the debugger" )
    is_check_ok = false
  endif

  if !exists('g:termdebug_config')
    Echoerr("'g:termdebug_config' is not set" )
    is_check_ok = false
  elseif !has_key(g:termdebug_config, 'command')
    Echoerr("'g:termdebug_config['command']' is not set" )
    is_check_ok = false
  endif

  if !exists('g:microdebugger_openocd_command')
    Echoerr("'g:microdebugger_openocd_command' is not set" )
    is_check_ok = false
  endif

  if exists('g:microdebugger_aux_windows')
    for x in g:microdebugger_aux_windows
      if !has_key(aux_windows, x)
        Echoerr($"'{x}' is not a valid value. Valid values are {keys(aux_windows)}" )
        is_check_ok = false
      endif
    endfor
    if index(g:microdebugger_aux_windows, 'monitor') != -1 && !exists('g:microdebugger_monitor_command')
      Echoerr("You shall set 'g:microdebugger_monitor_command' or remove 'monitor' from 'g:microdebugger_aux_windows'" )
      is_check_ok = false
    endif
  endif

  return is_check_ok
enddef

def MyTermdebug()
  InitScriptVars()
  if !SanityCheck()
    return
  endif

  # TODO: Check if this appears
  echo "Starting microdebugger for project: " .. fnamemodify(getcwd(), ':t')
  if !exists('g:termdebug_loaded')
    packadd termdebug
  endif

  # 1. Start openocd
  openocd_bufnr = term_start(&shell, {term_name: openocd_bufname, hidden: 1, term_finish: 'close'})
  term_sendkeys(openocd_bufnr, g:microdebugger_openocd_command)
  setbufvar(openocd_bufname, "&buflisted", 0)

  # 2. Start Termdebug and connect the gdb client to openocd (see g:termdebug_config['command'])
  execute "Termdebug"
  exe ":Gdb"
  gdb_bufname = bufname()
  gdb_bufnr = bufnr()
  gdb_win = win_getid()
  setbufvar(gdb_bufname, "&buflisted", 0)
  setwinvar(gdb_win, '&statusline', '%#StatusLine# %t(%n)%m%*' )

  # Set the height of the gdb console
  if exists('g:microdebugger_gdb_win_height')
    win_execute(gdb_win, $"resize {g:microdebugger_gdb_win_height}")
  endif

  # We close "debugged-program" buffer because it may not be of interest for
  # embedded.
  if !empty(win_findbuf(bufnr("debugged-program")))
    execute ":close " ..  bufwinnr("debugged-program")
  endif

  # Unlist the buffers opened by termdebug and by this plugin
  # setbufvar("debugged-program", "&buflisted", 0)
  setbufvar("gdb communication", "&buflisted", 0)

  # We start the debugging session from the :Source window.
  exe "Source"
  source_win = win_getid()

  # Aesthetical Termdebug. We arrange the windows while keeping the cursor
  # in the Source window
  if exists('g:microdebugger_aux_windows') && !empty(g:microdebugger_aux_windows)
    ArrangeAuxWindows()
  endif

  if exists('g:microdebugger_gdb_win_height')
    win_execute(gdb_win, $'resize {g:microdebugger_gdb_win_height}')
  endif
enddef

def GotoMonitorWinOrCreateIt()
  # var mdf = ''
  if !win_gotoid(monitor_win)

    monitor_win = win_getid()

    setlocal nowrap
    setlocal noswapfile
    setlocal buftype=nofile
    setlocal bufhidden=wipe
    setlocal signcolumn=no
    setlocal modifiable
    setlocal statusline=%#StatusLine#\ %t(%n)%m%*
    setlocal nobuflisted

    # If exists, then open, otherwise create
    if monitor_bufnr > 0 && bufexists(monitor_bufnr)
      exe ':buffer ' .. monitor_bufnr
    else
      # TODO: This won't work, you need to start the terminal
      term_start(g:microdebugger_monitor_command, {term_name: monitor_bufname, hidden: 1, term_finish: 'close'})
      # exe "silent file " .. monitor_bufname
      monitor_bufnr = bufnr(monitor_bufname)
    endif

  endif
enddef

def ArrangeAuxWindows()
  # Call function to adjust user-defined window.
  aux_windows[g:microdebugger_aux_windows[0]](true)

  # Stack the rest of the windows
  for key in g:microdebugger_aux_windows[1 : ]
    aux_windows[key](false)
  endfor
enddef

def SetVarWindow(is_first: bool)
  exe "Var"
  setbufvar(var_bufname, "&buflisted", 0)
  var_bufnr = bufnr(var_bufname)
  var_win = win_findbuf(var_bufnr)[0]
  var tmp_win = win_getid()
  if is_first
    wincmd L
    exe $"vertical resize {&columns / 3}"
    var_win = win_getid()
    setwinvar(var_win, '&statusline', '%#StatusLine# %t(%n)%m%*' )
  else
    wincmd l
    split
    exe ":buffer " .. var_bufnr
    win_execute(tmp_win, 'close')
  endif
  if exists('g:microdebugger_var_win_height')
    win_execute(var_win, $'resize {g:microdebugger_var_win_height}')
  endif
enddef

def SetAsmWindow(is_first: bool)
  exe "Asm"
  setbufvar(asm_bufname, "&buflisted", 0)
  asm_bufnr = bufnr(asm_bufname)
  var tmp_win = win_getid()
  if is_first
    wincmd L
    exe $"vertical resize {&columns / 3}"
    asm_win = win_getid()
    setwinvar(asm_win, '&statusline', '%#StatusLine# %t(%n)%m%*' )
  else
    wincmd l
    split
    exe ":buffer " .. asm_bufnr
    win_execute(tmp_win, 'close')
  endif
  # if exists('g:microdebugger_asm_win_height')
  #   win_execute(asm_win, $'resize {g:microdebugger_asm_win_height}')
  # endif
enddef

def SetMonitorWindow(is_first: bool)
  GotoMonitorWinOrCreateIt()
  setbufvar(monitor_bufname, "&buflisted", 0)
  monitor_bufnr = bufnr(monitor_bufname)
  var tmp_win = win_getid()
  if is_first
    wincmd L
    exe $"vertical resize {&columns / 3}"
    monitor_win = win_getid()
    setwinvar(monitor_win, '&statusline', '%#StatusLine# %t(%n)%m%*' )
  else
    wincmd l
    split
    exe ":buffer " .. monitor_bufnr
    win_execute(tmp_win, 'close')
  endif
  # if exists('g:microdebugger_monitor_win_height')
  #   win_execute(monitor_win, $'resize {g:microdebugger_monitor_win_height}')
  # endif
enddef

def SetOpenocdWindow()
  # echo "foo"
enddef

def ShutoffTermdebug()
  # Extension of Termdebug CloseBuffers() function
  var bufnumbers = [monitor_bufnr, openocd_bufnr]
  for bufnr in bufnumbers
    if bufnr > 0 && bufexists(bufnr)
      exe $'bwipe! {bufnr}'
    endif
  endfor
enddef

augroup OpenOCDShutdown
  autocmd!
  autocmd User TermdebugStopPost ShutoffTermdebug()
augroup END

# Mappings
var existing_mappings = {}

def SetUpTermdebugOverrides()
  if exists('g:microdebugger_mappings')
    for key in keys(g:microdebugger_mappings)
      # Save possibly existing mappings
      if !empty(mapcheck(key, "n"))
        existing_mappings[key] = maparg(key, 'n', false, true)
      endif
      exe 'nnoremap <expr> ' .. key .. " " .. $"$'{g:microdebugger_mappings[key]}'"
    endfor
  endif
enddef

def TearDownTermdebugOverrides()
  if exists('g:microdebugger_mappings')
    for key in keys(g:microdebugger_mappings)
      if index(keys(existing_mappings), key) != -1
        mapset('n', 0, existing_mappings[key])
      else
        exe "silent! nunmap {key}"
      endif
    endfor
  endif
enddef

augroup MyTermdebugOverrides
  autocmd!
  autocmd User TermdebugStartPost SetUpTermdebugOverrides()
  autocmd User TermdebugStopPost  TearDownTermdebugOverrides()
augroup END

command! -nargs=* MicroDebug MyTermdebug()

# vim: sw=2 sts=2 et
