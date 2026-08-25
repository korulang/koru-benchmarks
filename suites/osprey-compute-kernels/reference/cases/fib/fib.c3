// Naive recursive Fibonacci — exercises raw function-call + recursion overhead.
// Faithful C3 port of fib.c (same add/sub helpers, same switch recursion,
// same n=35), checked against expected.txt.
module fib_c3;
import std::io;

fn long add(long a, long b) { return a + b; }
fn long sub(long a, long b) { return a - b; }

fn long fib(long n)
{
	switch (n)
	{
		case 0: return 0;
		case 1: return 1;
		default: return add(fib(sub(n, 1)), fib(sub(n, 2)));
	}
}

fn int main()
{
	io::printfn("%d", fib(35));
	return 0;
}
