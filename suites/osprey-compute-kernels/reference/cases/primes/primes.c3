// Count primes below a limit by trial division — integer % in a tight loop.
// Faithful C3 port of primes.c (has_factor/is_prime, limit 200000).
module primes_c3;
import std::io;

fn int has_factor(long n, long d)
{
	if (d * d > n)
	{
		return 0;
	}
	else if (n % d == 0)
	{
		return 1;
	}
	else
	{
		return has_factor(n, d + 1);
	}
}

fn int is_prime(long n)
{
	if (n < 2L) { return 0; }
	return (int)!has_factor(n, 2);
}

fn int main()
{
	long acc = 0;
	for (long n = 2; n < 200000L; n += 1)
	{
		if (is_prime(n)) { acc += 1; }
	}
	io::printfn("%d", acc);
	return 0;
}
