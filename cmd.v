module runcmd

import context
import io
import os
import strings

type IOCopyFn = fn () !

pub type CommandCancelFn = fn () !

@[heap]
pub struct Command {
pub mut:
	// path may be a command name or absolute path to executable.
	// If the specified path is not absolute, it will be obtained
	// using the look_path() function before starting the process.
	path string

	// args holds command line arguments passed to the executable.
	args []string

	// env contains key-value pairs of environment variables that
	// will be passed to the process. If not specified the current
	// os.environ() will be used. If you want to update current
	// environ instead of overriding it, use merge() function from
	// `maps` module: `maps.merge(os.environ(), {'MYENV': 'value'})`
	env map[string]string

	// dir specifies the working directory for the child process.
	// If not specified, the current working directory of parent
	// will be used.
	dir string

	// If true create pipes for standart in/out/err streams and
	// duplicate child streams to created file descriptors.
	// redirect_stdio is required for work with child I/O.
	redirect_stdio bool

	// If the field is filled (any of stdin, stdout, stderr), then
	// after the process is started, a coroutine will be launched
	// in the background, which will copy the corresponding data
	// stream between the child and parent processes.
	//
	// This fields must be set BEFORE calling the start() function.
	//
	// This is useful if we want to feed data to the child process
	// via standard input or read stdout and/or stderr entirely.
	// Since the coroutines copies the stream continuously in a loop,
	// the data can only be processed once it has been completely
	// read. To process data in chunks, do not set these fields, but
	// use the stdin(), stdout() and stderr() functions to obtain
	// the child process's file descriptors after calling start().
	stdin  ?io.Reader
	stdout ?io.Writer
	stderr ?io.Writer

	// ctx holds a command context. It may be used to make a command
	// cancelable or set timeout/deadline for it.
	ctx ?context.Context

	// cancel function is used to terminate the child process. Do
	// not confuse with the context's cancel function.
	//
	// The default command cancel function created in with_context()
	// terminates the command by sending SIGTERM signal to child. You
	// can override it by setting your own command cancel function.
	// If cancel is none the child process won't be terminated even
	// if context is timed out or canceled.
	cancel ?CommandCancelFn

	// pre_exec_hooks will be called before starting the command in
	// the child process. Hooks can be used to modify a child's envi-
	// ronment, for example to perform a chroot.
	pre_exec_hooks []ProcessHookFn

	// process holds the underlying Process once started.
	process ?&Process

	// state holds an information about underlying process.
	// This is set only if process if finished. Call `run()`
	// or `wait()` to get actual state value.
	// This value MUST NOT be changed by API user.
	state ProcessState
mut:
	// stdio holds a file descriptors for I/O processing.
	// There is:
	// * 0 — child process stdin, we must write into it.
	// * 1 — child process stdout, we must read from it.
	// * 2 — child process stderr, we must read from it.
	stdio [3]int = [-1, -1, -1]!

	// stdio_copy_fns is array of closures to copy data between
	// parent and child processes. For standard I/O streams
	// it does (if some of .stdin, .stdout and .stderr fields is set):
	// * read from .stdin reader and write data into child stdin fd.
	// * read from child stdout fd and write into .stdout writer.
	// * read from child stderr fd and write into .stderr writer.
	stdio_copy_fns []IOCopyFn
}

// run starts a specified command and waits for it. After call see the `.state`
// value to get finished process identifier, exit status and other attributes.
// `run()` is shorthand for:
// ```v
// cmd.start()!
// cmd.wait()!
// ```
pub fn (mut c Command) run() ! {
	c.start()!
	c.wait()!
}

// output runs the command and returns its stdout on success. If command exit
// status is non-zero `ExitError` error is returned.
// Example:
// ```v
// import runcmd
//
// mut okcmd := runcmd.new('sh', '-c', 'echo Hello, World!')
// ok_out := okcmd.output()!
// println(ok_out)
// // Hello, World!
//
// mut badcmd := runcmd.new('sh', '-c', 'echo -n Error! >&2; false')
// bad_out := badcmd.output() or {
// 	if err is runcmd.ExitError {
// 		eprintln(err)
// 		exit(err.code())
// 	} else {
// 		// error starting process or handling I/O, see errno in err.code().
// 		panic(err)
// 	}
// }
// println(bad_out)
// // &runcmd.ExitError{
// //    state: exit status 1
// //    stderr: 'Error!'
// // }
// ```
pub fn (mut c Command) output() !string {
	mut out := strings.new_builder(2048)
	mut err := strings.new_builder(2048)
	c.redirect_stdio = true
	c.stdout = out
	c.stderr = err
	c.start()!
	c.wait()!
	if !c.state.success() {
		return ExitError{
			state:  c.state
			stderr: err.str()
		}
	}
	return out.str()
}

