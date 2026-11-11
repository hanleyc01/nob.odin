package main

import "core:fmt"

do_something :: proc(n: int) -> int {
	for i in 0 ..= n {
		x := n + 1000
		identity(x)
	}
	return n
}
