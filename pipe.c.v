module runcmd

import os

struct Pipe {
pub:
	r int = -1
	w int = -1
}

fn pipe() !Pipe {
	mut fds := [2]int{}
	if C.pipe(&fds[0]) == -1 {
		return os.last_error()
	}
	return Pipe{fds[0], fds[1]}
}
