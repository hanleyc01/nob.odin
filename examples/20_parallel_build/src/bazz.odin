package main

identity :: proc(x: $T) -> T {
	return x
}

do_something_also :: proc(n: int) -> int {
	for i in 0 ..= n {
		x := n + 10000
		identity(x)
	}
	return n
}
