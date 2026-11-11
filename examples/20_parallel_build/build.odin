package build

import nob "../../nob"
import "core:os"

main :: proc() {
	nob.go_rebuild_urself(os.args, #file)

	// Odin supports building a package from a file
	src_path := "src"
	out_path := "main"

	command := nob.command_init()
	nob.command_append(
		&command,
		"odin",
		"build",
		src_path,
		nob.output(out_path),
		// Thread count determines how many threads to spawn
		nob.thread_count(10),
	)
	ok := nob.command_run_with_options(&command, nob.default_opts())
	if !ok {
		os.exit(1)
	}

	nob.command_append(&command, "./main")
	ok = nob.command_run_with_options(&command, nob.default_opts())
	if !ok {
		os.exit(1)
	}
	os.exit(0)
}
