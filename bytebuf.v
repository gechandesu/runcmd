module runcmd

import io

// buffer creates simple bytes buffer that can be read through `io.Reader` interface.
pub fn buffer(data []u8) ByteBuffer {
	return ByteBuffer{
		bytes: data
	}
}

struct ByteBuffer {
	bytes []u8
mut:
	pos int
}

// read reads `buf.len` bytes from internal bytes buffer and returns number of bytes read.
pub fn (mut b ByteBuffer) read(mut buf []u8) !int {
	if b.pos >= b.bytes.len {
		return io.Eof{}
	}
	n := copy(mut buf, b.bytes[b.pos..])
	b.pos += n
	return n
}
