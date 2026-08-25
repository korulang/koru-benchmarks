// Naive recursive Fibonacci — exercises raw function-call + recursion overhead.
// Faithful Odin port of fib.c (same add/sub helpers, same switch recursion,
// same n=35), checked against expected.txt.
package main

import "core:fmt"

add :: proc(a: i64, b: i64) -> i64 {
	return a + b
}

sub :: proc(a: i64, b: i64) -> i64 {
	return a - b
}

fib :: proc(n: i64) -> i64 {
	switch n {
	case 0: return 0
	case 1: return 1
	case:    return add(fib(sub(n, 1)), fib(sub(n, 2)))
	}
	return 0
}

main :: proc() {
	fmt.printfln("%d", fib(35))
}
