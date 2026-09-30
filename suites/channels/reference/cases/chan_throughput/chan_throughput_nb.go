// chan_throughput_nb — the same Go channel, but driven like the pump:
// try-send via select/default (the | full branch), try-recv the same way,
// one goroutine, same pass schedule as the Koru kernel (feed up to 128,
// then four one-dequeue consumers). This row isolates Go's channel DATA
// STRUCTURE from its SCHEDULER — the nearest Go gets to std/channel's
// non-blocking contract.
package main

import (
	"fmt"
)

func main() {
	const total = 1000000
	const batch = 128
	const consumers = 4
	ch := make(chan int64, 1024)

	var sent, got, sum int64
	for got < total {
		// producer step: bounded batch, ends early on full
		fed := int64(0)
		for fed < batch && sent < total {
			select {
			case ch <- sent:
				sent++
				fed++
			default:
				fed = batch // full — stop the batch
			}
		}
		// consumer steps: four competing units, one dequeue each
		for c := 0; c < consumers; c++ {
			select {
			case v := <-ch:
				sum += v
				got++
			default:
			}
		}
	}
	fmt.Println(sum)
}
