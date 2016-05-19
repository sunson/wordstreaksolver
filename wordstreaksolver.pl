#! /usr/bin/perl

=head1 NAME

wordstreaksolver.pl - solve a wordstreak or wordament board

=head1 SYNOPSIS

 Reads the board from the keyboard as lines (one row is one line). 
 Empty new line completes input.
 Computes all possible valid words and prints the board in ANSI colors. 

 --dict=<path/to/dict/file>   Pass path to a custom dictionary file (default: /usr/share/dict/words)
 --help                       This help message.

=head2 QUIPS

 - Does not yet handle the case for digrams (like 'ed' or 'ly' which
   Wordament uses)

 - Would be nice if the direction of movement can be shown

 - Would be awesome if the "show_solutions" routine can make use of
   horizontal space to pack more solutions into one screen.

=cut 


use Data::Dumper;
use Term::ANSIColor qw(:constants);

# CRACK A WORDAMENT/WORDSTREAK BOARD BY USING THE DICTIONARY

my $board = []; # 2D list of lists (sub list is a row of chars)
my $w, $h; # height and width of board (determined and set by inputboard function)

use constant DEFAULT_DICT => "/usr/share/dict/words";

use Getopt::Long;
use Pod::Usage;

my $dictfile, $help_flag;

my $opt_c = GetOptions(
    'dict=s' => \$dictfile,
    'help' => \$help_flag
    );

if ($help_flag) {
    pod2usage();
    
}

$dictfile = DEFAULT_DICT if (!$dictfile);

if (! -f $dictfile) {
    pod2usage(-message => "Invalid dictionary file '$dictfile'", -exitval => 1);
}

my $dict = {}; # this is where dictionary is loaded into

# sort by lengthiest words and then store them
sub loaddict {
    $|++;
    print "Loading Dictionary ($dictfile)...";
    my @words = ();
    open(F, "<" . $dictfile) or die "Unable to open dictionary: " . DICT;
    while ($line = <F>) {
        chomp $line;
	push(@words, $line);
    }
    close(F);
    my @sorted = sort { length($b) <=> length($a) } @words;
    foreach my $w (@words) {
	dictstore($w);
    }
    print "Done\n";
    return $dict;
}

# recursively form a nested hash that is easy to lookup while cracking
sub dictstore {
    my ($word, $mydict, $remword) = @_;
    if (!$remword) {
	dictstore($word, $dict, $word); # pass the global dictionary
    } else {
	my $char = substr($remword, 0, 1);
	my $subdict;
	if (!exists $mydict->{$char}) {
	    $subdict = {}; # create a new empty hash that will act as the sub dictionary for this dictionary
	    my $remword2 = substr($remword, 1);
	    if (length($remword2) == 0) {
		$subdict->{'.'} = $word;
		$mydict->{$char} = $subdict;
		return $mydict;
	    } else {
		$mydict->{$char} = dictstore($word, $subdict, $remword2);
		return $mydict;
	    }
	} else {
	    $subdict = $mydict->{$char};
	    my $remword2 = substr($remword, 1);
	    if (length($remword2) == 0) {
		$subdict->{'.'} = $word;
		return $mydict;
	    } else {
		$mydict->{$char} = dictstore($word, $subdict, $remword2);
		return $mydict;
	    }
	}
    }
}

