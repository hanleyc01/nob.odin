package nob

import "core:os"
import "core:c/libc"
import "core:strings"
import "core:sys/posix"
import "core:fmt"

// Helper to make odin compiler flags easier, returns `-out:<out>`
output :: proc(out: string) -> string {
    return strings.concatenate({"-out:", out})
}

log :: proc(msgs: ..any) {
    fmt.print("[nob] ")
    fmt.println(..msgs)
}

log_error :: proc(msgs: ..any) {
    fmt.eprint("[nob ERROR] ")
    fmt.eprintln(..msgs)
}

// Options passed to the command runner.
Command_Options :: struct {
    do_async: bool,
    max_procs: uint,
    should_reset: bool,
    stdin_path: string,
    stdout_path: string,
    stderr_path: string,
}

// Initialize a new `Command_Options`
command_options_init :: proc(
    do_async := false,
    max_procs: uint = 0, 
    should_reset := true, 
    stdin_path := "",
    stdout_path := "",
    stderr_path := "",
) -> Command_Options {
    return Command_Options {
        do_async,
        max_procs,
        should_reset,
        stdin_path,
        stdout_path,
        stderr_path,
    }
}

default_opts :: proc() -> Command_Options {
    return command_options_init()
}

// Commands are a thin wrapper amound dynamic arrays of strings. Aliased in order
// to hide the functionality going on underneath.
Command :: struct {
    commands: [dynamic]string
}

// Initialize a new command with provided length and capacity for underlying
// command array.
command_init :: proc(init_length := 0, init_capacity := 16) -> Command {
    commands := make([dynamic]string, init_length, init_capacity)
    return Command { commands }
}

command_reinit :: proc(command: ^Command) {
    clear(&command.commands)
}

// Append a strings to the command.
command_append :: proc(command: ^Command, to_appends: ..string) {
    for to_append in to_appends {
        append(&command.commands, to_append)
    }
}

command_rebuild_urself :: proc(binary_path: string, source_path: string) -> [dynamic]string {
    // TODO: implement
    command: [dynamic]string
    append(&command, "odin")
    append(&command, "build")
    append(&command, source_path)
    append(&command, "-file")
    append(&command, strings.concatenate({"-out:", binary_path}))
    return command
}

command_write_to_string :: proc(command: Command, b: ^strings.Builder) {
    for cmd in command.commands {
        strings.write_string(b, cmd)
        strings.write_string(b, " ")
    }
}

command_start_process :: proc(command: Command) {
    sb := strings.builder_make()
    command_write_to_string(command, &sb)
    s := strings.to_string(sb)
    log("CMD: ", s)
    defer strings.builder_destroy(&sb)

    state, stdout, stderr, err := os.process_exec({command = command.commands[:]}, context.allocator)
    if err != nil {
        log_error("failed to run:", err)
        os.exit(state.exit_code)
    }
    defer delete(stdout)
    defer delete(stderr)

    log("exit code:", state.exit_code)
    strerr := string(stderr)
    if strerr != "" {
        fmt.eprint(strerr)
    }

    strout := string(stdout)
    if strout != "" {
        fmt.print(strout)
    }
}

// Run the current command, reinitializing the internal array.
command_run_with_options :: proc(command: ^Command, options: Command_Options) -> (ok: bool) {
    ok = true
    defer if options.should_reset {
        command_reinit(command)
    }

    // TODO: add async and specialized stdout and stderr
    command_start_process(command^)

    return ok
}

// Rename a file to a new name.
rename :: proc(from: string, to: string) -> (ok: bool) {
    log("renaming ", from, " -> ", to)
    result := libc.rename(strings.clone_to_cstring(from), strings.clone_to_cstring(to))
    if result < 0 {
        errno := posix.errno()
        log_error("could not rename ", from, " to ", to, " ", posix.strerror(errno))
        return false
    } else {
        return true
    }
}

// Result type for `needs_rebuild`. Indicates whether or not some file (determined
// by a string path) needs to be rebuilt based on `posix.stat`. 
Needs_Rebuild :: enum {
    Could_Not_Stat,
    Doesnt_Need_Rebuild,
}

// Determine whether or not the `nob.odin` file needs to be rebuilt, returning
// a `Needs_Rebuild`.
needs_rebuild :: proc(output_path: string, input_paths: [dynamic]string) -> (err: Maybe(Needs_Rebuild)) {
    buf: posix.stat_t

    stat: posix.result = posix.stat(strings.clone_to_cstring(output_path), &buf)
    if stat == .FAIL {
        errno := posix.errno()
        if errno == .ENOENT {
            return nil
        } else {
            log("could not stat ", output_path, " : ", posix.strerror(errno))
            return .Could_Not_Stat
        }
    }

    output_path_time: posix.timespec = buf.st_mtim

    for input_path in input_paths {
        stat = posix.stat(strings.clone_to_cstring(input_path), &buf)
        errno := posix.errno()
        if stat == .FAIL {
            log("could not stat ", input_path, " : ", posix.strerror(errno))
            return .Could_Not_Stat
        } else {
            input_path_time := buf.st_mtim

            if input_path_time.tv_sec > output_path_time.tv_sec {
                return nil
            }
        }
    }

    return .Doesnt_Need_Rebuild
}


// Detects whether or not to rebuild the `nob` project given modifications
// the `nob` file.
go_rebuild_urself :: proc(args: []string, source_path: string, var_args: ..string) {
    if args == nil || len(args) < 1 {
        os.exit(-1)
    }

    binary_path := args[0]
    args := args[1:]

    source_paths: [dynamic]string
    append(&source_paths, source_path)
    for arg in var_args {
        append(&source_paths, arg)
    }

    rebuild_is_needed := needs_rebuild(binary_path, source_paths)
    if rebuild_is_needed == .Could_Not_Stat {
        os.exit(-1)
    } else if rebuild_is_needed == .Doesnt_Need_Rebuild {
        return
    } // otherwise, rebuild is needed

    command := command_init()

    old_binary_path_builder, err := strings.builder_make()
    if err != nil {
        log("string builder allocator error")
        os.exit(-1)
    }
    strings.write_string(&old_binary_path_builder, binary_path)
    strings.write_string(&old_binary_path_builder, ".old")
    old_binary_path := strings.to_string(old_binary_path_builder)

    ok := rename(binary_path, old_binary_path)
    if !ok {
        log("error rewriting ", binary_path, "to ", old_binary_path)
        os.exit(1)
    }

    command_append(&command, ..command_rebuild_urself(binary_path, source_path)[:])
    command_options := command_options_init()
    ok = command_run_with_options(&command, command_options)
    if !ok {
        rename(old_binary_path, binary_path)
        os.exit(1)
    }

    command_append(&command, binary_path)
    command_append(&command, ..args)
    ok = command_run_with_options(&command, command_options)
    if !ok {
        os.exit(1)
    }

    os.exit(0)
}