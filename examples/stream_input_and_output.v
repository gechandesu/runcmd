import io.string_reader
import rand
import runcmd
import time

fn main() {
	// Prepare the command.
	mut cmd := runcmd.new('cat')

	// Setup I/O redirection.
	cmd.redirect_stdio = true

	// Start a process.
	// Note: File descriptors will only become available after the process has started!
	pid := cmd.start()!
	println('Child process started with pid ${pid}')

	// Get child file descriptors.
	mut child_stdin := cmd.stdin()!
	mut child_stdout := cmd.stdout()!

	// Prepare reader to store command output.
	mut output := string_reader.StringReader.new(reader: child_stdout)

	// Start stdout reading in a coroutine.
	//
	// The reader will be block until the descriptor contains data.
	// Therefore, to avoid blocking the main thread, we start the reader
	// in a coroutine.
	go fn [mut output] () {
		println('STDOUT reader started!')
		// Read stdout line by line until EOF.
		for {
			line := output.read_line() or { break }
			println('Recv: ${line}')
		}
	}()

	// Start sending data to child in a loop.
	limit := 5
	for _ in 0 .. limit {
		// Generate some data.
		data := rand.string(10) + '\n'
		print('Send: ${data}')

		// Write data to child stdin file descriptor.
		_ := child_stdin.write(data.bytes())!

		// Sleep a bit for demonstration.
		time.sleep(500 * time.millisecond)
	}

	// Close stdin by hand so that the child process receives EOF.
	// Without this child will hang for waiting for input.
	child_stdin.close()!

	// wait() will close the child stdout file desciptor by itself.
	cmd.wait()!
}
