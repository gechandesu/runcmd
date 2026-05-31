module runcmd

import os

@[if runcmd_trace ?]
fn printdbg(s string) {
	text := 'runcmd[pid=${v_getpid()}]: ${s}'
	eprintln(text)
	trace_file := $d('runcmd_trace_file', '')
	if trace_file != '' {
		file := os.open_append(trace_file) or { return }
		file.write_string(text + '\n') or {}
		file.flush()
	}
}