// combined_output runs the command and returns its combined stdout and stderr.
// Unlike `output()`, this function does not return `ExitError` on command failure.
// Note: The order of lines from stdout and stderr is not guaranteed, since
// reading from the corresponding file descriptors is done concurrently.
// Example:
// ```v
// import runcmd
// mut cmd := runcmd.new('sh', '-c', 'echo Hello, STDOUT!; echo Hello, STDERR! >&2')
// output := cmd.combined_output()!
// println(output)
// // Hello, STDOUT!
// // Hello, STDERR!
// ```
pub fn (mut c Command) combined_output() !string {
	mut out := strings.new_builder(4096)
	c.redirect_stdio = true
	c.stdout = out
	c.stderr = out
	c.start()!
	c.wait()!
	return out.str()
}

// start starts a specified command and does not wait for it to complete. Call
// `wait()` after `start()` has successfully completed to wait for the command
// to complete and release associated resources.
// Note: `.state` field is not set after `start()` call.
pub fn (mut c Command) start() !int {
	if c.process != none {
		return error('runcmd: process already started')
	}

	mut pipes := [3]Pipe{}
	if c.redirect_stdio {
		pipes[0] = pipe()! // stdin
		pipes[1] = pipe()! // stdout
		pipes[2] = pipe()! // stderr
	}

	parent_pipes_hook := fn [mut c, pipes] (mut p Process) ! {
		if !c.redirect_stdio {
			return
		}
		c.stdio[0] = pipes[0].w
		c.stdio[1] = pipes[1].r
		c.stdio[2] = pipes[2].r
		fd_close(pipes[0].r)!
		fd_close(pipes[1].w)!
		fd_close(pipes[2].w)!
	}

	child_pipes_hook := fn [mut c, pipes] (mut p Process) ! {
		printdbg('child pipes hook!')
		if !c.redirect_stdio {
			return
		}
		fd_close(pipes[0].w)!
		fd_close(pipes[1].r)!
		fd_close(pipes[2].r)!
		fd_dup2(pipes[0].r, 0)!
		fd_dup2(pipes[1].w, 1)!
		fd_dup2(pipes[2].w, 2)!
		fd_close(pipes[0].r)!
		fd_close(pipes[1].w)!
		fd_close(pipes[2].w)!
	}

	mut pre_exec_hooks := [child_pipes_hook]
	pre_exec_hooks << c.pre_exec_hooks

	if c.redirect_stdio {
		if c.stdin != none {
			c.stdio_copy_fns << fn [mut c] () ! {
				printdbg('Command.start: stdin copy callback called')
				mut fd := c.stdin()!
				printdbg('Command.start: stdin copy callback: child stdin fd=${fd.fd}')
				if c.stdin != none {
					// FIXME: V bug?: without `if` guard acessing
					// to c.stdin causes SIGSEGV.
					io_copy(mut c.stdin, mut fd, 'copy stdin')!
					printdbg('Command.start: stdin copy callback: close child stdin fd after copy')
					fd_close(fd.fd)!
				}
			}
		}
		if c.stdout != none {
			c.stdio_copy_fns << fn [mut c] () ! {
				printdbg('Command.start: stdout copy callback called')
				mut fd := c.stdout()!
				if c.stdout != none {
					io_copy(mut fd, mut c.stdout, 'copy stdout')!
				}
			}
		}
		if c.stderr != none {
			c.stdio_copy_fns << fn [mut c] () ! {
				printdbg('Command.start: stderr copy callback called')
				mut fd := c.stderr()!
				if c.stderr != none {
					io_copy(mut fd, mut c.stderr, 'copy stderr')!
				}
			}
		}
	}

	// Prepare and start child process.
	path := look_path(c.path)!
	printdbg('${@METHOD}: executable found: ${path}')
	c.path = path
	c.process = &Process{
		path:      path
		argv:      c.args
		env:       if c.env.len == 0 { os.environ() } else { c.env }
		dir:       os.abs_path(c.dir)
		post_fork: [parent_pipes_hook]
		pre_exec:  pre_exec_hooks
	}

	mut pid := -1
	if c.process != none {
		pid = c.process.start()!
	}

	// Start I/O copy callbacks.
	if c.stdio_copy_fns.len > 0 {
		for f in c.stdio_copy_fns {
			go fn (func IOCopyFn) {
				printdbg('Command.start: starting I/O copy closure in coroutine')
				func() or { eprintln('error in I/O copy coroutine: ${err}') }
			}(f)
		}
	}

	if c.ctx != none {
		printdbg('${@METHOD}: start watching for context')
		go c.ctx_watch()
	}

	return pid
}

