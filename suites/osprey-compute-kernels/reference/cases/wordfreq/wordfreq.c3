// Word-frequency count over a tiny vocab — exercises hashing + counting.
// Faithful C3 port of wordfreq.c: MINSTD hash stream, HashMap<&str,int>
// aggregation (the Rust reference's shape), position-weighted checksum.
// The urandom reseed branch is out of scope for a portable port — nonzero
// seeds are taken literally (oracle path feeds "0" -> seed 1, unchanged).
module wordfreq_c3;
import std::io;
import std::collections::map;

const usz MINSTD = 16807;
const usz MODULUS = 2147483647;
const usz N_TOKENS = 200000;

fn ulong r1(ulong x) { return (x * MINSTD) % MODULUS; }
fn ulong hash_at(ulong s, ulong i) { return r1(r1(s + i)); }

fn int main()
{
	String[8] vocab = { "the", "quick", "brown", "fox", "jumps", "over", "lazy", "dog" };

	// seed: first stdin line, 0 or unparseable -> 1
	ulong seed = 1;
	if (try String line = io::treadline())
	{
		ulong v = 0;
		bool ok = true;
		for (usz i = 0; i < line.len && ok; i += 1)
		{
			char c = line[i];
			if (c >= '0' && c <= '9') { v = v * 10 + (ulong)(c - '0'); }
			else if (i == 0) { ok = false; }
			else { break; }
		}
		if (ok && v != 0) { seed = v; }
	}

	HashMap{String, ulong} map;

	for (usz i = 0; i < N_TOKENS; i += 1)
	{
		String word = vocab[(hash_at(seed, i) % 8)];
		map[word] = (map[word] ?? 0) + 1;
	}

	ulong result = 0;
	for (usz k = 0; k < 8; k += 1)
	{
		result += (ulong)(k + 1) * (map[vocab[k]] ?? 0);
	}

	io::printfn("%d", result);
	return 0;
}
