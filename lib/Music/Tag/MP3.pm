package Music::Tag::MP3;
our $VERSION = 0.29;
our @AUTOPLUGIN = qw(mp3);

# Copyright (c) 2007 Edward Allen III. Some rights reserved.
#
## This program is free software; you can redistribute it and/or
## modify it under the terms of the Artistic License, distributed
## with Perl.
#

=pod

=head1 NAME

Music::Tag::MP3 - Plugin module for Music::Tag to get information from id3 tags

=head1 SYNOPSIS

	use Music::Tag

	my $info = Music::Tag->new($filename, { quiet => 1 }, "MP3");
	$info->get_info();
   
	print "Artist is ", $info->artist;

=head1 DESCRIPTION

Music::Tag::MP3 is used to read id3 tag information. It uses MP3::Tag to read id3v2 and id3 tags from mp3 files. As such, it's limitations are the same as MP3::Tag. It does not write id3v2.4 tags, causing it to have some trouble with unicode.

=head1 REQUIRED VALUES

No values are required (except filename, which is usually provided on object creation).

=head1 SET VALUES


=cut

use strict;
use MP3::Tag;
use MP3::Info;
use Data::Dumper;

#use Image::Magick;
our @ISA = qw(Music::Tag::Generic);

sub default_options {
    { apic_cover => 1, };
}

sub _decode_uni {
    my $in = shift;
	my $c = unpack( "U", substr( $in, 0, 1 ) );
    if ( ($c) && ($c == 255 )) {
		$in = decode("UTF-16LE", $in); 
		#$in =~ s/^[^A-Za-z0-9]*//;
		#$in =~ s/ \/ //g;
    }
    return $in;
}

sub mp3 {
	my $self = shift;
	unless ((exists $self->{'_mp3'}) && (ref $self->{'_mp3'})) {
		if ($self->info->filename) {
			$self->{'_mp3'} = MP3::Tag->new($self->info->filename);
		}
		else {
			return undef;
		}
	}
	return $self->{'_mp3'};
}

