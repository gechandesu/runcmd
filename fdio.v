module runcmd

import io
import os

struct ReadFd {
	fd int
}

// read reads the `buf.len` bytes from file descriptor and returns number of
// bytes read on success. This function implements the `io.Reader` interface.
pub fn (mut f ReadFd) read(mut buf []u8) !int {
	if buf.len == 0 {
		return io.Eof{}
	}
	nbytes := int(C.read(f.fd, buf.data, buf.len))
	if nbytes == -1 {
		return os.last_error()
	}
	if nbytes == 0 {
		return io.Eof{}
	}
	return nbytes
}

// slurp reads all data from file descriptor (until gets `io.Eof`) and returns
// result as byte array.
pub fn (mut f ReadFd) slurp() ![]u8 {
	mut res := []u8{}
	bufsize := 4096
	for {
		mut buf := []u8{len: bufsize, cap: bufsize}
		nbytes := f.read(mut buf) or {
			if err is io.Eof {
				break
			} else {
				return err
			}
		}
		if nbytes == 0 {
			break
		}
		res << buf
	}
	return res
}

// close closes the underlying file descriptor.
pub fn (mut f ReadFd) close() ! {
	fd_close(f.fd)!
}

struct WriteFd {
	fd int
}

// write writes the `buf.len` bytes to the file descriptor and returns number
// of bytes written on success. This function implements the `io.Writer` interface.
pub fn (mut f WriteFd) write(buf []u8) !int {
	if buf.len == 0 {
		return 0
	}
	nbytes := int(C.write(f.fd, buf.data, buf.len))
	if nbytes == -1 {
		return os.last_error()
	}
	return nbytes
}

// close closes the underlying file descriptor.
pub fn (mut f WriteFd) close() ! {
	fd_close(f.fd)!
}
