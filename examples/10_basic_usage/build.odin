package build

import nob "../../nob"
import "core:os"

main :: proc() {
	nob.go_rebuild_urself(os.args, #file)

	command := nob.command_init()

	main_name := "src/main.odin"
	output_name := "main"

	nob.command_append(&command, "odin", "build", main_name, "-file", nob.output(output_name))
	ok := nob.command_run_with_options(&command, nob.default_opts())
	if !ok {
		os.exit(1)
	}

	nob.command_append(&command, output_name)
	ok = nob.command_run_with_options(&command, nob.default_opts())
	if !ok {
		os.exit(1)
	}

	os.exit(0)
}
