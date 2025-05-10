class SimpleRNG {
	uint state;
	SimpleRNG() {
		state = Time::Now ^ Time::Stamp;
	}

	SimpleRNG(uint seed) {
		state = seed;
	}

	SimpleRNG& SeedAnd(uint seed) {
		state = seed;
		return this;
	}

	// <https://en.wikipedia.org/wiki/Linear_congruential_generator>
	uint NextUInt() {
		state = state * 1664525 + 1013904223;
		return state;
	}

	// Float in [0,1)
	float NextFloat() {
		// use top 24 bits for a 0..1 float
		uint v = NextUInt() & 0x00FFFFFF;
		return float(v) / float(0x01000000);
	}

	// Integer in [min, max]
	int NextInt(int min, int max) {
		return min + int( NextFloat() * float(max - min + 1) );
	}
}
