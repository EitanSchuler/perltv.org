package PerlTV::Import;
use strict;
use warnings FATAL => 'all';
use 5.010;

use Path::Tiny qw(path);
use JSON::Tiny ();
use Data::Dumper qw(Dumper);

use PerlTV::Tools qw(read_file youtube_thumbnail);

my %sources;
my %people;
my %seen;
my $json;
my @not_featured;
my @featured;


sub new {
	my ($class) = @_;
	$json = JSON::Tiny->new;
	return bless {}, $class;
}

sub import_sources {
	my $dir = path($0)->absolute->parent->parent->child('data/sources');
	foreach my $f ($dir->children) {
		next if $f =~ /\.swp$/;
		next if $f =~ /\.bak$/;
		my $source = read_file($f);
		$sources{ $f->basename } = $source;
	}
	path('sources.json')->spew_utf8( $json->encode(\%sources) );
}


sub import_people {
	my $dir = path($0)->absolute->parent->parent->child('data/people');
	foreach my $f ($dir->children) {
		next if $f =~ /\.swp$/;
		next if $f =~ /\.bak$/;
		my $person = read_file($f);
		$people{ $f->basename } = $person;
	}
	path('people.json')->spew_utf8( $json->encode(\%people) );
}


sub import_videos {
	my $dir = path($0)->absolute->parent->parent->child('data/videos');
	my @videos;
	my %tags;
	my %modules;
	my %meta;
	foreach my $f ($dir->children) {
		next if $f =~ /\.swp$/;
		next if $f =~ /\.bak$/;
		my $video = read_file($f);
		die "Missing source in $f" if not $video->{source};
		die "Unindentified source '$video->{source}' in $f"
			if not $sources{ $video->{source} };
		die "Missing speaker in $f" if not $video->{speaker};
		die "Unindentified speaker '$video->{speaker}' in $f"
			if not $people{ $video->{speaker} };
		if ($video->{length} !~ /(\d\d:)?\d?\d:\d\d$/) {
			die "Invalid length format '$video->{length}' in file '$f'\n";
		}
		if ($video->{date} !~ /^\d\d\d\d-\d\d-\d\d( \d\d:\d\d:\d\d)?$/) {
			die "Invalid date format '$video->{date}' in file '$f'\n";
		}
		if ($video->{featured} and $video->{featured} !~ /^\d\d\d\d-\d\d-\d\d( \d\d:\d\d:\d\d)?$/) {
			die "Invalid featrued format '$video->{featured}' in file '$f'\n";
		}

		$seen{$video->{src}}{$video->{id}} = 1;

		my $thumbnail = $video->{thumbnail} || youtube_thumbnail($video->{id});

		#warn Dumper $video;
		my %entry = (
			title => $video->{title},
			date  => $video->{date},
			featured  => $video->{featured},
			path  => $f->basename,
			language => $video->{language},
			thumbnail => $thumbnail,
			length   => $video->{length},
		);
	
		my %item = (
			id        => $video->{id},
			title     => $video->{title},
			featured  => ($video->{featured} || ''),
			date      => $video->{date},
			path      => $f->basename,
			thumbnail => $thumbnail,
			language  => $video->{language},
		);
		if ($video->{featured}) {
			push @featured, \%item;
		} else {
			push @not_featured, \%item;
		}
		if ($video->{tags}) {
			foreach my $tag (@{ $video->{tags} }) {
				push @{ $tags{lc $tag} }, \%entry;
			}
		}
		if ($video->{modules}) {
			foreach my $module (@{ $video->{modules} }) {
				push @{ $modules{$module} }, \%entry;
				push @{ $meta{modules}{$module} }, {
					title => $video->{title},
					url   => 'http://perltv.org/v/' . $f->basename,
					thumbnail => $thumbnail,
				};
			}
		}
	
		push @videos, {
			%entry,
			source  => $video->{source},
			speaker => $video->{speaker},
		};
	}
	
	@featured = sort { $b->{featured} cmp $a->{featured} } @featured;
	#@not_featured = sort { $b->{id} cmp $a->{id} } @not_featured;
	{
		my @dated = sort { $b->{date} cmp $a->{date} } grep { $_->{date} } @not_featured;
		my @undated = sort { $b->{id} cmp $a->{id} } grep { ! $_->{date} } @not_featured;
		@not_featured = (@dated, @undated);
	}
	
	my %data = (
		_comment => 'This is a generated file, please do NOT edit directly',
		videos => [ sort { $a->{title} cmp $b->{title} } @videos ],
	);
	path('videos.json')->spew_utf8( $json->encode(\%data) );
	path('featured.json')->spew_utf8( $json->encode(\@featured) );
	path('not_featured.json')->spew_utf8( $json->encode(\@not_featured) );
	path('tags.json')->spew_utf8( $json->encode(\%tags) );
	path('modules.json')->spew_utf8( $json->encode(\%modules) );
	path('public/meta.json')->spew_utf8( $json->encode(\%meta) );
	
	return \%seen;
}

sub print_latest_featured {
	say "Latest featured: $featured[0]{featured}\n";
}
sub print_not_featured {
	if (@not_featured) {
		say 'Not yet featured:';
		for my $v (@not_featured) {
			print $v->{date} ? $v->{date} : '          ';
			say "  $v->{path}";
		}
	}
}


1;

