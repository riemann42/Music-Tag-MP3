#!/usr/bin/perl -w
use strict;

use Test::More tests => 3;
use File::Copy;
use Test::Weaken qw(leaks);
use 5.006;

BEGIN { use_ok('Music::Tag') }

our $options = {};

# Add 13 test for each run of this
sub filetest {
    my $file        = shift;
    my $filetest    = shift;
    my $testoptions = shift;
  SKIP: {
        skip "File: $file does not exists", 1 unless ( -f $file );
		return unless ( -f $file );
		copy( $file, $filetest );
		my $test = sub {
			my $tag = Music::Tag->new( $filetest, $testoptions );
			die unless $tag;
			$tag->get_tag;
			$tag->title("Elise Test");
			$tag->set_tag;
			$tag->close();
			return $tag;
		};
		ok(! leaks($test), 'No Memory Leaks for Option Tag');
    }
}

ok( Music::Tag->LoadOptions("t/options.conf"), "Loading options file.\n" );
filetest( "t/elise.mp3", "t/elisetest.mp3" );
