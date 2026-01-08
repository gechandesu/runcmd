module runcmd

import os

pub type ProcCallbackFn = fn (mut p Process) !

pub struct Process {
pub:
	// Absolute path to the executable.
	path string

	// Arguments that will be passed to the executable.
	argv []string

	// Environment variables that will be applied to the child process.
	env map[string]string

	// Working directory for the child process.
	dir string

	// The *_cb fields stores callback functions that will be executed respectively:
	// - before calling fork();
	// - after calling fork() in the parent process, until the function exits;
	// - after calling fork() in the child process, until the working directory is
	//   changed and execve() is called.
	pre_fork_cb         ProcCallbackFn = fn (mut p Process) ! {}
	post_fork_parent_cb ProcCallbackFn = fn (mut p Process) ! {}
	post_fork_child_cb  ProcCallbackFn = fn (mut p Process) ! {}
mut:
	pid int = -1
}

struct ProcessState {
	pid    int        = -1
	status WaitStatus = -1
}

// pid returns the child process identifier. If process is not
// launched yet -1 wil be returned.
pub fn (s ProcessState) pid() int {
	return s.pid
}

// exited returns true if process is exited.
pub fn (s ProcessState) exited() bool {
	return s.status.exited()
}

// exit_code returns the process exit status code or -1 if process is not exited.
pub fn (s ProcessState) exit_code() int {
	return s.status.exit_code()
}

// success returns true if process if successfuly exited (0 exit status on POSIX).
pub fn (s ProcessState) success() bool {
	return s.status.exit_code() == 0
}

// sys returns the system-specific process state object. For now its always `WaitStatus`.
pub fn (s ProcessState) sys() voidptr {
	// FIXME: Possible V bug: return without explicit voidptr cast corrupts the value...
	// Reproduces with examples/error_handling.v in SIGKILL check.
	// return &s.status
	return unsafe { voidptr(s.status) }
}

// str returns the text representation of process state. For non-started process
// it returns 'unknown' state.
pub fn (s ProcessState) str() string {
	mut str := ''
	match true {
		s.exited() {
			str = 'exit status ${s.exit_code()}'
		}
		s.status.signaled() {
			sig := s.status.term_signal()
			sig_str := os.sigint_to_signal_name(sig)
			str = 'signal: ${sig} (${sig_str})'
		}
		s.status.stopped() {
			str = 'stop signal: ${s.status.stop_signal()}'
		}
		s.status.continued() {
			str = 'continued'
		}
		else {
			str = 'unknown'
		}
	}
	if s.status.coredump() {
		str += ' (core dumped)'
	}
	return str
}

// start starts new child process by performing
// [fork(3p)](https://www.man7.org/linux/man-pages/man3/fork.3p.html) and
// [execve(3p)](https://man7.org/linux/man-pages/man3/exec.3p.html)
// calls. Return value is the child process identifier.
pub fn (mut p Process) start() !int {
	if p.pid != -1 {
		return error('runcmd: process already started')
	}
	printdbg('${@METHOD}: current pid before fork() = ${v_getpid()}')
	printdbg('${@METHOD}: executing pre-fork callback')
	p.pre_fork_cb(mut p)!
	pid := os.fork()
	p.pid = pid
	if pid == -1 {
		return os.last_error()
	}
	printdbg('${@METHOD}: pid after fork() = ${pid}')

	if pid != 0 {
		//
		// This is the parent process
		//

		printdbg('${@METHOD}: executing post-fork parent callback')
		p.post_fork_parent_cb(mut p)!
	} else {
		//
		// This is the child process
		//

		printdbg('${@METHOD}: executing post-fork child callback')
		p.post_fork_child_cb(mut p)!
		if p.dir != '' {
			os.chdir(p.dir)!
		}
		mut env := []string{}
		for k, v in p.env {
			env << k + '=' + v
		}
		os.execve(p.path, p.argv, env)!
	}

	return pid
}

// pid returns the child process identifier. -1 is returned if process is not started.
pub fn (p &Process) pid() int {
	return p.pid
}

// wait waits for process to change state and returns the `ProcessState`.
pub fn (p &Process) wait() !ProcessState {
	printdbg('${@METHOD}: wait for pid ${p.pid}')
	mut wstatus := 0
	if C.waitpid(p.pid, &wstatus, 0) == -1 {
		return os.last_error()
	}
	return ProcessState{
		pid:    p.pid
		status: wstatus
	}
}

// signal sends the `sig` signal to the child process.
pub fn (p &Process) signal(sig os.Signal) ! {
	if C.kill(p.pid, int(sig)) == -1 {
		return os.last_error()
	}
}

// kill send SIGKILL to the child process.
pub fn (p &Process) kill() ! {
	p.signal(.kill)!
}
