vim9script noclear

# Termdebug settings for microcontroller applications
# Maintainer: Ubaldo Tiberi
# License: Vim license
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

command! MicroDebug MicrodebuggerStart()

# Script global variables
var openocd_bufname: string
var openocd_bufnr: number
var openocd_win: number
# var openocd_failure: bool

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
var aux_bufnames: dict<string>
var aux_windows_pos: string
var aux_windows_width: number

var monitor_term_waiting_time: number
var openocd_term_waiting_time: number

var existing_mappings: dict<any>

def InitScriptVars()
  openocd_bufname = 'OPENOCD'
  # term_start returns 0 if the job fails to start. Hence, it is safer to use
  # -1 as initial condition
  openocd_bufnr = -1
  openocd_win = 0
  # openocd_failure = false

  monitor_bufname = 'Monitor'
  monitor_bufnr = -1
  monitor_win = 0

  gdb_bufname = 'gdb'
  gdb_bufnr = -1
  gdb_win = 0

  var_bufname = "Termdebug-variables-listing"
  var_bufnr = -1
  var_win = 0

  asm_bufname = "Termdebug-asm-listing"
  asm_bufnr = -1
  asm_win = 0

  source_win = 0
  # The possible values for g:microdebugger_aux_windows corresponds to the
  # keys of the following dictionaries.
  aux_windows = {variables: SetVarWindow, monitor: SetMonitorWindow, asm: SetAsmWindow, openocd: SetOpenocdWindow}
  aux_bufnames = {variables: var_bufname, monitor: monitor_bufname, asm: asm_bufname, openocd: openocd_bufname}
  aux_windows_pos = get(g:, 'microdebugger_aux_win_pos', 'L')
  aux_windows_width = get(g:, 'microdebugger_aux_win_width', &columns / 3)

  monitor_term_waiting_time = get(g:, 'microdebugger_monitor_waiting_time', 100)
  openocd_term_waiting_time = get(g:, 'microdebugger_openocd_waiting_time', 1000)

  existing_mappings = {}

  g:termdebug_config['variables_window'] = 0
  g:termdebug_config['disasm_window'] = 0
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
        Echoerr($"'{x}' is not a valid value for 'g:microdebugger_aux_windows'. Valid values are {keys(aux_windows)}" )
        is_check_ok = false
      endif
    endfor
    if index(g:microdebugger_aux_windows, 'monitor') != -1 && !exists('g:microdebugger_monitor_command')
      Echoerr("You shall set 'g:microdebugger_monitor_command' or remove 'monitor' from 'g:microdebugger_aux_windows'" )
      is_check_ok = false
    endif
  endif

  if exists('g:microdebugger_aux_win_pos')
    if !(g:microdebugger_aux_win_pos == 'H' || g:microdebugger_aux_win_pos == 'L')
      Echoerr("The value of 'g:microdebugger_aux_win_pos' must be 'H' or 'L'")
      is_check_ok = false
    endif
  endif
  return is_check_ok
enddef

def OpenOcdExitHandler(job_id: any, exit_status: number)
  if exit_status != 0
    Echoerr('OpenOCD detected some errors. Microdebugger will not work.')
    # openocd_failure = true
  endif
enddef

