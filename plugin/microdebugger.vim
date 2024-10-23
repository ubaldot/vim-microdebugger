vim9script noclear

# A tiny plugin on top of Termdebug for gdb remote debugging.
# Maintainer: Ubaldo Tiberi
# License: Vim license
#
#
#
if !has('vim9script') ||  v:version < 901
  finish
endif

if exists('g:microdebugger_loaded') && g:microdebugger_loaded
    Echoerr('Plugin already loaded.')
    finish
endif
g:microdebugger_loaded = true

def Echoerr(msg: string)
  echohl ErrorMsg | echom $'[microdebugger] {msg}' | echohl None
enddef

def Echowarn(msg: string)
  echohl WarningMsg | echom $'[microdebugger] {msg}' | echohl None
enddef

command! -nargs=? -complete=file MicroDebug MicrodebuggerStart(<f-args>)

# Script global variables
var server_bufname: string
var server_bufnr: number
var server_win: number
# var server_failure: bool

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
var server_term_waiting_time: number

var existing_mappings: dict<any>
var ctrl_c_map_saved: dict<any>
var tab_map_saved: dict<any>

var ctrl_c_program: string

# UBA
var microdebugger_tabnr = -1

def InitScriptVars()
  server_bufname = 'SERVER'
  # term_start returns 0 if the job fails to start. Hence, it is safer to use
  # -1 as initial condition
  server_bufnr = -1
  server_win = 0

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
  aux_windows = {variables: GotoOrCreateVarWindow, monitor: GotoOrCreateMonitorWindow, asm: GotoOrCreateAsmWindow, server: GotoOrCreateServerWindow}
  aux_bufnames = {variables: var_bufname, monitor: monitor_bufname, asm: asm_bufname, server: server_bufname}
  aux_windows_pos = get(g:, 'microdebugger_aux_win_pos', 'L')
  aux_windows_width = get(g:, 'microdebugger_aux_win_width', &columns / 3)

  monitor_term_waiting_time = get(g:, 'microdebugger_monitor_waiting_time', 1000)
  server_term_waiting_time = get(g:, 'microdebugger_server_waiting_time', 1000)

  existing_mappings = {}
  ctrl_c_map_saved = {}
  tab_map_saved = {}

  g:termdebug_config['variables_window'] = false
  g:termdebug_config['disasm_window'] = false

  ctrl_c_program = get(g:, 'microdebugger_windows_CtrlC_program', '')

  microdebugger_tabnr = -1
enddef

def SanityCheck(): bool
  var is_check_ok = true

  # TODO: this is tricky to verify as it may execute a .sh script
  # if !executable('openocd')
  #   Echoerr("'openocd' not found. Cannot start the debugger" )
  #   is_check_ok = false
  # endif

  if !exists('g:termdebug_config')
    Echoerr("'g:termdebug_config' is not set" )
    is_check_ok = false
  elseif !has_key(g:termdebug_config, 'command')
    Echoerr("'g:termdebug_config['command']' is not set" )
    is_check_ok = false
  endif

  if !exists('g:microdebugger_server_command')
    Echoerr("'g:microdebugger_server_command' is not set" )
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

  if has('win32') && empty(ctrl_c_program)
    Echowarn("Cannot find a program for Ctrl-C. :Stop command is disabled")
  elseif has('win32') && !executable(ctrl_c_program)
    Echowarn($"Cannot find {ctrl_c_program} for Ctrl-C. :Stop command is disabled")
  endif

  return is_check_ok
enddef

def ServerExitHandler(job_id: any, exit_status: number)
  if exit_status != 0
    Echoerr('Server detected some errors. Microdebugger will not work')
    # server_failure = true
  endif
enddef

