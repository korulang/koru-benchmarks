#include <cstdint>
#include <cstdio>
#include <chrono>
struct EvensIt {
    size_t i = 0, n;
    size_t operator*() const { return i; }
    EvensIt& operator++() { do { ++i; } while (i <= n && i % 2); return *this; }
    bool operator!=(const EvensIt& o) const { return i != o.i; }
};
int main(int argc, char**) {
    size_t n = 10000000 + (size_t)argc;
    double best = 1e30; int64_t c = 0;
    for (int r = 0; r < 7; r++) {
        auto t = std::chrono::steady_clock::now();
        c = 0;
        for (EvensIt it{0, n}, end{n + 1, n + 1}; it != end; ++it) c += (int64_t)*it * 3;
        best = std::min(best, std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-t).count());
    }
    std::printf("RESULT %lld %.6f\n", (long long)c, best);
}
