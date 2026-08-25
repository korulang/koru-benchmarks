// Word-frequency count over a tiny vocab — exercises hashing + counting.
// Faithful Odin port of wordfreq.c: MINSTD hash stream, builtin map[string]int
// aggregation, position-weighted checksum. The urandom reseed branch is out of
// scope for a portable port — nonzero seeds are taken literally (the oracle
// path feeds "0" -> seed 1, unchanged).
package main

import "core:fmt"
import "core:io"
import "core:os"
import "core:strconv"

MINSTD :: i64(16807)
MODULUS :: i64(2147483647)

r1 :: proc(x: i64) -> i64 {
	return (x * MINSTD) % MODULUS
}

hash_at :: proc(s, i: i64) -> i64 {
	return r1(r1(s + i))
}

main :: proc() {
	vocab := [8]string{"the", "quick", "brown", "fox", "jumps", "over", "lazy", "dog"}

	seed := i64(1)
	line: [32]byte
	n := 0
	for n < len(line) {
		c, err := io.read_byte(os.to_stream(os.stdin))
		if err != nil || c == '\n' do break
		line[n] = c
		n += 1
	}
	if v, ok := strconv.parse_i64_of_base(string(line[:n]), 10); ok && v != 0 {
		seed = v
	}

	counts := make(map[string]int)
	defer delete(counts)

	for i := i64(0); i < 200000; i += 1 {
		word := vocab[hash_at(seed, i) % 8]
		counts[word] += 1
	}

	result := i64(0)
	for k := 0; k < 8; k += 1 {
		result += (i64(k) + 1) * i64(counts[vocab[k]])
	}
	fmt.printfln("%d", result)
}
