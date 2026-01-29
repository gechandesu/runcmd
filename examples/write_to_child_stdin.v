import io
import strings
import runcmd

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

fn main() {
	input := 'Hello from parent process!'

	// Prepare reader and writer.
	// * `reader` reads input from the parent process; it will be copied to the
	//    standard input of the child process.
	// * `writer` accepts data from the child process; it will be copied from the
	//    standard output of the child process. This is optinal.
	mut reader := ByteBuffer{
		bytes: input.bytes()
	}
	mut writer := strings.new_builder(4096)

	// Prepare the command.
	mut cmd := runcmd.new('cat')

	// Set redirect_stdio to perform I/O copying between parent and child processes.
	cmd.redirect_stdio = true

	// Setup reader and writer for child I/O streams.
	cmd.stdin = reader
	cmd.stdout = writer

	// Start and wait for command.
	cmd.run()!

	// Get command output as string.
	output := writer.str()

	// Make sure that `cat` returned the same data that we sent to it as input.
	assert input == output, 'output data differs from input!'

	println('Child state: ${cmd.state}')
	println('Child output: ${output}')
}
