// Triple-nested counting loop accumulating (i*j*k) mod P — nested iteration.
// Faithful C3 port of nestedloop.c (same while-loop structure, P = 1000000007).
module nestedloop_c3;
import std::io;

fn long loop_k(long i, long j, long k, long acc)
{
	while (k != 0)
	{
		long v = (acc + i * j * k) % 1000000007L;
		acc = v;
		k -= 1;
	}
	return acc;
}

fn long loop_j(long i, long j, long n, long acc)
{
	while (j != 0)
	{
		acc = loop_k(i, j, n, acc);
		j -= 1;
	}
	return acc;
}

fn long loop_i(long i, long n, long acc)
{
	while (i != 0)
	{
		acc = loop_j(i, n, n, acc);
		i -= 1;
	}
	return acc;
}

fn int main()
{
	io::printfn("%d", loop_i(250, 250, 0));
	return 0;
}