sub get_tag {
    my $self     = shift;
    return unless ( $self->mp3 );
    $self->mp3->config( id3v2_mergepadding => 0 );
	$self->mp3->config( autoinfo => "ID3v2", "ID3v1");
    return unless $self->mp3;
    $self->mp3->get_tags;

=over 4

=item mp3 file info added:

   Currently this includes bitrate, duration, frequency, stereo, bytes, codec, frames, vbr, 
=cut

    $self->info->bitrate( $self->mp3->bitrate_kbps );
    $self->info->duration( $self->mp3->total_millisecs_int );
    $self->info->frequency( $self->mp3->frequency_Hz() );
    $self->info->stereo( $self->mp3->is_stereo() );
    $self->info->bytes( $self->mp3->size_bytes() );
    if ( $self->mp3->mpeg_version() ) {
        $self->info->codec(   "MPEG Version "
                            . $self->mp3->mpeg_version()
                            . " Layer "
                            . $self->mp3->mpeg_layer() );
    }
    $self->info->frames( $self->mp3->frames() );
    $self->info->framesize( $self->mp3->frame_len() );
    $self->info->vbr( $self->mp3->is_vbr() );

=item id3v1 tag info added:

title, artist, album, track, comment, year and genre

=cut

    eval {
        $self->info->title( _decode_uni( $self->mp3->title ) );
        $self->info->artist( _decode_uni( $self->mp3->artist ) );
        $self->info->album( _decode_uni( $self->mp3->album ) );
        $self->info->tracknum( _decode_uni( $self->mp3->track ) );
        $self->info->comment( _decode_uni( $self->mp3->comment ) );
        $self->info->year( _decode_uni( $self->mp3->year ) );
        $self->info->genre( _decode_uni( $self->mp3->genre ) );
    };
    warn $@ if $@;

=pod

=item id3v2 tag info added:

title, artist, album, track, totaltracks, year, genre, disc, totaldiscs, label, releasedate, lyrics (using USLT), url (using WCOM), encoder (using TFLT),  and picture (using apic). 

=cut

    if ( exists $self->mp3->{ID3v2} ) {
        unless ( (defined $self->info->title) && ($self->info->title  eq $self->mp3->{ID3v2}->title ))  { $self->info->changed }
        unless ( (defined $self->info->artist) &&  ($self->info->artist eq $self->mp3->{ID3v2}->artist )) { $self->info->changed }
        unless ( (defined $self->info->album) &&  ($self->info->album  eq $self->mp3->{ID3v2}->album ))  { $self->info->changed }
        unless ( (defined $self->info->year) &&  ($self->info->year   eq $self->mp3->{ID3v2}->year ))   { $self->info->changed }
        unless ( (defined $self->info->track) &&  ($self->info->track  eq $self->mp3->{ID3v2}->track ))  { $self->info->changed }
        unless ( (defined $self->info->genre) &&  ($self->info->genre  eq $self->mp3->{ID3v2}->genre ))  { $self->info->changed }
        if ( $self->info->{changed} ) {
            $self->status("ID3v2 tag does not have all needed information");
        }
        $self->info->discnum( $self->mp3->{ID3v2}->get_frame('TPOS') );
        $self->info->label( $self->mp3->{ID3v2}->get_frame('TPUB') );
        $self->info->sortname( $self->mp3->{ID3v2}->get_frame('TPE1') );
        $self->info->sortname( $self->mp3->{ID3v2}->get_frame('XSOP') );

        # Remove this eventually, changing tag to TXXX[ASIN]
        $self->info->asin( $self->mp3->{ID3v2}->get_frame('TOWN') );
        my $t;

        my $day = $self->mp3->{ID3v2}->get_frame('TDAT') || "";
        if ( ( $day =~ /(\d\d)(\d\d)/ ) && ( $self->info->year ) ) {
			my $releasedate = $self->info->year . "-" . $1 . "-" . $2 ;
			my $time = $self->mp3->{ID3v2}->get_frame('TIME') || "";
			if ($time =~ /(\d\d)(\d\d)/) {
				$releasedate .= " ". $1 . ":" . $2;
			}
            $self->info->releasetime($releasedate); 
        }

        my $mbid = $self->mp3->{ID3v2}->get_frame('UFID');
		if (ref $mbid) {
         $self->info->mb_trackid($mbid->{_Data}); 
	    }
        my $lyrics = $self->mp3->{ID3v2}->get_frame('USLT');
        if ( ref $lyrics ) {
            $self->info->lyrics( $lyrics->{Text} );
        }
        if ( ref $self->mp3->{ID3v2}->get_frame('WCOM') ) {
            $self->info->url( $self->mp3->{ID3v2}->get_frame('WCOM')->{URL} );
        }
        else {
            $self->info->url("");
        }
        if ( ref $self->mp3->{ID3v2}->get_frame('TFLT') ) {
            $self->info->encoder( $self->mp3->{ID3v2}->get_frame('TFLT') );
        }
        if ( $self->mp3->{ID3v2}->get_frame('TENC') ) {
            $self->info->encoded_by( $self->mp3->{ID3v2}->get_frame('TENC') );
        }
        if ( ref $self->mp3->{ID3v2}->get_frame('USER') ) {
            if ( $self->mp3->{ID3v2}->get_frame('USER')->{Language} eq "Cop" ) {
                $self->status("Emusic mistagged file found");
                $self->info->encoded_by('emusic');
            }
        }
        if (    ( not $self->options->{ignore_apic} )
             && ( $self->mp3->{ID3v2}->get_frame('APIC') ) 
		     && ( not $self->info->picture_exists)) {
            $self->info->picture( $self->mp3->{ID3v2}->get_frame('APIC') );
        }
		if ($self->info->comment =~ /^Amazon.com/i) {
			$self->info->encoded_by('Amazon.com');
		}
		if ($self->info->comment =~ /^cdbaby.com/i) {
			$self->info->encoded_by('cdbaby.com');
		}

=pod

=item The following information is gathered from the ID3v2 tag using custom tags

TXXX[ASIN]   asin
TXXX[Sortname] sortname
TXXX[MusicBrainz Artist Id] mb_artistid
TXXX[MusicBrainz Album Id] mb_albumid
TXXX[MusicBrainz Track Id] mb_trackid
TXXX[MusicBrainz Album Type] album_type
TXXX[MusicBrainz Artist Type] artist_type

=cut

        $t = $self->mp3->{ID3v2}->frame_select( "TXXX", "ASIN", [''] );
        if ($t) { $self->info->asin($t); }
        $t = $self->mp3->{ID3v2}->frame_select( "TXXX", "Sortname", [''] );
        if ($t) { $self->info->sortname($t); }
        $t =
          $self->mp3->{ID3v2}->frame_select( "TXXX", "MusicBrainz Album Artist Sortname", [''] );
        if ($t) { $self->info->albumartist_sortname($t); }
        $t = $self->mp3->{ID3v2}->frame_select( "TXXX", "MusicBrainz Album Artist", [''] );
        if ($t) { $self->info->albumartist($t); }
        $t =
          $self->mp3->{ID3v2}->frame_select( "TXXX", "MusicBrainz Album Release Country", [''] );
        if ($t) { $self->info->countrycode($t); }
        $t = $self->mp3->{ID3v2}->frame_select( "TXXX", "MusicBrainz Artist Id", [''] );
        if ($t) { $self->info->mb_artistid($t); }
        $t = $self->mp3->{ID3v2}->frame_select( "TXXX", "MusicBrainz Album Id", [''] );
        if ($t) { $self->info->mb_albumid($t); }
        $t = $self->mp3->{ID3v2}->frame_select( "TXXX", "MusicBrainz Track Id", [''] );
        if ($t) { $self->info->mb_trackid($t); }


        $t = $self->mp3->{ID3v2}->frame_select( "TXXX", "MusicBrainz Album Status", [''] );
        if ($t) { $self->info->album_type($t); }
        $t = $self->mp3->{ID3v2}->frame_select( "TXXX", "MusicBrainz Artist Type", [''] );
        if ($t) { $self->info->artist_type($t); }
        $t = $self->mp3->{ID3v2}->frame_select( "TXXX", "MusicIP PUID", [''] );
        if ($t) { $self->info->mip_puid($t); }
        $t = $self->mp3->{ID3v2}->frame_select( "TXXX", "Artist Begins", [''] );
        if ($t) { $self->info->artist_start($t); }
        $t = $self->mp3->{ID3v2}->frame_select( "TXXX", "Artist Ends", [''] );
        if ($t) { $self->info->artist_end($t); }
    }

=pod

=item Some data in the LAME header is obtained from MP3::Info (requires MP3::Info 1.2.3)

pregap
postgap

=cut

   $self->{mp3info} = MP3::Info::get_mp3info($self->info->filename);
   if ($self->{mp3info}->{LAME}) {
	   $self->info->pregap($self->{mp3info}->{LAME}->{start_delay});
	   $self->info->postgap($self->{mp3info}->{LAME}->{end_padding});
	   if ($self->{mp3info}->{LAME}->{encoder_version}) {
	       $self->info->encoder($self->{mp3info}->{LAME}->{encoder_version});
	   }
    }

    return $self;
}

