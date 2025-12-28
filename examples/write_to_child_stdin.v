import io.string_reader
import strings
import runcmd

fn main() {
	input := 'Hello from parent process!'

	// Prepare reader and writer.
	//
	// * `reader` reads input from the parent process; it will be copied to the
	//    standard input of the child process.
	// * `writer` accepts data from the child process; it will be copied from the
	//    standard output of the child process.
	mut reader := string_reader.StringReader.new(reader: runcmd.buffer(input.bytes()), source: input)
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
