module runcmd

@[trusted]
fn C.WIFSTOPPED(int) bool

@[trusted]
fn C.WCOREDUMP(int) bool

@[trusted]
fn C.WIFCONTINUED(int) bool

@[trusted]
fn C.WSTOPSIG(int) int

// WaitStatus stores the result value of [wait(2)](https://www.man7.org/linux/man-pages/man2/wait.2.html) syscall.
pub type WaitStatus = u32

// exited returns true if process is exited.
pub fn (w WaitStatus) exited() bool {
	return C.WIFEXITED(w)
}

// exit_code returns the process exit status code or -1 if process is not exited.
pub fn (w WaitStatus) exit_code() int {
	if w.exited() {
		return C.WEXITSTATUS(w)
	}
	return -1
}

// signaled returns true if the child process was terminated by a signal.
pub fn (w WaitStatus) signaled() bool {
	return C.WIFSIGNALED(w)
}

// term_signal returns the number of the signal that caused the child process to terminate.
pub fn (w WaitStatus) term_signal() int {
	if w.signaled() {
		return C.WTERMSIG(w)
	}
	return -1
}

// stopped returns true if the child process was stopped by delivery of a signal.
pub fn (w WaitStatus) stopped() bool {
	return C.WIFSTOPPED(w)
}

// stop_signal returns the number of the signal which caused the child to stop.
pub fn (w WaitStatus) stop_signal() int {
	if w.stopped() {
		return C.WSTOPSIG(w)
	}
	return -1
}

// continued returns true if the child process was resumed by delivery of SIGCONT.
pub fn (w WaitStatus) continued() bool {
	return C.WIFCONTINUED(w)
}

// coredump returns true if the child produced a core dump.
// See [core(5)](https://man7.org/linux/man-pages/man5/core.5.html).
pub fn (w WaitStatus) coredump() bool {
	if w.signaled() {
		return C.WCOREDUMP(w)
	}
	return false
}
