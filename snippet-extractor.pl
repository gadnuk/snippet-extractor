#!/usr/bin/perl

###############################################################################

# Details
# Author: 		Eric Moras
# Assignment: 	Snippet Extractor (Yelp Code Test)
# System: 		Mac OS X v10.8.2 (Mountain Lion)
# Language: 	Perl v5.12.4
# IDE: 			CodeRunner 1.3 (6)

###############################################################################

use Test::More tests => 8;
use warnings;
use strict;

## Global variables. Can be changed as per need.

my $doc = "I like fish. Little star’s deep dish pizza sure is fantastic. Dogs are funny.";
my $query = "deep dish pizza";
my $snippet_size = 40;

my %hash = ();

###############################################################################

# Input: doc (string), query (string)
# Output: Extracted snippet (string)

my $snippet = highlight_doc($doc, $query);

print "\nSample doc/query (as given in the test sheet):\nDocument: $doc\nQuery: $query\nSnippet: $snippet\n\nTests:\n";

###############################################################################

# Subroutine to extract the proper snippet and highlight query terms

sub highlight_doc {
	
	my $doc_copy = $_[0];
	my $query_copy = $_[1];
	
	# Fetch the best snippet window from the document
	my @snippet_window = get_best_snippet_window($doc_copy, $query_copy, $snippet_size);
	
	my @document_terms = split(" ", $doc_copy);
	my @snippet_terms = ();
	
	# Load the terms in the snippet within the optimal window
	for (my $i = $snippet_window[0][0]; $i < $snippet_window[0][1]; $i++) {
		push(@snippet_terms, $document_terms[$i]);
	}
	
	my $snippet_string = join(" ", @snippet_terms);
	
	# Highlight the query terms in the snippet
	my $snippet = highlight_terms($snippet_string, $query_copy);
	
	#print "\n$snippet\n";
	
	return $snippet;
}

###############################################################################

# Subroutine to sort hash by values

sub hashValueDescendingNum {
   $hash{$b} <=> $hash{$a};
}

###############################################################################

# Subroutine to get the best snippet window
# Input: doc, query, window_size
# Output: snippet_lower_index, snippet_upper_index

sub get_best_snippet_window {
	my $doc_copy = $_[0];
	my $query_copy = $_[1];
	my $size = $_[2];
	
	my $original_doc = $doc_copy;
	
	# Clean the document and the query by removing punctuations and converting
	# all tokens to lowercase
	$doc_copy =~ s/[[:punct:]]//g;
	$doc_copy = lc $doc_copy;
	$query_copy =~ s/[[:punct:]]//g;
	$query_copy = lc $query_copy;
	
	# Split the document and query into token, delimited by space
	my @query_terms = split(" ", $query_copy);
	my @doc_terms = split(" ", $doc_copy);
	
	# Initialize all the necessary variables
	my $query_match_count = 0;
	my $max_count = 0;
	my $window_start_pos = 0;
	my $window_end_pos = $window_start_pos + $size - 1;
	my $window_low_index = 0;
	my $window_high_index = $window_start_pos + $size - 1;
	my @snippet_window = ();
	my %frequency = ();
	
	# If the length of the document is less than the window size,
	# simply return the most relevant sentence in the document.
	# Initially, the design was such that the entire document was
	# returned. However, this proves to fail for the sample input.
	if (scalar(@doc_terms) < $size) {
		# Divide the document into sentences using this nasty regex
		# from the internet
		my @doc_sentences = 
		split(/(?:(?<=\.|\!|\?)(?<!Mr\.|Dr\.)(?<!U\.S\.A\.)\s+(?=[A-Z]))/, 
												$original_doc);
		my @sentence_starts = ();
		my $count = 0;
		push(@sentence_starts, $count);
		for (my $i = 0; $i < scalar(@doc_sentences); $i++)
		{
			# Split sentences into tokens and keep track of the starting
			# index of each sentence
			my @doc_sentence_terms = split(" ", $doc_sentences[$i]);
			push(@sentence_starts, $count+scalar(@doc_sentence_terms));
			$count += scalar(@doc_sentence_terms);
			
			# Populate a hash which records the frequency of query terms
			# in a sentence in the document
			for(my $j = 0; $j < scalar(@doc_sentence_terms); $j++) {
				for (my $k = 0; $k < scalar(@query_terms); $k++) {
					if ($doc_sentence_terms[$j] eq $query_terms[$k]) {
						$frequency{$i}++;
					}
				}
			}
		}
		my $s = 0;
		my $e = 0;
		
		# Pick the sentence with the highest frequency of query words
		# and return it's bounds as the snippet window
		foreach my $key (sort hashValueDescendingNum (keys(%frequency))) {
		   $s = $sentence_starts[$key];
		   $e = $sentence_starts[$key+1];
		}
		
		if ($s == 0 and $e == 0) {
			@snippet_window = [0, scalar(@doc_terms)];
			return @snippet_window;
		}
		
		@snippet_window = [$s, $e];
		return @snippet_window;
	}
	
	# Calculate the number of matching query terms for the initial window
	for (my $i = $window_low_index; $i < $window_high_index; $i++) {
		if ($doc_terms[$i] ~~ @query_terms) {
			$query_match_count += 1;
			$max_count += 1;
		}
	}
	
	$window_low_index++;
	$window_high_index++;
	
	# Keep sliding the upper bound of the window until document
	# length has been reached
	while ($window_high_index < scalar(@doc_terms)) {
		# If a matching query word was removed from the window, 
		# decrement the query match count
		if ($doc_terms[$window_low_index - 1] ~~ @query_terms) {
			$query_match_count -= 1;
		}
		
		# If a matching query word was added to the window, 
		# increment the query match count
		if ($doc_terms[$window_high_index] ~~ @query_terms) {
			$query_match_count += 1;
		}		
		
		# Set the lower and upper bounds to the snippet window
		# Termination argument
		if ($query_match_count > $max_count) {
			$max_count = $query_match_count;
			$window_start_pos = $window_low_index;
			$window_end_pos = $window_high_index;
		}
		
		$window_low_index += 1;
		$window_high_index += 1;
	}
	
	# Set the bounds of the snippet window and return it
	@snippet_window = ($window_start_pos, $window_end_pos + 1);
	
	return \@snippet_window;
}

