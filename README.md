# Run External Commands

`runcmd` module implements a high-level interface for running external commands.

## Why not vlib `os`?

The standard V `os` module already contains many tools for running external commands,
but I don't like any of them. So let's overview.

* `os.execvp()`, `os.execve()` — cross-platform versions of the C functions of the same name.

* `os.execute()`, `os.execute_opt()`, `os.execute_or_exit()`, `os.execute_or_panic()` — starts and waits for a command to completed. Under the hood, they perform a dirty hack by calling shell with stream redirection `'exec 2>&1;${cmd}'`. Only stdout and exit_code are available in Result.

* `util.execute_with_timeout()` (from `os.util`) — just an `os.execute()` wrapper.

* `os.system()` — also executes command in the shell, but does not redirect streams. This is fine for running commands that take a long time and write something to the terminal; it's convenient in build scripts.

* `os.Process` just has an ugly interface with a lot of unnecessary methods. Actually, it's not bad; I copied parts of it.

* `os.Command` calls `C.popen()` under the hood and is not suitable for anything other than running a command in the shell (again) with stream processing of the mixed stdout and stderr.

The obvious downside of this module is that it only works on Linux and likely other
POSIX-compliant operating systems. I'm not interested in working on MS Windows, but
anyone interested can submit a PR on GitHub to support the worst operating system.

## Usage

Basic usage:

```v
import runcmd

mut cmd := runcmd.new('sh', '-c', 'echo Hello,  World!')
cmd.run()! // Start and wait for process.
// Hello, World!
println(cmd.state) // exit status 0
```

If you don't want to wait for the child process to complete, call `start()` instead of `run()`:

```v
mut cmd := runcmd.new('sh', '-c', 'sleep 60')
pid := cmd.start()!
println(pid)
```
`.state` value is unavailable in this case because we didn't wait for the process to complete.

If you need to capture standard output and standard error, use the `output()` and
`combined_output()`. See examples in its description.

To learn more about the `runcmd`'s capabilities and usage, see the [examples](examples)
directory. **Examples are very important**.

## Roadmap

- [x] Basic implementation.
- [x] Contexts support for creating cancelable commands, commands with timeouts, etc.
- [ ] Process groups support, pgkill().
- [ ] Better error handling and more tests...

Send pull requests for additional features/bugfixes.
