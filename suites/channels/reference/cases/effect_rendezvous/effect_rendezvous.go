// effect_rendezvous — the rendezvous peer. An UNBUFFERED Go channel is
// the shape the post names: sender and receiver meet, the value crosses,
// both continue — and the meeting costs a park/wake pair per element.
// 1,000,000 handshakes, one receiver accumulating, same checksum oracle.
package main

import "fmt"

func main() {
	const total = 1000000
	ch := make(chan int64) // unbuffered: every send is a rendezvous
	done := make(chan int64)

	go func() {
		var sum int64
		for v := range ch {
			sum += v
		}
		done <- sum
	}()

	for i := int64(0); i < total; i++ {
		ch <- i
	}
	close(ch)
	fmt.Println(<-done)
}
