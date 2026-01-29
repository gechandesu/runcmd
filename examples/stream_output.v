import io
import runcmd

fn main() {
	// Prepare command.
	mut cmd := runcmd.new('sh', '-c', r'for i in {1..5}; do echo line $i; sleep .5; done; echo finish!')

	// This is required to captute standart I/O streams.
	cmd.redirect_stdio = true

	// Start child process.
	pid := cmd.start()!
	println('Child process started with pid ${pid}')

	// Setup StringReader with stdout input. Note the cmd.stdout()! call, it
	// returns the io.Reader interface and reads child process stdout file descriptor.
	mut reader := io.new_buffered_reader(reader: cmd.stdout()!)

	// Read sdtout line by line until EOF.
	for {
		line := reader.read_line() or { break }
		println('Read: ${line}')
	}

	cmd.wait()! // Wait to child process completed.

	println('Child state: ${cmd.state}')
}