def MicrodebuggerStart(filename: string = '')
  if exists('g:termdebug_is_running') && g:termdebug_is_running
    Echoerr('Terminal debugger is already running, cannot run two')
    return
  endif

  InitScriptVars()
  if !SanityCheck()
    return
  endif

  # TODO: Check if this appears
  echo "Microdebugger is starting ... "
  if !exists('g:termdebug_loaded')
    packadd! termdebug
  endif

  # UBA
  tab split
  microdebugger_tabnr = tabpagenr()

  # 1. Start server
  silent! server_bufnr = term_start(g:microdebugger_server_command, {term_name: server_bufname, hidden: 1, exit_cb: ServerExitHandler})
  if server_bufnr == 0
    Echoerr('Invlid Server opening command. Microdebbugger will not start. Check ''g:microdebugger_server_command'' variable')
    ShutoffMicrodebugger()
    return
  endif
  term_wait(server_bufname, server_term_waiting_time)
  setbufvar(server_bufname, "&buflisted", false)

  # For debugging
  # var server_job = term_getjob(server_bufnr)
  # ch_logfile('logfile', 'w')
  # ch_log('server log')


  # 2. Start Termdebug and connect the gdb client to server (see g:termdebug_config['command'])
  execute $"Termdebug {filename}"
  exe ":Gdb"

  # Fix prompt mode autocompletion
  if g:termdebug_config->get('use_prompt', false) || has('win32')
    tab_map_saved = maparg('<tab>', 'i', false, true)
    inoremap <buffer> <tab> <c-x><c-f>
  endif

  if executable(ctrl_c_program) && has('win32')
    ctrl_c_map_saved = maparg('<c-c>', 'i', false, true)
    inoremap <buffer> <C-c> <cmd>Stop<cr>
  endif
  gdb_bufname = bufname()
  gdb_bufnr = bufnr()
  gdb_win = win_getid()
  setbufvar(gdb_bufname, "&buflisted", false)
  setbufvar(gdb_bufname, "&bufhidden", 'wipe')
  setwinvar(gdb_win, '&statusline', '%#StatusLine# %t(%n)%m%*' )
  # setlocal wildmode=list:longest

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
  for key in g:microdebugger_aux_windows
    aux_windows[key]()
  endfor
enddef

def AuxBuffersWinIDs(): list<number>
  # Return a list of windows ID:s displaying aux buffers
  var displayed_aux_buffers = []
  for key in g:microdebugger_aux_windows
    var aux_buf_nr = bufnr(aux_bufnames[key])
    var win_containing_buf = bufwinid(aux_buf_nr)
    if bufexists(aux_buf_nr) && aux_buf_nr > 0 && win_containing_buf != -1
      add(displayed_aux_buffers, win_containing_buf)
    endif
  endfor
  return displayed_aux_buffers
enddef

def ResizeAuxWindows()
  if win_gotoid(server_win)
    win_execute(server_win, $'vertical resize {aux_windows_width}')
  elseif win_gotoid(monitor_win)
    win_execute(monitor_win, $'vertical resize {aux_windows_width}')
  endif
enddef

def GotoOrCreateVarWindow()
  if !win_gotoid(var_win)
    exe "Var"
    setbufvar(var_bufname, "&buflisted", false)
    var_bufnr = bufnr(var_bufname)
    var_win = win_getid()
    SetWindowCommon(var_win)
    setwinvar(var_win, '&statusline', '%#StatusLine# %t(%n)%m%*' )
  endif
  win_execute(var_win, $'vertical resize {aux_windows_width}')
  # if exists('g:microdebugger_var_win_height')
  #   win_execute(var_win, $'resize {g:microdebugger_var_win_height}')
  # endif
enddef

def GotoOrCreateAsmWindow()
  if !win_gotoid(asm_win)
    exe "Asm"
    setbufvar(asm_bufname, "&buflisted", false)
    asm_bufnr = bufnr(asm_bufname)
    asm_win = win_getid()
    SetWindowCommon(asm_win)
    setwinvar(asm_win, '&statusline', '%#StatusLine# %t(%n)%m%*' )
  endif
  win_execute(asm_win, $'vertical resize {aux_windows_width}')
  # if exists('g:microdebugger_asm_win_height')
  #   win_execute(asm_win, $'resize {g:microdebugger_asm_win_height}')
  # endif
enddef

def GotoOrCreateMonitorWindow()
  if !win_gotoid(monitor_win)
    if index(term_list(), monitor_bufnr) == -1
      CreateMonitorWindow()
    else
      split
      exe $"buffer {monitor_bufnr}"
    endif
    monitor_win = win_getid()
    SetWindowCommon(monitor_win)
    setwinvar(monitor_win, '&statusline', '%#StatusLine# %t(%n)%m%*' )
  endif
  win_execute(monitor_win, $'vertical resize {aux_windows_width}')
  # if exists('g:microdebugger_monitor_win_height')
  #   win_execute(monitor_win, $'resize {g:microdebugger_monitor_win_height}')
  # endif
enddef

def GotoOrCreateServerWindow()
  if !win_gotoid(server_win)
    split
    exe "buffer " .. server_bufnr
    server_win = win_getid()
    SetWindowCommon(server_win)
    setwinvar(server_win, '&statusline', '%#StatusLine# %t(%n)%m%*' )
  endif
  win_execute(server_win, $'vertical resize {aux_windows_width}')
enddef

