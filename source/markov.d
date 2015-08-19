
module markov;

import std.algorithm;
import std.array;
import std.conv;
import std.exception;
import std.random;
import std.string;

import counters;
import strings;
import util;

struct Element
{
	String token;

	double frequency;

	string toString()
	{
		return "(%s, %s)".format(token, frequency);
	}
}

struct MarkovState(int Count)
{
	alias Strings = String[Count];

	private CounterTable!Count counters;

	@property
	size_t length()
	{
		return counters.length;
	}

	void clear()
	{
		counters.clear;
	}

	String random()
	{
		// Nothing to fetch.
		if(counters.empty) return null;

		size_t index = uniform(0L, counters.length);
		auto counter = counters[index];
		if(counter.empty) return null;

		index = uniform(0L, counter.length);
		return counter[index];
	}

	String select(String[] array)
	{
		Strings sequence = array;
		return select(sequence);
	}

	String select(Strings sequence)
	{
		auto counter = counters[sequence];
		size_t value = uniform(0, counter);

		foreach(frequency; counter)
		{
			if(value < frequency)
			{
				return frequency.token;
			}
			else
			{
				value -= frequency;
			}
		}

		return null;
	}

	void train(String[] tokens)
	{
		// Input text too short, skip.
		if(tokens.length < Count) return;

		// Iterate over sequences of tokens.
		foreach(index, token; tokens[0 .. $ - Count])
		{
			Strings sequence = tokens[index .. index + Count];
			counters[sequence][tokens[index + Count]]++;
		}
	}
}

class Markov
{
private:
	double _mutation;
	double _crossover;

	String[] _seed;

	MarkovState!1 unaryTable;
	MarkovState!2 binaryTable;
	MarkovState!3 ternaryTable;

public:
	@property
	double mutation()
	{
		return _mutation;
	}

	@property
	void mutation(double mutation)
	{
		_mutation = mutation;
	}

	@property
	double crossover()
	{
		return _crossover;
	}

	@property
	void crossover(double crossover)
	{
		_crossover = crossover;
	}

	@property
	string[] seed()
	{
		return _seed
			.map!(str => str.toString)
			.array;
	}

	@property
	void seed(string[] tokens)
	{
		_seed = tokens
			.filter!(token => token.length > 0)
			.map!(token => String.findOrCreate(token))
			.array;
	}

	@property
	size_t unaryLength()
	{
		return unaryTable.length;
	}

	@property
	size_t binaryLength()
	{
		return binaryTable.length;
	}

	@property
	size_t ternaryLength()
	{
		return ternaryTable.length;
	}

	void clear()
	{
		// Clear string table.
		StringTable.get.clear;

		// Clear frequency tables.
		unaryTable.clear;
		binaryTable.clear;
		ternaryTable.clear;
	}

	void train(Range)(Range tokens)
	{
		// Map to string references.
		String[] strings = tokens
			.filter!(token => token.length > 0)
			.map!(token => String.findOrCreate(token))
			.array;

		// Rehash string table.
		StringTable.get.optimize;

		// Train frequency tables.
		unaryTable.train(strings);
		binaryTable.train(strings);
		ternaryTable.train(strings);
	}

	auto generate(int length)
	{
		String[] output;

		// Starting tokens.
		if(_seed.length > 0)
		{
			output ~= _seed;
		}

		while(output.length < length)
		{
			String token;

			if(output.length >= 3)
			{
				auto temp = ternaryTable.select(output[$ - 3 .. $]);
				if(temp !is null) token = temp;
			}

			// Roll for two-token sequence crossover change.
			if(output.length >= 2 && (token is null || uniform(0.0, 1.0) < _crossover))
			{
				auto temp = binaryTable.select(output[$ - 2 .. $]);
				if(temp !is null) token = temp;
			}

			// Roll for single-token sequence crossover chance.
			if(output.length >= 1 && (token is null || uniform(0.0, 1.0) < _crossover / 2))
			{
				auto temp = unaryTable.select(output[$ - 1 .. $]);
				if(temp !is null) token = temp;
			}

			// Roll for random token mutation chance.
			if(token is null || uniform(0.0, 1.0) < _mutation)
			{
				auto temp = unaryTable.random;
				if(temp !is null) token = temp;
			}

			// Append resulting token to the output list.
			enforce(token !is null, "No possible tokens.");
			output ~= token;
		}

		return output
			.map!(str => str.toString)
			.filter!(str => str.length > 0);
	}
}
