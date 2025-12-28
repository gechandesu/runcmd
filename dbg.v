module runcmd

@[if runcmd_trace ?]
fn printdbg(s string) {
	eprintln('runcmd[pid=${v_getpid()}]: ${s}')
}
