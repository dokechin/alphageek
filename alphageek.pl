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


my $country = { 
	'Austrian' => 'at',
	'Brazilian' => 'br',
	'British' => 'gb',
	'Canadian' => 'ca',
	'Catalonian' => 'ct',
	'Chinese' => 'cn',
	'Danish' => 'dk',
	'Dutch' => 'nl',
	'French' => 'fr',
	'German' => 'de',
	'Icelandic' => 'is',
	'India' => 'in',
	'Indonesian' => 'id',
	'Israeli' => 'il',
	'Italian' => 'it',
	'Japanese' => 'jp',
	'Korean' => 'kr',
	'Norwegian' => 'no',
	'Portuguese' => 'pt',
	'Russian' => 'ru',
	'Spanish' => 'es',
	'Swedish' => 'se',
	'Taiwanese' => 'tw',
	'Turkish' => 'tr',
	'Ukrainian' => 'ua',
};

my @categoryinfos;
my @categories = Acme::CPANAuthors->_list_categories();
my $top_html_filename = "./release/index.html";
my @persons;

my $slideshare_hashref = retrieve('slideshare_name.store');
my @slideshare_ids = keys %$slideshare_hashref;
my @slideshare_names = values %$slideshare_hashref;

my $cache = Cache::File->new(
               cache_root      => "/tmp/mycache",
               default_expires => "30 min",
           );


for my $category(@categories){

#	if ($category ne "Japanese") {
#		next;
#	}


	my $html_filename = "./release/alphageek_" . $category . ".html";
#	my $opml_filename = "alphageek.opml";

    my $authors = Acme::CPANAuthors->new($category);

    my @ids      = $authors->id;

    my @cpans;

#    my $index = 0;
    for my $id (@ids){
        my @distros  = $authors->distributions($id);
        my $count = @distros;
        my $name  = $authors->name($id);


        if ($count > 0) {
            push @cpans, {id=> $id, count => $count, name => $name };
	    }

#        if ($index > 4) {
#        	last;
#        }
#        $index = $index + 1;
    }

    printf "******%s*************\n", $category;

    @cpans = sort { $b->{count} <=> $a->{count} } @cpans;

	push @categoryinfos, {category => $category, country => $country->{$category}, count => scalar(@cpans)};

    for my $cpan( @cpans){
        
		printf "%s,%d\n" ,$cpan->{id}, $cpan->{count};
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

    		my $response   = $search_cpan->get('~' . $cpan->{id});
	    	my $content = $response->decoded_content;

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
			 name=> $cpan->{name} , id=> $cpan->{id}, distributions_count => $cpan->{count},
			 homepage_url => $homepage_url, homepage_title => $homepage_title,
             github_url => $url, blog_url => $blog_url, blog_title => $blog_title, public_gists => $public_gists,
             hatena_count => $hatena_count,hatena_url => $hatena_url,
             total => $cpan->{count} + $public_gists + $hatena_count,
             slideshare_id => $slideshare_hit_ids[0],
             slideshare_count => $slideshare_count
			});
        }
	}

	$_->join for @coros;

    @persons = sort { $b->{distributions_count} <=> $a->{distributions_count} } @persons;

	save_html(\@persons,$category, $html_filename);
}

save_top_html(\@categoryinfos,$top_html_filename);


