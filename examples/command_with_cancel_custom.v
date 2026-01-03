import context
import runcmd
import time

fn main() {
	// Create context with cancel.
	mut bg := context.background()
	mut ctx, cancel := context.with_cancel(mut bg)

	// Create new command as usual.
	mut cmd := runcmd.new('sleep', '120')

	// Set the context...
	cmd.ctx = ctx

	// ...and custom command cancel function.
	cmd.cancel = fn [mut cmd] () ! {
		if cmd.process != none {
			println('Killing ${cmd.process.pid()}!')
			cmd.process.kill()!
		}
	}

	// Start a command.
	println('Start command!')
	cmd.start()!

	// Sleep a bit for demonstration.
	time.sleep(1 * time.second)

	// Cancel command.
	//
	// In a real application, cancel() might be initiated by the user.
	// For example, a command might take too long to execute and need
	// to be canceled.
	//
	// See also command_with_timeout.v example.
	println('Cancel command!')
	cancel()

	// Wait for command.
	cmd.wait()!

	// Since command has been killed, the state would be: `signal: 9 (SIGKILL)`
	println('Child state: ${cmd.state}')
}
