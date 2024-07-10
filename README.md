# vim-microdebugger (WIP)

A plugin built on top of the vim builtin Termdebug to play with
micro-controllers that relies on `openocd` (to be installed separately).

The plugin starts a `openocd` server in a hidden, unlisted buffer so that you
can connect to it using Termdebug as a gdb client. A good explanation is given
in
[this](https://stackoverflow.com/questions/38033130/how-to-use-the-gdb-gnu-debugger-and-openocd-for-microcontroller-debugging-fr)
picture.

At this point, you have pretty much the same interface as Termdebug. I said
"pretty much" because I added some eye-candy features that may not meet the
preferences of some people used to Termdebug layout. Hence, it is perhaps
better to have the chance of two different aesthetic views separate.

Examples of such aesthetic changes are the status lines of the auxiliary
windows that are a bit more clean, the auxiliary buffers are unlisted and
there is the possibility to arrange the windows a bit differently.

Furthermore, you can define more mappings and, in addition to the auxiliary
windows provided by Termdebug, such a variables and disassemble window, you
have an extra window to run an external program, like for example `pyserial`
to monitor the traffic on the serial port.

However, I'll try as much as I can to keep it in sync with Termdebug. For
example, If some of these changes will be included in Termdebug then they will
be removed from here.

The configuration parameters follows with few example settings:

```
g:microdebugger_openocd_command = openocd_cmd
g:microdebugger_aux_windows = ['variables', 'monitor']
g:microdebugger_monitor_command = "ls"
g:microdebugger_gdb_win_height = 8
g:microdebugger_mappings
```

Note that you also have to configure `g:termdebug_config['command']` to
specify how the debugger shall be instantiated.

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
