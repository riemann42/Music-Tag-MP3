#!/usr/bin/perl -w
use strict;

use Test::More tests => 15;
use File::Copy;
use 5.006;

BEGIN { use_ok('Music::Tag') }

our $options = {};

# Add 13 test for each run of this
sub filetest {
    my $file        = shift;
    my $filetest    = shift;
    my $testoptions = shift;
  SKIP: {
        skip "File: $file does not exists", 7 unless ( -f $file );
        return unless ( -f $file );
        copy( $file, $filetest );
        my $tag = Music::Tag->new( $filetest, $testoptions );
        ok( $tag, 'Object created: ' . $filetest );
        die unless $tag;
        ok( $tag->get_tag, 'get_tag called: ' . $filetest );
        ok( $tag->isa('Music::Tag'), 'Correct Class: ' . $filetest );
        is( $tag->artist, "Beethoven", 'Artist: ' . $filetest );
        is( $tag->album,  "GPL",       'Album: ' . $filetest );
        is( $tag->title,  "Elise",     'Title: ' . $filetest );
        ok( $tag->title("Elise Test"), 'Set new title: ' . $filetest );
        ok( $tag->set_tag, 'set_tag: ' . $filetest );
        $tag->close();
        $tag = undef;
        my $tag2 = Music::Tag->new( $filetest, $testoptions);
        ok( $tag2, 'Object created again: ' . $filetest );
        die unless $tag2;
        ok( $tag2->get_tag, 'get_tag called: ' . $filetest );
        is( $tag2->title, "Elise Test", 'New Title: ' . $filetest );
        ok( $tag2->title("Elise"), 'Reset title: ' . $filetest );
        ok( $tag2->set_tag, 'set_tag again: ' . $filetest );
        $tag2->close();
        unlink($filetest);
    }
}

ok( Music::Tag->LoadOptions("t/options.conf"), "Loading options file.\n" );
filetest( "t/elise.mp3", "t/elisetest.mp3" );