###############################################################################

# Subroutine to highligh the query terms in a snippet
# Input: snippet, query
# Output: highlighted_snippet

sub highlight_terms {
	my $snippet = $_[0];
	my $query_copy = $_[1];
	
	my $snippet_copy = $snippet;
	my $highlighted_snippet = ();
	my @highlight_range = ();
	my $i = 0;
	
	# Clean the snippet and the query by removing punctuations and converting
	# all tokens to lowercase
	$query_copy =~ s/[[:punct:]]//g;
	$query_copy = lc $query_copy;
	$snippet =~ s/[[:punct:]]//g;
	$snippet = lc $snippet;
	
	# Initilaize the highlight start and end markers
	my $highlight_start = "[[HIGHLIGHT]]";
	my $highlight_end = "[[ENDHIGHLIGHT]]";	
	
	my $window_start = -1;
	my @query_terms = split(" ", $query_copy);
	my @snippet_terms = split(" ", $snippet);
	my @snippet_terms_copy = split(" ", $snippet_copy);
	
	# Find spans of tokens in the snippet which match the query terms
	for ($i = 0; $i < scalar(@snippet_terms); $i++) {
		# If a new matching query term has been encountered in the snippet
		if ($snippet_terms[$i] ~~ @query_terms) {
			# If a span is yet to be started, 
			# start it with the index of the token
			if ($window_start eq -1) {
				$window_start = $i;
			}
		}
		else {			
			if ($window_start ne -1) {
				# Set the bounds of the span and reset the flag
				my @range = ($window_start, $i - 1);
				push(@highlight_range, \@range);
				$window_start = -1;
			}
		}
	}
	
	# If a span hasn't completed and end of document has been reached, 
	# end the span and add the bounds of the span
	if ($window_start ne -1) {
		my @range = [$window_start, $i - 1];
		push(@highlight_range, @range);
	}
	
	# For the given ranges in the snippet, highlight all the terms
	for (my $j = 0; $j < scalar(@highlight_range); $j++) {
		$snippet_terms_copy[$highlight_range[$j][0]] = 
			"$highlight_start$snippet_terms_copy[$highlight_range[$j][0]]";
		$snippet_terms_copy[$highlight_range[$j][1]] = 
			"$snippet_terms_copy[$highlight_range[$j][1]]$highlight_end";
	}
	
	# Reconstruct the final highlighted snippet and return it
	$highlighted_snippet = join(" ", @snippet_terms_copy);
	return $highlighted_snippet;
}

###############################################################################

# TESTS

# Note: Description of tests present as comment in the tests itself.
# Warning: Excuse the formatting. Large strings were involved here. 
#		   Didn't want to use I/O for reading documents for testing.

my $doc1 = "I like fish. Dogs are funny.";
my $query1 = "deep dish pizza";

is( highlight_doc($doc1, $query1), 'I like fish. Dogs are funny.', "Small document containing irrelevant terms" );

my $doc2 = "I like fish. Little star’s deep dish pizza sure is fantastic. Dogs are funny.";
my $query2 = "deep dish pizza";

is( highlight_doc($doc2, $query2), 'Little star’s [[HIGHLIGHT]]deep dish pizza[[ENDHIGHLIGHT]] sure is fantastic.', "Small document containing one relevant sentence" );

