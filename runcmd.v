module runcmd

import os

// new creates new Command instance with given command name and arguments.
pub fn new(name string, arg ...string) &Command {
	return &Command{
		path: name
		args: arg
	}
}

// is_present returns true if cmd is present on system. cmd may be a command
// name or filepath (relative or absolute).
// The result relies on `look_path()` output, see its docs for command search
// details.
pub fn is_present(cmd string) bool {
	_ := look_path(cmd) or { return false }
	return true
}

// look_path returns the absolute path to executable file. cmd may be a command
// name or filepath (relative or absolute). If the name contains a slash, then the
// PATH search is not performed, instead the path will be resolved and the file
// existence and its permissions will be checked (execution must be allowed).
// Note: To use executables located in the current working directory use './file'
// instead of just 'file'. Searching for executable files in the current directory
// is disabled for security reasons. See https://go.dev/blog/path-security.
pub fn look_path(cmd string) !string {
	if cmd.is_blank() {
		return os.ExecutableNotFoundError{}
	}

	// Do not search executable in PATH if its name contains a slashes (as POSIX-shells does),
	// See PATH in: https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap08.html#tag_08_03

	if cmd.contains('/') {
		actual_path := os.abs_path(os.expand_tilde_to_home(os.norm_path(cmd)))
		if is_executable_file(actual_path) {
			return actual_path
		} else {
			return os.ExecutableNotFoundError{}
		}
	}

	paths := os.getenv('PATH').split(os.path_delimiter)

	for path in paths {
		if path in ['', '.'] {
			// Prohibit current directory.
			continue
		}
		actual_path := os.abs_path(os.join_path_single(path, cmd))
		if is_executable_file(actual_path) {
			return actual_path
		}
	}

	return os.ExecutableNotFoundError{}
}

fn is_executable_file(file string) bool {
	return os.is_file(file) && os.is_executable(file)
}
