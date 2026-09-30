// chan_custody — the same 1M-message workload with a struct payload.
// Go channels have no ownership semantics: Msg copies through the channel
// and "custody" is a convention, not a checked contract. Koru's side of
// this kernel sends a Src<live!> — a linear obligation the compiler
// tracks across the channel edge — which is the row's reason to exist.
package main

import (
	"fmt"
	"sync"
)

type Msg struct {
	id int64
}

func main() {
	const total = 1000000
	const consumers = 4
	ch := make(chan Msg, 1024)

	var wg sync.WaitGroup
	sum := make([]int64, consumers)
	for c := 0; c < consumers; c++ {
		wg.Add(1)
		go func(c int) {
			defer wg.Done()
			for m := range ch {
				sum[c] += m.id
			}
		}(c)
	}
	for i := int64(0); i < total; i++ {
		ch <- Msg{id: i}
	}
	close(ch)
	wg.Wait()
	var t int64
	for _, s := range sum {
		t += s
	}
	fmt.Println(t)
}
