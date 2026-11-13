# tmux cheat sheet

Default `Ctrl-b` prefix, mouse on, vi keys in copy mode. Every key follows the prefix unless it is a shell command or a mouse action.

```
PREFIX = Ctrl-b                          (press, release, then the key)

SESSIONS                                 WINDOWS (tabs)
  d      detach (everything keeps running)  c      new window
  s      session picker                     n / p  next / previous
  $      rename session                     0-9    jump to window N
  ( / )  previous / next session            l      last-used window
  L      last-used session                  w      window picker (all sessions)
                                            ,      rename window
  shell:                                    &      kill window
  tmux ls                  list sessions    .      move window to number N
  tmux new -A -s NAME      attach or create
  tmux attach -t NAME      attach
  tmux kill-session -t NAME
  tmux kill-server         stop everything

PANES (splits)                           COPY MODE / SCROLLBACK (vi keys)
  %      split left | right                 [      enter copy mode
  "      split top / bottom                 PgUp   enter copy mode, scrolled up
  arrows move between panes                 q      exit copy mode
  o      next pane                          h j k l, arrows   move
  ;      last-used pane                     Ctrl-u / Ctrl-d   half page up / down
  z      zoom pane full-window (toggle)     g / G  top / bottom of history
  x      kill pane                          / ?    search forward / backward
  !      break pane out to its own window   n / N  next / previous match
  Space  cycle layouts                      Space  start selection
  { / }  swap pane with previous / next     v      toggle rectangle selection
  q      show pane numbers (press N to go)  Enter  copy selection and exit
  Ctrl-arrows   resize by 1                 ]      paste tmux buffer
  Alt-arrows    resize by 5                 =      choose from buffer history

MOUSE                                    MISC
  wheel        scroll history               ?      list all key bindings
  drag         select + copy to clipboard   :      tmux command prompt
  Shift+drag   terminal-native selection    Ctrl-b send a literal Ctrl-b to the app
  click        focus pane / window          t      clock
  drag border  resize pane                  D      choose a client to detach
  double / triple click  copy word / line   :source ~/.tmux.conf   reload config
```