def MicrodebuggerStart()
  if exists('g:termdebug_is_running') && g:termdebug_is_running
    Echoerr('Terminal debugger is already running, cannot run two')
    return
  endif

  InitScriptVars()
  if !SanityCheck()
    return
  endif

  if !exists('g:termdebug_loaded')
    packadd termdebug
  endif

  # 1. Start openocd
  silent! openocd_bufnr = term_start(g:microdebugger_openocd_command, {term_name: openocd_bufname, hidden: 1, exit_cb: OpenOcdExitHandler})
  if openocd_bufnr == 0
    Echoerr('Invlid OpenOCD opening command. Microdebbugger will not start')
    ShutoffMicrodebugger()
    return
  endif
  term_wait(openocd_bufname, openocd_term_waiting_time)
  setbufvar(openocd_bufname, "&buflisted", false)
  # Returning from OpenOcdExitHandler
  # if openocd_failure
    # ShutoffMicrodebugger()
    # return
  # endif

  # 2. Start Termdebug and connect the gdb client to openocd (see g:termdebug_config['command'])
  execute "Termdebug"
  exe ":Gdb"
  gdb_bufname = bufname()
  gdb_bufnr = bufnr()
  gdb_win = win_getid()
  setbufvar(gdb_bufname, "&buflisted", 0)
  setbufvar(gdb_bufname, "&bufhidden", 'wipe')
  setwinvar(gdb_win, '&statusline', '%#StatusLine# %t(%n)%m%*' )

  # We close "debugged-program" buffer because it may not be of interest for
  # embedded.
  if bufexists("debugged-program")
    execute ":bw! " ..  bufnr("debugged-program")
  endif

  # Unlist the buffers opened by termdebug and by this plugin
  setbufvar("gdb communication", "&buflisted", false)

  # We start the debugging session from the :Source window.
  exe "Source"
  source_win = win_getid()

  # Aesthetical Termdebug. We arrange the windows while keeping the cursor
  # in the Source window
  if exists('g:microdebugger_aux_windows') && !empty(g:microdebugger_aux_windows)
    ArrangeAuxWindows()
    # if !ArrangeAuxWindows()
    #   ShutoffMicrodebugger()
    #   return
    # endif
  endif

  if exists('g:microdebugger_gdb_win_height')
    win_execute(gdb_win, $'resize {g:microdebugger_gdb_win_height}')
  endif

  if exists('#User#MicrodebuggerStartPost')
    doauto <nomodeline> User MicrodebuggerStartPost
  endif
enddef

def ArrangeAuxWindows()
  # Stack aux buffers
  # var return_status = true
  for key in g:microdebugger_aux_windows
    aux_windows[key]()
    # if !aux_windows[key]()
    #   return_status = false
    #   break
    # endif
  endfor
  # return return_status
enddef

def DisplayedAuxBuffers(): list<number>
  # Return a list of windows ID:s displaying aux buffers
  var displayed_aux_buffers = []
  for key in g:microdebugger_aux_windows
    var aux_buf_nr = bufnr(aux_bufnames[key])
    var wins_containing_buf = win_findbuf(aux_buf_nr)
    if bufexists(aux_buf_nr) && aux_buf_nr > 0 && !empty(wins_containing_buf)
      add(displayed_aux_buffers, wins_containing_buf[0])
    endif
  endfor
  return displayed_aux_buffers
enddef

def ResizeAuxWindows()
  if win_gotoid(openocd_win)
    win_execute(openocd_win, $'vertical resize {aux_windows_width}')
  elseif win_gotoid(monitor_win)
    win_execute(monitor_win, $'vertical resize {aux_windows_width}')
  endif
enddef

def SetVarWindow()
  # exe "Var"
  # setbufvar(var_bufname, "&buflisted", false)
  # setwinvar(var_win, '&statusline', '%#StatusLine# %t(%n)%m%*' )
  # ResizeAuxWindows()
  if !win_gotoid(var_win)
    exe "Var"
    # setbufvar(var_bufname, "&buflisted", false)
    # setbufvar(var_bufnr, "&bufhidden", 'hide')
    var_bufnr = bufnr(var_bufname)
    SetWindowCommon(var_bufnr)
    var_win = win_getid()
    setwinvar(var_win, '&statusline', '%#StatusLine# %t(%n)%m%*' )
  endif
  # if exists('g:microdebugger_var_win_height')
  #   win_execute(var_win, $'resize {g:microdebugger_var_win_height}')
  # endif
enddef

def SetAsmWindow()
  # exe "Asm"
  # setbufvar(asm_bufname, "&buflisted", false)
  # setwinvar(asm_win, '&statusline', '%#StatusLine# %t(%n)%m%*' )
  # ResizeAuxWindows()
  if !win_gotoid(asm_win)
    exe "Asm"
    # setbufvar(asm_bufname, "&buflisted", false)
    # setbufvar(asm_bufname, "&bufhidden", 'hide')
    # setbufvar(asm_bufname, "&modified", true)
    asm_bufnr = bufnr(asm_bufname)
    SetWindowCommon(asm_bufnr)
    asm_win = win_getid()
    setwinvar(asm_win, '&statusline', '%#StatusLine# %t(%n)%m%*' )
  endif
  # return true
  # win_execute(asm_win, $'vertical resize {aux_windows_width}')
  # if exists('g:microdebugger_asm_win_height')
  #   win_execute(asm_win, $'resize {g:microdebugger_asm_win_height}')
  # endif
enddef

