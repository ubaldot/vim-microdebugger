# vim-microdebugger

A micro plugin built on top of Termdebug to facilitate remote gdb debugging.
Through this plugin, you should easily debug in docker
containers, micro-controllers (MCUs) and everything that runs a gdbserver.

It is written in Vim9 and it requires Vim 9.1.0602.

<p align="center">
<img src="/Microdebugger.png" width="100%" height="100%">
</p>

Microdebugger starts a server in a hidden, unlisted buffer that you can
connect to by using Termdebug as a gdb client.

The server could be an `openocd` server or a docker container that runs a
gdbserver.

At this point, you have pretty much the same interface as Termdebug with few
differences: the `debugged-program` window is not used, the status lines are a
bit different, the auxiliary buffers are unlisted, and the overall windows
layout is different. Furthermore, you can define more mappings and you have an
extra window called `monitor` to run an external program, like for example `pyserial` to
monitor the traffic on the serial port.

I'll try as much as I can to keep it in sync with Termdebug. For example, if
some of the mentioned changes will be included in Termdebug then they will be
removed from here.

## Commands

The available commands in addition to those provided by Termdebug are the
following:

```
# Starts the microdebugger. Use this to start the microdebugger
:MicroDebug

# Create or jump to the monitor window
:MicroDebugMonitor

# Create or jump to the server window
:MicroDebugServer

# Equivalent to `monitor halt`
:MicroDebugHalt

# Equivalent to `monitor resume`
:MicroDebugResume

# Create or jump to the disassemble window
:MicroDebugAsm

# Create or jump to the variables window
:MicroDebugVar
```

Do not use `:Termdebug` to start remote debugging but use `:MicroDebug`
instead.

The commands `:MicroDebugAsm` and `:MicroDebugVar` are wrappers around `:Asm`
and `:Var` commands of Termdebug that you should use if you use this plugin.
Otherwise, the windows layout will get messy.

## Configuration

The configuration parameters are the following:

```
# Command to start the server
g:microdebugger_server_command

# If the server takes time to start up, increase this value (default 1000ms)
# Note that g:termdebug_config['timeout'] is used in the client side,
# whereas g:microdebugger_server_waiting_time is used in the server side
g:microdebugger_server_waiting_time # [ms]

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

At the bare minimum, you have to establish how to fire up the server and how
to connect to it. This is done through `g:microdebugger_server_command` and
`g:termdebug_config['command']`, respectively.

### Configuration for debugging in docker containers

An example follows:

```
vim9script

g:termdebug_config = {}
g:termdebug_config['command'] = ['gdb', '-ex', 'shell sleep 6', '-ex', 'target extended-remote localhost:1234',
  '-ex', 'set substitute-path /app /home/ubaldot/projects/apollo15']
g:termdebug_config['timeout'] = 800

g:microdebugger_server_command = ['docker run --rm -i -p 1234:1234 my_image  gdbserver "--once --no-startup-with-shell 0.0.0.0:1234 ./build/my_executable"']
```

### Configuration for debugging MCU:s through an openocd server

A good overview of how openocd works along with different clients is given
[here](https://stackoverflow.com/questions/38033130/how-to-use-the-gdb-gnu-debugger-and-openocd-for-microcontroller-debugging-fr).
An example of initialization script could be the following. This time I also
include some mappings.

```
vim9script

g:termdebug_config['command'] = ['arm-none-eabi-gdb', '-ex', 'target extended-remote localhost:3333', '-ex', 'monitor reset']
g:termdebug_config['timeout'] = 500

g:microdebugger_windows_CtrlC_program = 'SendSignalCtrlC'
g:microdebugger_openocd_command = ['openocd', '-f', 'stlink.cfg', '-f', 'stm32f4x.cfg']
# Or something like g:microdebugger_openocd_command = ['cmd.exe', '/c', 'openocd_startup.bat']
g:microdebugger_aux_windows = ['variables', 'monitor']
g:microdebugger_monitor_command = ['screen', '/dev/ttyUSB0', '115200']
g:microdebugger_gdb_win_height = 8
g:microdebugger_server_waiting_time = 5000 # ms

# Some mappings
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

The order of execution when launching MicroDebugger is to start the server,
then start Termdebug, and finally start the auxiliary buffers.

In addition to the events offered by Termdebug, you have an additional event
`MicrodebuggerStartPost` that you can use in your auto-commands.

## Known bugs

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

## Happy debugging!
