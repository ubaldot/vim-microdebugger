# vim-microdebugger

A plugin built on top of the vim builtin Termdebug to deal with
micro-controllers.

It starts a openocd server in a hidden, unlisted buffer so that it is possible
to connect to it using termdebug as a gdb client. This mean that you need to
install `openocd`. Furthermore, it is possible to monitor the output of some
external program (think for example to run `pyserial` to monitor the traffic
on the serial port) in a dedicated window.

```
g:microdebugger_openocd_command = openocd_cmd
g:microdebugger_aux_windows
g:microdebugger_monitor_command = "ls"
g:microdebugger_gdb_win_height = 8
g:microdebugger_mappings
g:microdebugger_monitor_win_height = 20
```

I'll try as much as I can to keep it in sync with Termdebug.

However, compared to Termdebug, some sugar-syntactic changes has been added.
For example, the status lines of the auxiliary windows are kept clean, the
"backend" buffers are unlisted, there is the possibility to arranging the
windows a bit differently, there is the possibility of having more mappings,
etc. If some of these changes will be included in Termdebug then they will be
removed from here.