def SetWindowCommon(current_winid: number)
  # If it is the first window, then place it in a side. Otherwise, stack to
  # the existings
  var aux_buf_winids = AuxBuffersWinIDs()

  var current_idx = index(aux_buf_winids, current_winid)
  var current_win_nr = win_id2win(aux_buf_winids[current_idx])
  var near_winnr = -1

  if current_idx == 0 && len(aux_buf_winids) == 1
    exe $'wincmd {aux_windows_pos}'
  elseif current_idx == 0 && len(aux_buf_winids) > 1
    near_winnr = win_id2win(aux_buf_winids[1])
  else
    near_winnr = win_id2win(aux_buf_winids[current_idx - 1])
  endif

  if near_winnr > 0
    win_splitmove(current_win_nr, near_winnr)
  endif
enddef

def MonitorExitHandler(job_id: any, exit_status: number)
  if exit_status != 0
    Echoerr('The monitor program cannot start.')
  endif
enddef

def CreateMonitorWindow()
  # If exists, then open, otherwise create
  silent! monitor_bufnr = term_start(join(g:microdebugger_monitor_command), {term_name: monitor_bufname, exit_cb: MonitorExitHandler})
  if monitor_bufnr == 0
    Echoerr('Monitor program cannot start.')
    return
  endif
  term_wait(monitor_bufnr, monitor_term_waiting_time)

  setbufvar(monitor_bufnr, "&wrap", false)
  setbufvar(monitor_bufnr, "&swapfile", false)
  setbufvar(monitor_bufnr, "&bufhidden", 'hide')
  setbufvar(monitor_bufnr, "&buflisted", false)
  setbufvar(monitor_bufnr, "&signcolumn", 'no')
enddef

def InterruptGdb()
  if executable(ctrl_c_program) && has('win32')
    var gdb_pid =  system('powershell -Command "Get-Process -Name ' .. gdb_bufname .. '| ForEach-Object { $_.Id }"')
    silent! exe $"!SendSignalCtrlC.exe {gdb_pid}"
  else
    Echoerr('SendSignalCtrlC.exe not found. Please, consider to download it and include it in the PATH.')
  endif
enddef


def SetUpMicrodebugger()

  # Stop command for Windows
  if executable(ctrl_c_program) && has('win32')
    command! Stop InterruptGdb()
  elseif has('win32')
    command! Stop Echoerr("Cannot find a program for Ctrl-C. :Stop command is disabled")
  endif

  command! MicroDebugAsm GotoOrCreateAsmWindow()
  command! MicroDebugVar GotoOrCreateVarWindow()
  command! MicroDebugMonitor GotoOrCreateMonitorWindow()
  command! MicroDebugServer GotoOrCreateServerWindow()
  command! MicroDebugHalt g:TermDebugSendCommand("-interpreter-exec console \"monitor halt\"")
  command! MicroDebugResume g:TermDebugSendCommand("-interpreter-exec console \"monitor resume\"")

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
  job_stop(term_getjob(server_bufnr), "kill")
  if monitor_bufnr != -1
    job_stop(term_getjob(monitor_bufnr), "kill")
  endif

  # For debugging
  # echom job_status(term_getjob(server_bufnr))
  # echom job_status(term_getjob(monitor_bufnr))

  var bufnumbers = [monitor_bufnr, server_bufnr, gdb_bufnr]
  for bufnr in bufnumbers
    if bufnr > 0 && bufexists(bufnr)
      exe $'bwipe! {bufnr}'
    endif
  endfor
  exe $":tabclose {microdebugger_tabnr}"
enddef

def TearDownMicrodebugger()
  # Use this to shutoff everything AFTER TermdebugStartPost event is
  # triggered

  delcommand MicroDebugAsm
  delcommand MicroDebugVar
  delcommand MicroDebugMonitor
  delcommand MicroDebugServer
  delcommand MicroDebugHalt
  delcommand MicroDebugResume

  if exists('g:microdebugger_mappings')
    for key in keys(g:microdebugger_mappings)
      if has_key(existing_mappings, key)
        mapset('n', 0, existing_mappings[key])
      else
        exe $"nunmap {key}"
      endif
    endfor
  endif

  if !empty(ctrl_c_map_saved)
    mapset('i', 0, ctrl_c_map_saved)
  endif
  if !empty(tab_map_saved)
    mapset('i', 0, tab_map_saved)
  endif

  ShutoffMicrodebugger()
enddef

augroup MicrodebuggerSetUpTearDown
  autocmd!
  autocmd User MicrodebuggerStartPost SetUpMicrodebugger()
  autocmd User TermdebugStopPost  TearDownMicrodebugger()
augroup END

# vim: sw=2 sts=2 et