def SetMonitorWindow()
  if !win_gotoid(monitor_win)
    CreateMonitorWindow()
    # if !CreateMonitorWindow()
    #   return false
    # endif
    SetWindowCommon(monitor_bufnr)
    monitor_win = win_getid()
    setwinvar(monitor_win, '&statusline', '%#StatusLine# %t(%n)%m%*' )
  endif
  win_execute(monitor_win, $'vertical resize {aux_windows_width}')
  # return true
  # if exists('g:microdebugger_monitor_win_height')
  #   win_execute(monitor_win, $'resize {g:microdebugger_monitor_win_height}')
  # endif
enddef

def SetOpenocdWindow()
  if !win_gotoid(monitor_win)
    split
    exe "buffer " .. openocd_bufnr
    SetWindowCommon(openocd_bufnr)
    openocd_win = win_getid()
    setwinvar(openocd_win, '&statusline', '%#StatusLine# %t(%n)%m%*' )
  endif
  win_execute(openocd_win, $'vertical resize {aux_windows_width}')
  # return true
enddef

def SetWindowCommon(bufnr: number)
  # If it is the first window, then place it in a side. Otherwise, stack to
  # the existings
  var tmp_win = win_getid()
  var displayed_buffers = DisplayedAuxBuffers()
  # if you are the first, go on the side
  if len(displayed_buffers) == 1
    exe $'wincmd {aux_windows_pos}'
  else
    win_gotoid(displayed_buffers[0])
    split
    exe ":buffer " .. bufnr
    win_execute(tmp_win, 'close')
  endif
enddef

def MonitorExitHandler(job_id: any, exit_status: number)
  if exit_status != 0
    Echoerr('The monitor program cannot start.')
  endif
enddef

def CreateMonitorWindow()
  # If exists, then open, otherwise create
  # TODO: This won't work, you need to start the terminal
  silent! monitor_bufnr = term_start(join(g:microdebugger_monitor_command), {term_name: monitor_bufname, exit_cb: MonitorExitHandler})
  # silent! monitor_bufnr = term_start(join(g:microdebugger_monitor_command), {term_name: monitor_bufname})
  if monitor_bufnr == 0
    Echoerr('Monitor program cannot start.')
    return
  endif
  term_wait(monitor_bufnr, monitor_term_waiting_time)
  # term_sendkeys(monitor_bufnr, join(g:microdebugger_monitor_command))

  setbufvar(monitor_bufnr, "&wrap", false)
  setbufvar(monitor_bufnr, "&swapfile", false)
  setbufvar(monitor_bufnr, "&bufhidden", 'hide')
  setbufvar(monitor_bufnr, "&buflisted", false)
  setbufvar(monitor_bufnr, "&signcolumn", 'no')
  # return true
enddef



def SetUpMicrodebugger()

  command! MicroDebugAsm SetAsmWindow()
  command! MicroDebugVar SetVarWindow()
  command! MicroDebugMonitor SetMonitorWindow()
  command! MicroDebugOpenocd SetOpenocdWindow()

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

def ShutoffMicrodebugger()
  # Use this to shutoff everything BEFORE TermdebugStartPost event is
  # triggered
  # Extension of Termdebug CloseBuffers() function
  # Closing gdb_bufnr close the whole Termdebug
  var bufnumbers = [monitor_bufnr, openocd_bufnr, gdb_bufnr]
  for bufnr in bufnumbers
    if bufnr > 0 && bufexists(bufnr)
      exe $'bwipe! {bufnr}'
    endif
  endfor
enddef

def TearDownMicrodebugger()
  # Use this to shutoff everything AFTER TermdebugStartPost event is
  # triggered

  silent! delcommand MicroDebugAsm
  silent! delcommand MicroDebugVar
  silent! delcommand MicroDebugMonitor
  silent! delcommand MicroDebugOpenocd

  if exists('g:microdebugger_mappings')
    for key in keys(g:microdebugger_mappings)
      if has_key(existing_mappings, key)
        mapset('n', 0, existing_mappings[key])
      else
        exe $"nunmap {key}"
      endif
    endfor
  endif
  ShutoffMicrodebugger()
enddef

augroup MicrodebuggerSetUpTearDown
  autocmd!
  autocmd User TermdebugStartPost SetUpMicrodebugger()
  autocmd User TermdebugStopPost  TearDownMicrodebugger()
augroup END

# vim: sw=2 sts=2 et
