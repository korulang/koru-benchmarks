// Count primes below a limit by trial division — integer % in a tight loop.
// Faithful Odin port of primes.c (has_factor/is_prime, limit 200000).
package main

import "core:fmt"

has_factor :: proc(n: i64, d: i64) -> b32 {
	if d * d > n {
		return false
	} else if n % d == 0 {
		return true
	} else {
		return has_factor(n, d + 1)
	}
}

is_prime :: proc(n: i64) -> b32 {
	if n < 2 {
		return false
	}
	return !has_factor(n, 2)
}

main :: proc() {
	acc := i64(0)
	for n: i64 = 2; n < 200000; n += 1 {
		if is_prime(n) do acc += 1
	}
	fmt.printfln("%d", acc)
}
