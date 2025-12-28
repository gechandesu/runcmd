import runcmd
import os
import io.util

fn make_temp_file() !string {
	_, path := util.temp_file()!
	os.chmod(path, 0o700)!
	dump(path)
	return path
}

fn test_lookup() {
	path := make_temp_file()!
	defer { os.rm(path) or {} }
	assert os.is_abs_path(runcmd.look_path(path)!)
	assert runcmd.look_path('/nonexistent') or { '' } == ''
	assert runcmd.look_path('env')! == '/usr/bin/env'
}

fn test_is_present() {
	path := make_temp_file()!
	defer { os.rm(path) or {} }
	assert runcmd.is_present(path)
}
