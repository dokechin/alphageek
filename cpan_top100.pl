#!/usr/bin/perl

use strict;
use warnings;
use IO::File;
use YAML;
use WebService::Simple;
use Feed::Find;
use XML::OPML;
use Template;
use Template::Provider::Encoding;
use Template::Stash::ForceUTF8;
use Cache::File;
use Encode;
use utf8;
use Acme::CPANAuthors;
use URI::Escape;
use Coro;
use Coro::LWP;
use alphageek;
use Storable;
use CPAN::WWW::Top100::Retrieve;
use CPAN::Search::Author;



my @categoryinfos;
#my @categories = qw( heavy volatile debian downstream meta1 meta2 meta3 fail );
my @categories = qw( downstream meta1 meta2 meta3 fail );
my @persons;

my $slideshare_hashref = retrieve('slideshare_name.store');
my @slideshare_ids = keys %$slideshare_hashref;
my @slideshare_names = values %$slideshare_hashref;

my $cache = Cache::File->new(
               cache_root      => "/tmp/mycache",
               default_expires => "30 min",
           );


for my $category(@categories){



	my $html_filename = "./release/alphageek_top100_" . $category . ".html";

    my @cpans;

    my $top100 = CPAN::WWW::Top100::Retrieve->new;

#    my $index = 0;
    for my $dist  (@{ $top100->list( $category) } ){
        my $rank = $dist->rank;

        my $search = CPAN::Search::Author->new();
        my $name = $search->by_id($dist->author);

        push @cpans, {id=> $dist->author, dist=> $dist->dist, rank => $rank, name => $name };

    }

    printf "******%s*************\n", $category;

    @cpans = sort { $a->{rank} <=>  $b->{rank}} @cpans;

	push @categoryinfos, {category => $category};

    for my $cpan( @cpans){
        
		printf "%s,%d\n" ,$cpan->{id}, $cpan->{rank};
    }


	my @coros;
	my @persons = ();
	for my $cpan ( @cpans ) {

		push @coros,async {

			(my $url,my $blog_url,my $public_gists) = search_github($cpan->{name});

            my $homepage_url;
            my $homepage_title;
            my $search_cpan = WebService::Simple->new(
                  base_url => "http://search.cpan.org/",
                  ache    => $cache
            );

			my $content;
			eval{
	    		my $response   = $search_cpan->get('~' . $cpan->{id});
		    	$content = $response->decoded_content;
	    	};
	    	if ($@){
	    		my $response   = $search_cpan->get('~' . $cpan->{id});
		    	$content = $response->decoded_content;
	    	}
	    	
	    	

			if ( $content =~ m#<a href="(.*?)" rel="me">#g ){
				$homepage_url = $1;

				my $homepage = WebService::Simple->new(
				base_url => $homepage_url,
				ache    => $cache,
	    		);
				eval{
					my $response   = $homepage->get();

					printf "homepage_url=%s\n", $homepage_url;

					if ($response->is_success){
						my $content = $response->decoded_content('default_charset'=>'utf8');

						if ( $content =~ m!<title.*?>(.+?)</title>!i  ) {
							$homepage_title =  encode_utf8($1);
						}
					}
					elsif ($response->is_redirect ) {
						printf "is_redirect !!! \n";
					}
				};
				if ( $@ ){
					$homepage_title = $homepage_url;
				}
			}

			my $blog_title ='';
			my $hatena_count;
			my $hatena_url;
			if ($blog_url ){

				my $blog = WebService::Simple->new(
				base_url => $blog_url,
				ache    => $cache,
	    		);
				
				eval{
					my $response   = $blog->get();
					printf "blog_url=%s\n", $blog_url;
					my $content = $response->decoded_content('default_charset'=>'utf8');

					if ( $content =~ m!<title.*?>(.+?)</title>!i ) {
						$blog_title =  encode_utf8($1);
					}
				};
				if ( $@ ){
					$blog_title = $blog_url;
				}

				my $hatena = WebService::Simple->new(
				base_url => "http://b.hatena.ne.jp/entry/jsonlite/",
				response_parser => WebService::Simple::Parser::JSON->new(json => JSON->new->allow_nonref),
				ache    => $cache
				);

				eval{
					my $ref   = $hatena->get({ url => $blog_url })->parse_response;
					$hatena_count = $ref->{count};
					$hatena_url = $ref->{entry_url};
				};
				if ( $@ ) {
					printf "hatena error (%s) \n", $url;
				}

#				print Dump($ref);



			}
			
			if (!defined $hatena_count){
				$hatena_count = 0;
			}
			if (!defined $public_gists){
				$public_gists = 0;
			}
			
			my @slideshare_hit_ids = map {  $slideshare_ids[$_] }  grep { uc $slideshare_names[$_] eq uc $cpan->{name}}  0 .. $#slideshare_names;
			if ($#slideshare_hit_ids == -1){
				@slideshare_hit_ids = map {  $slideshare_ids[$_] }  grep { uc $slideshare_names[$_] eq reverse_name(uc $cpan->{name})}  0 .. $#slideshare_names;
			}

			my $slideshare_count;
			if ($#slideshare_hit_ids >= 0){
				$slideshare_count = slideshare_count($slideshare_hit_ids[0]);
			}

			push(@persons, { 
			 name=> $cpan->{name} , id=> $cpan->{id}, rank => $cpan->{rank},
			 dist=> $cpan->{dist},
			 homepage_url => $homepage_url, homepage_title => $homepage_title,
             github_url => $url, blog_url => $blog_url, blog_title => $blog_title, public_gists => $public_gists,
             hatena_count => $hatena_count,hatena_url => $hatena_url,
             slideshare_id => $slideshare_hit_ids[0],
             slideshare_count => $slideshare_count
			});
        }
	}

	$_->join for @coros;

    @persons = sort {  $a->{rank} <=>  $b->{rank} } @persons;

	save_top100_html(\@persons,$category, $html_filename);
}


