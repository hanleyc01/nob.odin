# nob.odin

WIP implementation of [nob](https://github.com/tsoding/nob.h) in Odin.

# Usage

Download or copy `nob.odin` into your project, and create a build
script. I named mine `build.odin`

```{odin}
// build.odin
package build

import "core:os"
import nob "./nob"

main :: proc() {
    nob.go_rebuild_urself(os.args, #file)

    command := nob.command_init()

    main_name := "main.odin"
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
```

This compiles and runs `main.odin`:
```{odin}
// main.odin
package main

import "core:fmt"

main :: proc() {
    fmt.println("Hello, worrld!")
}
```