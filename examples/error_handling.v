import os
import runcmd

fn main() {
	// Prepare the command.
	mut cmd := runcmd.new('sh', '-c', 'echo -n This command always fails! >&2; sleep 30; false')

	// Run this example with `-d runcmd_trace` to see debug logs.
	// Look for line like this: runcmd[pid=584015]: Process.wait: wait for pid 584016
	// Try to `kill -9 ${pid_here}` while program runs and see whats happen.

	// Run command with capturing its output.
	out := cmd.output() or {
		if err is runcmd.ExitError {
			// Command exited with non-zero code. Handle it here.
			eprintln(err)
			// `err.state` can tell you the failure details.
			eprintln(err.state)
			// Let's check if the process was killed by someone...
			status := runcmd.WaitStatus(err.state.sys())
			if status.term_signal() == int(os.Signal.kill) {
				eprintln('Oh, process is killed... ( x__x )')
			} else {
				// Not killed.
			}
			exit(err.code()) // `err.code()` here contains the command exit status.
		} else {
			// Another error occurred. Most likely, something went wrong while executing
			// the process creation system calls. Check `err.code()` to get the concrete
			// error, it contains the standard C errno value.
			// See https://www.man7.org/linux/man-pages/man3/errno.3.html

			// Replace 0 to actual errno value (real errno never be zero).
			if err.code() == 0 {
				// Do something here...
			}

			// Fallback to panic.
			panic(err)
		}
	}

	println(out)
}