sub inputboard {
    print "Enter rows: (If first row of board contains the letters 'A', 'B', 'C', 'D', and 'E', then just enter 'abcde')\n";
    # read from STDIN until an empty line is reached
    while (my $l = <STDIN>) {
        chomp $l;
        if ($l =~ m/^$/) {
            # end reached
            last;
        }
        my $len = length($l);
        if (!$w) {
            $w = $len;
        } else {
            if ($len != $w) {
                print "Invalid Line contains $len letters (first line sets width to $w). Please re-enter.\n";
                next;
            }
        }
        # split letters and store into $board
        push(@{$board}, [ split(//, $l) ]);
	showboard(30);
    }
    # calc height of board
    $h = scalar(@{$board});
    showboard(30);
}

sub showboard {
    my $indent = shift;
    my $paths = shift;
    # header
    my $hindent = $indent + 2;
    print " " x $hindent;
    print join(" ", 0..($w-1)) . "\n";
    my $rc = 0;
    my $first_flag = undef;
    foreach my $row (@{$board}) {
	print " " x $indent;
	print $rc . " ";
	my $ycounter = 0;
	map { 
	    $found = undef;
	    for (my $i = 0; $i < scalar(@{$paths}); $i++) { 
		$p = $paths->[$i];
		my ($px, $py) = @{$p};
		if ($ycounter == $py && $rc == $px) { 
		    if ($i == 0) {
			$first_flag = 1;
		    } else {
			$first_flag = 0;
		    }
		    $found = 1;
		} 
	    }
	    $ycounter++; 
	    if ($found) {
		if ($first_flag) {
		    print YELLOW uc($_) . " ";
		    $first_flag = undef;
		} else {
		    print GREEN uc($_) . " ";
		}
	    } else {
		print WHITE lc($_) . " ";
	    }
	} @{$row};
	print WHITE "\n";
	$rc++;
    }
}

# given x, y return a list of list of neighbour cell coords
sub neighbour_coords {
    my ($x, $y) = @_;

    if ($x > $w - 1 || $x < 0 || $y > $h - 1 || $y < 0) {
	return; # ie. error. Caller must check if this function has returned undef
    }

    my $tryxstart, $tryystart, $tryxend, $tryyend;

    if ($x == 0) { 
	$tryxstart = 0;
    } else {
	$tryxstart = $x - 1;
    }
    if ($y == 0) {
	$tryystart = 0;
    } else {
	$tryystart = $y - 1;
    }

    if ($x == $w - 1) {
	$tryxend = $w - 1;
    } else {
	$tryxend = $x + 1;
    }
    if ($y == $h - 1) {
	$tryyend = $h - 1;
    } else {
	$tryyend = $y + 1;
    }

    my $nc = [];
    for (my $tx = $tryxstart; $tx < $tryxend + 1; $tx++) {
	for (my $ty = $tryystart; $ty < $tryyend + 1; $ty++) {
	    if ($tx == $x && $ty == $y) {
		# skip THIS coord which is itself and not a neighbour!
	    } else {
		push(@{$nc}, [ $tx, $ty ]);
	    }
	}
    }

    return $nc;
    
}

# given a coord, return the char at that point
sub char_at {
    my ($x, $y) = @_;
    return $board->[$x]->[$y];
}

sub valid_word {
    my ($word, $mydict, $remword) = @_;
    if (!$mydict) {
	return valid_word($word, $dict, $word . ".");
    } else {
	my $firstchar = substr($remword, 0, 1);
	my $remword2 = substr($remword, 1);
	if (exists $mydict->{$firstchar}) {
	    if (length($remword2) == 0) {
		return 1;
	    } else {
		return valid_word($word, $mydict->{$firstchar}, $remword2);
	    }
	}
    }
}

sub valid_attempt {
    my ($word, $mydict, $remword) = @_;
    if (!$mydict) {
	return valid_attempt($word, $dict, $word);
    } else {
	my $firstchar = substr($remword, 0, 1);
	my $remword2 = substr($remword, 1);
	if (exists $mydict->{$firstchar}) {
	    if (length($remword2) == 0) {
		return 1;
	    } else {
		return valid_attempt($word, $mydict->{$firstchar}, $remword2);
	    }
	}
    }
}


# start from top most coord and recursively attempt to print all possible solutions
my $solutions = {};
sub solve {
    my ($path, $x, $y, $attempt) = @_;
    if (!$path) {
	for (my $tryx = 0; $tryx < $w; $tryx++) {
	    for (my $tryy = 0; $tryy < $h; $tryy++) {
		$path = [];
		my $c = char_at($tryx, $tryy);
		solve($path, $tryx, $tryy, "");
	    }
	}
    } else {
	# first check if given x,y is part of existing $path
	foreach my $p (@{$path}) {
	    my ($px, $py) = @{$p};
	    if ($px == $x && $py == $y) {
		# Path cannot be crossed again! 
		return;
	    }
	}

	my $c = char_at($x, $y);
	$attempt = $attempt . $c;
	if (valid_word($attempt)) {
	    $solutions->{$attempt} = { word => $attempt, path => [ @{$path}, [ $x, $y ] ] };
	} else {

	}
	# check if this is at least a valid attempt
	if (valid_attempt($attempt)) {
	    
	    # try to explore neighbours; update the current path
	    foreach my $trypath (@{ neighbour_coords($x, $y) }) {
		my ($tx, $ty) = @{$trypath};
		solve([ @{$path}, [$x, $y] ], $tx, $ty, $attempt);
	    }
	}
    }
}

sub show_solutions {
    my $words = [ keys %{$solutions} ];
    my $wc = scalar(@{$words});
    my $c = 1;
    print "Found $wc words. \n";
    foreach my $word (sort { length($a) <=> length($b) } @{$words}) {
	print "$c. $word:\n";
	$c++;
	my $s = $solutions->{$word};
	showboard(20, $s->{path});
    }
}

# main

loaddict();
inputboard();
solve();
show_solutions();
