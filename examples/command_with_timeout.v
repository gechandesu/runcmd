import context
import runcmd
import time

fn main() {
	// Create context with cancel.
	mut bg := context.background()
	mut ctx, _ := context.with_timeout(mut bg, 10 * time.second)

	// Create new command with context.
	mut cmd := runcmd.with_context(ctx, 'sleep', '120')

	// Start a command.
	cmd.start()!
	started := time.now()
	println('Command started at ${started}')

	// Wait for command.
	cmd.wait()!

	// The `sleep 120` command would run for two minutes without a timeout.
	// But in this example, it will time out after 10 seconds.
	finished := time.now()
	println('Command finished at ${finished} after ${finished - started}')

	// Since command has been terminated, the state would be: `signal: 15 (SIGTERM)`
	println('Child state: ${cmd.state}')
}