sub calculate_gapless {
	my $self = shift;
	my $file = shift;
	my $gap = {};
	require MP3::Info;
	$MP3::Info::get_framelengths = 1;
	my $info = MP3::Info::get_mp3info($file);
	if (($info) && ($info->{LAME}->{end_padding}))  {
		$gap->{gaplesstrackflag} = 1;
		$gap->{pregap} = $info->{LAME}->{start_delay};
		$gap->{postgap} = $info->{LAME}->{end_padding};
		$gap->{samplecount} = $info->{FRAME_SIZE} * scalar($info->{FRAME_LENGTHS}) - $gap->{pregap} - $gap->{postgap};
		my $finaleight = 0;
		for (my $n = 1; $n <= 8; $n++) {
			$finaleight += $info->{FRAME_LENGTHS}->[-1 * $n];
		}
		$gap->{gaplessdata} = Math::Int64::uint64($info->{SIZE}) - Math::Int64::uint64($finaleight);
	}
	return $gap;
}

sub strip_tag {
    my $self = shift;
    $self->status("Stripping current tags");
    if ( exists $self->mp3->{ID3v2} ) {
        $self->mp3->{ID3v2}->remove_tag;
        $self->mp3->{ID3v2}->write_tag;
    }
    if ( exists $self->mp3->{ID3v1} ) {
        $self->mp3->{ID3v1}->remove_tag;
    }
    return $self;
}

