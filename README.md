# vim-microdebugger (WIP)

A tiny plugin built on top of Termdebug to play with micro-controllers and
that relies on `openocd` (to be installed separately). This plugin is written
in Vim9.

Microdebugger starts a `openocd` server in a hidden, unlisted buffer so that
you can connect to it using Termdebug as a gdb client. A good explanation is
given in
[this](https://stackoverflow.com/questions/38033130/how-to-use-the-gdb-gnu-debugger-and-openocd-for-microcontroller-debugging-fr)
picture.

At this point, you have pretty much the same interface as Termdebug. I said
"pretty much" because I added some eye-candy features that may not meet the
preferences of some people used to Termdebug layout.

<!-- Hence, it is perhaps -->
<!-- better to have the chance of two different aesthetic views separate. -->

Examples of such aesthetic changes affects auxiliary windows status lines,
auxiliary buffers are now unlisted, and the windows layout is different.

Furthermore, you can define more mappings and, in addition to the auxiliary
windows provided by Termdebug, you have an extra window to run an external
program, like for example `pyserial` to monitor the traffic on the serial
port.

However, I'll try as much as I can to keep it in sync with Termdebug. For
example, If some of these changes will be included in Termdebug then they will
be removed from here.

The available commands are:

```
MicroDebug  # Starts the microdebugger
MicroDebugMonitor # Create or jump to the monitor window
MicroDebugAsm # Create or jump to the disassemble window
MicroDebugVar # Create or jump to the variables window
```

The latter are wrappers around `:Asm` and `:Var` command of Termdebug that you
should use if you use this plugin. Otherwise, the windows layout will get
messy.

The configuration parameters are:

```
g:microdebugger_openocd_command # Command to start openocd
g:microdebugger_aux_windows # List of windows to include in the layout. Possible values: 'variables', 'asm', 'monitor', 'openocd'.
g:microdebugger_monitor_command # Program to be executed in the monitor window
g:microdebugger_gdb_win_height # Height of gdb window
g:microdebugger_mappings # User-defined mappings
```

Note that you also have to configure `g:termdebug_config['command']` to
specify how the debugger shall be instantiated.

An example of initialization script could be the following:

```
vim9script

g:termdebug_config['command'] = ['arm-none-eabi-gdb', '-ex', '"target extended-remote localhost:3333"', '-ex', '"monitor reset"', './build/myfile.elf']

g:microdebugger_openocd_command = ['openocd', '-f', 'stlink.cfg', '-f', 'stm32f4x.cfg']
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
    T: '<Cmd>Tbreak<CR><cmd>call TermDebugSendCommand("display")<cr>',
    X: '<cmd>call TermDebugSendCommand("set confirm off")<cr><cmd>call TermDebugSendCommand("exit")<cr>'}
```

Happy debugging!
