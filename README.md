# vim-microdebugger

A tiny plugin built on top of Termdebug to play with micro-controllers. It is
written in Vim9 and it relies on `openocd` (to be installed separately).

<p align="center">
<img src="/Microdebugger.png" width="100%" height="100%">
</p>

Microdebugger starts a `openocd` server in a hidden, unlisted buffer so that
you can connect to it using Termdebug as a gdb client. A good overview of how
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

The plugin has been tested on macos, Windows (be careful, read below) and
partially on Linux. When the plugin execution is terminated, you get an error
message about OpenOCD. You can safely ignore it, it is only and `echo` that is
erroneously triggered.

> [!CAUTION]
>
> **For Windows users.** In some cases the output of the gdb console is
> redirected to the `:Source` window for some strange reasons. **BE CAREFUL**
> because this means that the messages that shall be displayed in the gdb
> console are being appended to your source file instead! **Check that your
> source file is not going to be modified!**
>
> To trigger such a behavior you could issue a `Run` followed by `Stop`.
> Whatever you write in the gdb console won't appear there but it is going to
> be appended to your source file.

## Commands

The available commands are:

```
MicroDebug  # Starts the microdebugger
MicroDebugMonitor # Create or jump to the monitor window
MicroDebugOpenocd # Create or jump to the openocd window
MicroDebugAsm # Create or jump to the disassemble window
MicroDebugVar # Create or jump to the variables window
```

The latter are wrappers around `:Asm` and `:Var` commands of Termdebug that
you should use if you use this plugin. Otherwise, the windows layout will get
messy.

## Configuration

The configuration parameters are the following:

```
g:microdebugger_openocd_command # Command to start openocd
g:microdebugger_openocd_waiting_time# If openocd takes time to start up, increase this value (default 1000ms)
g:microdebugger_aux_windows # List of windows to include in the layout. Possible values: 'variables', 'asm', 'monitor', 'openocd'.
g:microdebugger_monitor_command # Program to be executed in the monitor window
g:microdebugger_monitor_waiting_time # If the program in the monitor window takes time to start up, increase this value (default 100ms)
g:microdebugger_gdb_win_height # Height of gdb window (default '')
g:microdebugger_aux_win_pos # Stacked aux windows position: 'L' or 'H' (default 'L')
g:microdebugger_aux_win_width # Width of the stacked aux windows (default &columns / 3)
g:microdebugger_mappings # User-defined mappings
```

Note that you also have to configure `g:termdebug_config['command']` to
specify how the debugger shall be instantiated.

An example of initialization script could be the following:

```
vim9script

g:termdebug_config['command'] = ['arm-none-eabi-gdb', '-ex', 'target extended-remote localhost:3333', '-ex', 'monitor reset']

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

Finally, in addition to the events offered by Termdebug, you have an
additional event `MicrodebuggerStartPost` that you can use in your
auto-commands.

**Happy debugging!**
