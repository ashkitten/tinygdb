# about this project

sooooo i realized around 20 hours into the project, by which time it had
achieved an almost-working state, that essentially what i'm doing is equivalent
to using gdb to launch a program that launches your executable, which makes it
immune to gdb's stricter checks. it proved to be a good coding exercise and
maybe i'll end up finishing it later and possibly adding more features? anyways
don't bother using this probably, here's a command that's basically equivalent:

```
gdb env -ex 'set args <program and args>' -ex 'catch exec'
```
