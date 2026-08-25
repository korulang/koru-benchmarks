// Triple-nested counting loop accumulating (i*j*k) mod P — nested iteration.
// Faithful Odin port of nestedloop.c (same while-loop structure, P = 1000000007).
package main

import "core:fmt"

P :: i64(1000000007)

loop_k :: proc(i, j, k0, acc0: i64) -> i64 {
	k, acc := k0, acc0
	for k != 0 {
		acc = (acc + i * j * k) % P
		k -= 1
	}
	return acc
}

loop_j :: proc(i, j0, n, acc0: i64) -> i64 {
	j, acc := j0, acc0
	for j != 0 {
		acc = loop_k(i, j, n, acc)
		j -= 1
	}
	return acc
}

loop_i :: proc(i0, n, acc0: i64) -> i64 {
	i, acc := i0, acc0
	for i != 0 {
		acc = loop_j(i, n, n, acc)
		i -= 1
	}
	return acc
}

main :: proc() {
	fmt.printfln("%d", loop_i(250, 250, 0))
}
