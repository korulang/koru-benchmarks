// chan_throughput — same topology as the Koru kernel: 1,000,000 int64s
// through a capacity-1024 buffered channel, four competing consumer
// goroutines, checksum oracle sum(0..1000000). The difference being
// measured is the substrate: Go runs 5 goroutines across OS threads and
// parks them on channel ops; Koru runs 5 participants on one thread and
// parks nothing.
package main

import (
	"fmt"
	"sync"
)

func main() {
	const total = 1000000
	const consumers = 4
	ch := make(chan int64, 1024)
	partials := make(chan int64, consumers)

	var wg sync.WaitGroup
	for c := 0; c < consumers; c++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			var sum int64
			for v := range ch {
				sum += v
			}
			partials <- sum
		}()
	}

	go func() {
		for i := int64(0); i < total; i++ {
			ch <- i
		}
		close(ch)
	}()

	wg.Wait()
	var sum int64
	for c := 0; c < consumers; c++ {
		sum += <-partials
	}
	fmt.Println(sum)
}