fn (mut c Command) ctx_watch() {
	mut ch := chan int{}
	if c.ctx != none {
		ch = c.ctx.done()
	}
	for {
		select {
			_ := <-ch {
				printdbg('${@METHOD}: context is canceled/done')
				if c.cancel != none {
					printdbg('${@METHOD}: cancel command now!')
					c.cancel() or { eprintln('error canceling command: ${err}') }
					printdbg('${@METHOD}: command canceled!')
				}
				return
			}
		}
	}
}

// wait waits to previously started command is finished. After call see the `.state`
// field value to get finished process identifier, exit status and other attributes.
// `wait()` will return an error if the process has not been started or wait has
// already been called.
pub fn (mut c Command) wait() ! {
	if c.process == none {
		return error('runcmd: wait for non-started process')
	} else if c.state != ProcessState{} {
		return error('runcmd: wait already called')
	}
	if c.process != none {
		c.state = c.process.wait()!
	}
	unsafe { c.release()! }
}

// release releases all resources assocuated with process.
@[unsafe]
pub fn (mut c Command) release() ! {
	for fd in c.stdio {
		if fd == -1 {
			continue
		}
		fd_close(fd) or {
			if err.code() == 9 {
				// Ignore EBADF error, fd is already closed.
				continue
			}
			printdbg('${@METHOD}: cannot close fd: ${err}')
			return err
		}
	}
}

// stdin returns an open file descriptor associated with the standard
// input stream of the child process. This descriptor is write-only for
// the parent process.
pub fn (c Command) stdin() !WriteFd {
	return if c.stdio[0] != -1 {
		WriteFd{c.stdio[0]}
	} else {
		printdbg('${@METHOD}: invalid fd -1')
		error_with_code('Bad file descriptor', 9)
	}
}

// stdout returns an open file descriptor associated with the standard
// output stream of the child process. This descriptor is read-only for
// the parent process.
pub fn (c Command) stdout() !ReadFd {
	return if c.stdio[1] != -1 {
		ReadFd{c.stdio[1]}
	} else {
		printdbg('${@METHOD}: invalid fd -1')
		error_with_code('Bad file descriptor', 9)
	}
}

// stderr returns an open file descriptor associated with the standard
// error stream of the child process. This descriptor is read-only for
// the parent process.
pub fn (c Command) stderr() !ReadFd {
	return if c.stdio[2] != -1 {
		ReadFd{c.stdio[2]}
	} else {
		printdbg('${@METHOD}: invalid fd -1')
		error_with_code('Bad file descriptor', 9)
	}
}

pub struct ExitError {
pub:
	state  ProcessState
	stderr string
}

// code returns an exit status code of a failed process.
pub fn (e ExitError) code() int {
	return e.state.exit_code()
}

// msg returns message about command failure.
pub fn (e ExitError) msg() string {
	return 'command exited with non-zero code'
}

// io_copy is copypasta from io.cp() with some debug logs.
fn io_copy(mut src io.Reader, mut dst io.Writer, msg string) ! {
	mut buf := []u8{len: 4096}
	defer {
		unsafe {
			buf.free()
		}
	}
	for {
		nr := src.read(mut buf) or {
			printdbg('${@FN}: (${msg}) got error from reader, breaking loop: ${err}')
			break
		}
		printdbg('${@FN}: (${msg}) ${nr} bytes read from src to buf')
		nw := dst.write(buf[..nr]) or { return err }
		printdbg('${@FN}: (${msg}) ${nw} bytes written to dst')
	}
}

// Wrap os.fd_* functions for errors handling...

fn fd_close(fd int) ! {
	if os.fd_close(fd) == -1 {
		return os.last_error()
	}
}

fn fd_dup2(fd1 int, fd2 int) ! {
	if os.fd_dup2(fd1, fd2) == -1 {
		return os.last_error()
	}
}
