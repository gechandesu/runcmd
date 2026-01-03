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
	started := time.now()
	println('Start command at ${started}')
	cmd.start()!

	// Wait for command.
	cmd.wait()!

	// The `sleep 120` command would run for two minutes without a timeout.
	// But in this example, it will time out after 10 seconds.
	println('Command finished after ${time.now() - started}')

	// Since command has been terminated, the state would be: `signal: 15 (SIGTERM)`
	println('Child state: ${cmd.state}')
}