sub set_tag {
    my $self     = shift;
    my $filename = $self->info->filename;
    $self->status("Updating MP3");
    my $id3v1;
    my $id3v2;
    if ( $self->mp3->{ID3v2} ) {
        $id3v2 = $self->mp3->{ID3v2};
    }
    else {
        $id3v2 = $self->mp3->new_tag("ID3v2");
    }
    if ( $self->mp3->{ID3v1} ) {
        $id3v1 = $self->mp3->{ID3v1};
    }
    else {
        $id3v1 = $self->mp3->new_tag("ID3v1");
    }
    $self->status("Writing ID3v2 Tag");
    ($self->info->title) && $id3v2->title( $self->info->title );
    ($self->info->artist) && $id3v2->artist( $self->info->artist );
    ($self->info->album) && $id3v2->album( $self->info->album );
    ($self->info->year) && $id3v2->year( $self->info->year );
    ($self->info->track) && $id3v2->track( $self->info->tracknum );
    ($self->info->genre) && $id3v2->genre( $self->info->genre );
	if ($self->info->disc) {
		$id3v2->remove_frame('TPOS');
		$id3v2->add_frame( 'TPOS', 0, $self->info->disc );
	}
	if ($self->info->label) {
		$id3v2->remove_frame('TPUB');
		$id3v2->add_frame( 'TPUB', 0, $self->info->label );
	}
	if ($self->info->url) {
		$id3v2->remove_frame('WCOM');
		$id3v2->add_frame( 'WCOM', 0, _url_encode( $self->info->url ) );
	}

    if ( $self->info->encoded_by ) {
        $id3v2->remove_frame('TENC');
        $id3v2->add_frame( 'TENC', 0, $self->info->encoded_by );
    }
    if ( $self->info->asin ) {
        $id3v2->frame_select( 'TXXX', 'ASIN', [''], $self->info->asin );
    }
    if ( $self->info->mb_trackid ) {
        $id3v2->frame_select( 'TXXX', 'MusicBrainz Track Id', [''], $self->info->mb_trackid );
		$id3v2->remove_frame('UFID');
		$id3v2->add_frame( 'UFID', 'http://musicbrainz.org', $self->info->mb_trackid ); 
    }
    if ( $self->info->mb_artistid ) {
        $id3v2->frame_select( 'TXXX', 'MusicBrainz Artist Id', [''], $self->info->mb_artistid );
    }
    if ( $self->info->mb_albumid ) {
        $id3v2->frame_select( 'TXXX', 'MusicBrainz Album Id', [''], $self->info->mb_albumid );
    }
    if ( $self->info->album_type ) {
        $id3v2->frame_select( 'TXXX', 'MusicBrainz Album Status', [''], $self->info->album_type );
    }
    if ( $self->info->artist_type ) {
        $id3v2->frame_select( 'TXXX', 'MusicBrainz Artist Type', [''], $self->info->artist_type );
    }
    if ( $self->info->albumartist ) {
        $id3v2->frame_select( 'TXXX', 'MusicBrainz Album Artist', [''], $self->info->albumartist );
    }
    if ( $self->info->albumartist_sortname ) {
        $id3v2->frame_select( 'TXXX', 'MusicBrainz Album Artist Sortname',
                              [''], $self->info->albumartist_sortname );
    }
    if ( $self->info->countrycode ) {
        $id3v2->frame_select( 'TXXX', 'MusicBrainz Album Release Country',
                              [''],   $self->info->countrycode );
    }
    if ( $self->info->mip_puid ) {
        $id3v2->frame_select( 'TXXX', 'MusicIP PUID', [''], $self->info->mip_puid );
    }
    if ( $self->info->artist_start ) {
        $id3v2->frame_select( 'TXXX', 'Artist Begins', [''], $self->info->artist_start );
    }
    if ( $self->info->artist_end ) {
        $id3v2->frame_select( 'TXXX', 'Artist Ends', [''], $self->info->artist_end );
    }
    $id3v2->remove_frame('USLT');
    $id3v2->add_frame( 'USLT', 0, "ENG", "Lyrics", $self->info->lyrics );

    if (($self->info->releasedate) && ( $self->info->releasetime =~ /(\d\d\d\d)-?(\d\d)?-?(\d\d)? ?(\d\d)?:?(\d\d)?/ )) {
		my $day = sprintf("%02d%02d", $2 || 0, $3 || 0);
		my $time = sprintf("%02d%02d", $4 || 0, $5 || 0);
        $id3v2->remove_frame('TDAT');
        $id3v2->add_frame( 'TDAT', 0, $day );
        $id3v2->remove_frame('TIME');
        $id3v2->add_frame( 'TIME', 0, $time );
    }
    unless ( $self->options->{ignore_apic} ) {
        $id3v2->remove_frame('APIC');
        if ( ( $self->options->{apic_cover} ) && ( $self->info->picture ) ) {
            $self->status("Saving Cover to APIC frame");
            $id3v2->add_frame( 'APIC', _apic_encode( $self->info->picture ) );
        }
    }
    $self->status("Writing ID3v1 Tag for $filename");
    eval { $id3v2->write_tag(); };
    ($self->info->title) && $id3v1->title( $self->info->title );
    ($self->info->artist) && $id3v1->artist( $self->info->artist );
    ($self->info->album) && $id3v1->album( $self->info->album );
    ($self->info->year) && $id3v1->year( $self->info->year );
    ($self->info->tracknum) && $id3v1->track( $self->info->tracknum );
    ($self->info->genre) && $id3v1->genre( $self->info->genre );
    eval { $id3v1->write_tag(); };
    return $self;
}

