package main

import nob "../../nob"
import "core:fmt"
import "core:os"

PROGRAM_NAME :: "30_cli"

do_something :: proc() {
	fmt.println("foo")
}

do_something_else :: proc() {
	fmt.println("bar")
}

main :: proc() {
	nob.go_rebuild_urself(os.args, #file)

	ap := nob.argument_parser(PROGRAM_NAME)
	defer nob.argument_parser_destroy(&ap)

	nob.parser_add_argument(
		&ap,
		"do_something",
		help_message = "this is a test",
		proc_ = do_something,
	)
	nob.parser_add_argument(
		&ap,
		"do_something_else",
		help_message = "do the other thing",
		proc_ = do_something_else,
	)

	ok := nob.parse_args(&ap, os.args)
	if !ok do return
}
