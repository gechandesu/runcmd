/*
	Note: chroot() call requires privilege escalation in the operating system.
	Therefore, to run this example, run: `sudo v run command_with_chroot.c.v`
*/
import os
import runcmd
import term

fn C.chroot(&char) i32

fn main() {
	// Create new root filesystem for demonstration.
	new_root := '/tmp/new_root'

	// Create dirtree and copy `ls` utility with shared objects...
	paths := {
		0: os.join_path(new_root, 'usr', 'bin')
		1: os.join_path(new_root, 'usr', 'lib')
		2: os.join_path(new_root, 'lib64')
	}
	for _, path in paths {
		os.mkdir_all(path)!
	}
	os.cp('/usr/bin/ls', paths[0])!
	os.cp('/usr/lib/libcap.so.2', paths[1])!
	os.cp('/usr/lib/libc.so.6', paths[1])!
	os.cp('/lib64/ld-linux-x86-64.so.2', paths[2])!

	// Create a test file in the new root.
	os.write_file(os.join_path_single(new_root, 'HELLO_FROM_CHROOT'), 'TEST')!

	// Cleanup demo root filesystem at exit.
	defer {
		os.rmdir_all(new_root) or {}
	}

	// Prepare the command.
	mut cmd := runcmd.new('ls', '-alFh', '/')

	// Add pre-exec hook to perform chroot().
	cmd.pre_exec_hooks << fn [new_root] (mut p runcmd.Process) ! {
		if C.chroot(&char(new_root.str)) == -1 {
			return os.last_error()
		}
	}

	// Run command and read its output.
	out := cmd.output() or {
		if err is runcmd.ExitError {
			eprintln(err)
			exit(err.code())
		} else {
			panic(err)
		}
	}

	// Expected output:
	//
	// total 4.0K
	// drwxr-xr-x 4 0 0 100 Jan  8 06:39 ./
	// drwxr-xr-x 4 0 0 100 Jan  8 06:39 ../
	// -rw-r--r-- 1 0 0   4 Jan  8 06:39 HELLO_FROM_CHROOT
	// drwxr-xr-x 2 0 0  60 Jan  8 06:39 lib64/
	// drwxr-xr-x 4 0 0  80 Jan  8 06:39 usr/

	println('Command output: ${term.yellow(out)}')
	println('Child state: ${cmd.state}')
}
