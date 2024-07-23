# vim-microdebugger (WIP)

A tiny plugin built on top of Termdebug to play with micro-controllers. It is
written in Vim9 and it relies on `openocd` (to be installed separately). It
requires Vim 9.1.0602.

<p align="center">
<img src="/Microdebugger.png" width="100%" height="100%">
</p>

Microdebugger starts a `openocd` server in a hidden, unlisted buffer that you
can connect to by using Termdebug as a gdb client. A good overview of how
openocd works along with different clients is given
[here](https://stackoverflow.com/questions/38033130/how-to-use-the-gdb-gnu-debugger-and-openocd-for-microcontroller-debugging-fr).

At this point, you have pretty much the same interface as Termdebug with few
differences: the `debugged-program` window is not used, the status lines are a
bit different, the auxiliary buffers are unlisted, and the overall windows
layout is different. Furthermore, you can define more mappings and you have an
extra window to run an external program, like for example `pyserial` to
monitor the traffic on the serial port.

I'll try as much as I can to keep it in sync with Termdebug. For example, if
some of the mentioned changes will be included in Termdebug then they will be
removed from here.

### Known bugs

The plugin has been tested on macos, Windows (read below) and partially on
Linux.

Sometimes you can get some `Termdebug` errors when launching `Microdebugger`.
In that case, manually add `Termdebug` with `:packadd termdebug`.

When the plugin execution is terminated, you get an error message about
OpenOCD. You can safely ignore it, it is only an `echo` message that is
erroneously triggered.

> [!WARNING]
>
> **For Windows users.** When you run `continue` with no breakpoints it does
> not seem possible to take control back of the gdb console. Ideally, a
> `ctrl-c` should interrupt gdb but it is not the case. You must go on the gdb
> console and execute `<c-w>:close!` to shutoff everything.
>
> However, if you are willing to use an external program for sending `SIGINT`
> signals, then you can set `g:microdebugger_windows_CtrlC_program`. By doing
> that, `ctrl-c` would exploit such a program to interrupt the non-responding
> gdb.
>
> For example, if you use
> [SendSignalCtrlC.exe](https://github.com/SergeyPirogov/video-recorder-java/raw/master/core/src/main/resources/SendSignalCtrlC.exe),
> then you can set
> `g:microdebugger_windows_CtrlC_program = 'SendSignalCtrlC'`. Be sure that
> such a program is in your Windows path. Once done, you have a working
> `:Stop` command mapped locally to `<c-c>`.
>
> **BE CAREFUL** since the command may append garbage to the buffer opened in
> the `:Source` window.

## Commands

The available commands in addition to those provided by Termdebug are the
following:

```
# Starts the microdebugger. Use this to start the microdebugger
:MicroDebug

# Create or jump to the monitor window
:MicroDebugMonitor

# Create or jump to the openocd window
:MicroDebugOpenocd

# Equivalent to `monitor halt`
:MicroDebugHalt

# Equivalent to `monitor resume`
:MicroDebugResume

# Create or jump to the disassemble window
:MicroDebugAsm

# Create or jump to the variables window
:MicroDebugVar
```

Do not use `:Termdebug` to start the MCU debugging but use `:MicroDebug`
instead.

The commands `:MicroDebugAsm` and `:MicroDebugVar` are wrappers around `:Asm`
and `:Var` commands of Termdebug that you should use if you use this plugin.
Otherwise, the windows layout will get messy.

## Configuration

The configuration parameters are the following:

```
# Command to start openocd
g:microdebugger_openocd_command

# If openocd takes time to start up, increase this value (default 1000ms)
g:microdebugger_openocd_waiting_time

# List of windows to include in the layout. Possible values: 'variables', 'asm', 'monitor', 'openocd'.
g:microdebugger_aux_windows

# Program to be executed in the monitor window
g:microdebugger_monitor_command

# If the program in the monitor window takes time to start up, increase this value (default 100ms)
g:microdebugger_monitor_waiting_time

# Height of gdb window (default '')
g:microdebugger_gdb_win_height

# Stacked aux windows position: 'L' or 'H' (default 'L')
g:microdebugger_aux_win_pos

# Width of the stacked aux windows (default &columns / 3)
g:microdebugger_aux_win_width

# User-defined mappings
g:microdebugger_mappings

# Command for sending SIGINT (only for Windows)
g:microdebugger_windows_CtrlC_program
```

Note that you also have to configure `g:termdebug_config['command']` to
specify how the debugger shall be instantiated.

An example of initialization script could be the following:

```
vim9script

g:termdebug_config['command'] = ['arm-none-eabi-gdb', '-ex', 'target extended-remote localhost:3333', '-ex', 'monitor reset']

g:microdebugger_windows_CtrlC_program = 'SendSignalCtrlC'
g:microdebugger_openocd_command = ['openocd', '-f', 'stlink.cfg', '-f', 'stm32f4x.cfg']
# Or something like g:microdebugger_openocd_command = ['cmd.exe', '/c', 'openocd_startup.bat']
g:microdebugger_aux_windows = ['variables', 'monitor']
g:microdebugger_monitor_command = ['screen', '/dev/ttyUSB0', '115200']
g:microdebugger_gdb_win_height = 8
g:microdebugger_mappings = { C: '<Cmd>Continue<CR><cmd>call TermDebugSendCommand("display")<cr>',
    B: '<Cmd>Break<CR><cmd>call TermDebugSendCommand("display")<cr>',
    D: '<Cmd>Clear<CR><cmd>call TermDebugSendCommand("display")<cr>',
    I: '<Cmd>Step<CR><cmd>call TermDebugSendCommand("display")<cr>',
    O: '<Cmd>Over<CR><cmd>call TermDebugSendCommand("display")<cr>',
    F: '<Cmd>Finish<CR><cmd>call TermDebugSendCommand("display")<cr>',
    S: '<Cmd>Stop<CR><cmd>call TermDebugSendCommand("display")<cr>',
    U: '<Cmd>Until<CR><cmd>call TermDebugSendCommand("display")<cr>',
    T: '<Cmd>Tbreak<CR><cmd>call TermDebugSendCommand("display")<cr>'}
```

## Events

The order of execution when launching MicroDebugger is to start openocd
server, to start Termdebug, and to start the auxiliary buffers.

In addition to the events offered by Termdebug, you have an additional event
`MicrodebuggerStartPost` that you can use in your auto-commands.

## Happy debugging!
