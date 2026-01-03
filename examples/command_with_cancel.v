import context
import runcmd
import time

fn main() {
	// Create context with cancel.
	mut bg := context.background()
	mut ctx, cancel := context.with_cancel(mut bg)

	// Create new command with context.
	mut cmd := runcmd.with_context(ctx, 'sleep', '120')

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

	// Since command has been terminated, the state would be: `signal: 15 (SIGTERM)`
	println('Child state: ${cmd.state}')
}