sub close {
    my $self = shift;
	if ($self->mp3) {
		$self->mp3->close();
		$self->mp3->{ID3v2} = undef;
		$self->mp3->{ID3v1} = undef;
		$self->{'_mp3'}          = undef;
	}
}

sub _apic_encode {
    my $code = shift;
    my @PICTYPES = ( "Other",
                     "32x32 pixels 'file icon' (PNG only)",
                     "Other file icon",
                     "Cover (front)",
                     "Cover (back)",
                     "Leaflet page",
                     "Media (e.g. lable side of CD)",
                     "Lead artist/lead performer/soloist",
                     "Artist/performer",
                     "Conductor",
                     "Band/Orchestra",
                     "Composer",
                     "Lyricist/text writer",
                     "Recording Location",
                     "During recording",
                     "During performance",
                     "Movie/video screen capture",
                     "A bright coloured fish",
                     "Illustration",
                     "Band/artist logotype",
                     "Publisher/Studio logotype"
                   );
    my $c = 0;
    my %PICBYTES = map { $_ => chr( $c++ ) } @PICTYPES;
    return ( 0, $code->{"MIME type"}, $code->{"Picture Type"}, $code->{"Description"},
             $code->{_Data} );
}

sub _url_encode {
    my $url = shift;
    return ($url);
}

=back

=head1 METHODS

=over 4

=item default_options

Returns the default options for the plugin.  

=item set_tag

Save object back to ID3v2.3 and ID3v1 tag.

=item get_tag

Load information from ID3v2 and ID3v1 tags.

=item strip_tag

Remove the tag from the file.

=item close

Close the file and destroy the MP3::Tag object.

=item mp3

Returns the MP3::Tag object

=back

=head1 OPTIONS

=over 4

=item apic_cover

Set to false to disable writing picture to tag.  True by default.

=item ignore_apic

Ignore embeded picture.

=item calculate_gapless

Calculate gapless playback information.  Requires patched version of MP3::Info to work.

=back

=head1 BUGS

ID3v2.4 is not read reliablly and can't be writen.  Apic cover is unreliable in older versions of MP3::Tag.  

=head1 SEE ALSO INCLUDED

L<Music::Tag>, L<Music::Tag::Amazon>, L<Music::Tag::File>, L<Music::Tag::FLAC>, L<Music::Tag::Lyrics>,
L<Music::Tag::M4A>, L<Music::Tag::MusicBrainz>, L<Music::Tag::OGG>, L<Music::Tag::Option>,

=head1 SEE ALSO

L<MP3::Tag>, L<MP3::Info>

=head1 AUTHOR 

Edward Allen III <ealleniii _at_ cpan _dot_ org>

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the terms of the Artistic License, distributed
with Perl.

=head1 COPYRIGHT

Copyright (c) 2007 Edward Allen III. Some rights reserved.

=cut


1;

# vim: tabstop=4