my $doc3 = "As a loyal fan of Patxi's on Irving Street, it saddens me to give this honest, one-star review. My roommates and I have been regulars who always loved the regular (initially called \"thin\" when they first opened), whole wheat crust.  We probably got pizza there almost once per week. Unfortunately, Patxi's no longer offers it, and the remaining two options are unsatisfying.  The deep dish is fine if you want deep dish, but the new thin crust tastes like I am eating the cardboard pizza box. Please, please, please bring back the regular, whole wheat crust, and you'll surely bring back the sad customers you have lost, including us. Thanks (fingers crossed)";
my $query3 = "deep dish pizza";

is( highlight_doc($doc3, $query3), '"thin" when they first opened), whole wheat crust. We probably got [[HIGHLIGHT]]pizza[[ENDHIGHLIGHT]] there almost once per week. Unfortunately, Patxi\'s no longer offers it, and the remaining two options are unsatisfying. The [[HIGHLIGHT]]deep dish[[ENDHIGHLIGHT]] is fine if you want [[HIGHLIGHT]]deep dish,[[ENDHIGHLIGHT]]', "Larger document taken from Yelp with snippet window in between" );

my $doc4 = "Pizza is delicious.  They do a great deep dish pizza with customized toppings.  The prosciutto and arugula thin crust style is also a great choice.  One medium deep dish and a large thin crust pizza for 4 people approximately \$50.";
my $query4 = "deep dish pizza";

is( highlight_doc($doc4, $query4), '[[HIGHLIGHT]]Pizza[[ENDHIGHLIGHT]] is delicious. They do a great [[HIGHLIGHT]]deep dish pizza[[ENDHIGHLIGHT]] with customized toppings. The prosciutto and arugula thin crust style is also a great choice. One medium [[HIGHLIGHT]]deep dish[[ENDHIGHLIGHT]] and a large thin crust [[HIGHLIGHT]]pizza[[ENDHIGHLIGHT]] for 4 people approximately $50.', "Mid sized document taken from Yelp with uppercase relevant words at edges" );

my $doc5 = "";
my $query5 = "deep dish pizza";

is( highlight_doc($doc5, $query5), '', "Empty document with a valid query" );

my $doc6 = "I like fish. Little star’s deep dish pizza sure is fantastic. Dogs are funny.";
my $query6 = "";

is( highlight_doc($doc6, $query6), 'I like fish. Little star’s deep dish pizza sure is fantastic. Dogs are funny.', "Empty query with a valid document" );

my $doc7 = "Caveat: I've only dined in here once. I remember the service and ambiance and whatnot as being fine, but to be honest, I don't remember that particular experience very well. Instead, since I have a friend that lives just around the corner, we usually just get take-out.

So: what about the main event--the pizza? Now, I could wax philosophical about pizza for a *long* time; but unfortunately, Yelp imposes a character limit on these dang reviews. So I'll have to keep things pretty succinct.

Suffice it to say that the pizza is great. We usually get the deep dish classic when we come here, which I believe has sausage, mushroom, and peppers. There may be some other stuff in it. It doesn't matter too much. It's sloppy and full of cheese and sauce and is a pleasure to consume.

The crust is maybe the most remarkable part: crunch and crispy but not tough at all. I can't think of another pizza I've had with a crust quite like it. Tasty and distinctive.

Qualitatively, it's not entirely dissimilar to the deep dish I had in Chicago when I was growing up--although it's also not quite the same. But I don't really care whether or not it fits cleanly into one of my conceptual boxes. The only boxes my pizzas need to come in are flat cardboard ones that usually have some kind of map of Italy on the top.

I haven't had the thin crust here, so I can't say anything about it.";
my $query7 = "deep dish pizza";

is( highlight_doc($doc7, $query7), 'about [[HIGHLIGHT]]pizza[[ENDHIGHLIGHT]] for a *long* time; but unfortunately, Yelp imposes a character limit on these dang reviews. So I\'ll have to keep things pretty succinct. Suffice it to say that the [[HIGHLIGHT]]pizza[[ENDHIGHLIGHT]] is great. We usually get the [[HIGHLIGHT]]deep dish[[ENDHIGHLIGHT]]', "Large document with same query" );

my $doc8 = "Pizza is delicious.  They do a great deep dish pizza with customized toppings.  The prosciutto and arugula thin crust style is also a great choice.  One medium deep dish and a large thin crust pizza for 4 people approximately \$50.";
my $query8 = "%deep dish/ pizza!!";

is( highlight_doc($doc8, $query8), '[[HIGHLIGHT]]Pizza[[ENDHIGHLIGHT]] is delicious. They do a great [[HIGHLIGHT]]deep dish pizza[[ENDHIGHLIGHT]] with customized toppings. The prosciutto and arugula thin crust style is also a great choice. One medium [[HIGHLIGHT]]deep dish[[ENDHIGHLIGHT]] and a large thin crust [[HIGHLIGHT]]pizza[[ENDHIGHLIGHT]] for 4 people approximately $50.', "Mid sized document taken from Yelp with special characters in query" );



###############################################################################

# END

###############################################################################
