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
use CPAN::Search::Author;
use Storable;
use Data::Dumper;
use alphageek;

my $cache;

    my $slideshare_hashref = retrieve('slideshare_name.store');
    my @slideshare_ids = keys %$slideshare_hashref;
    my @slideshare_names = values %$slideshare_hashref;

	my $html_filename = "./release/alphageek_recent.html";

    my $search_cpan = WebService::Simple->new(
    base_url => "http://search.cpan.org/uploads.rdf'",
    ache    => $cache
    );

	my $response   = $search_cpan->get();
	my $feed= $response->parse_response;

    my @ratings;
    for my $item ( @{ $feed->{item} || [] } ) {
        my ( $rating, $comment ) = $item->{description}
        =~ /Rating: \s* ([\d.]+) \s* stars \s* (.+)/sx;

        $rating = 'N/A'
            unless defined $rating;

        $comment = $item->{description}
            unless defined $comment;

        my $string = $item->{'dc:creator'};
        Encode::_utf8_off($string);


        push @ratings, {

            creator     => decode('UTF-8', $string),
            link        => $item->{link},
            dist        => $item->{title},
            comment     => $comment,
            rating      => $rating,
        };
        
        print Dump($item);
        
    }

    my @cpans;
    my $search = CPAN::Search::Author->new();

    for my $ratingref (@ratings){
        my %rating = %$ratingref;

#		printf "%s\n" ,$rating{creator};
        
        my $result = $search->where_name_contains($rating{creator});
        print Dump($result);
        my $id;
        for my $cpanid (keys  %$result){
            $id = $cpanid;
            last;
        }
        if (defined $id){
            push @cpans, {id=> $id, dist => $rating{dist}, name => $rating{creator} };
	    }

    }

    for my $cpan( @cpans){
        
		printf "%s,%s,%s\n" ,$cpan->{id}, $cpan->{dist},$cpan->{name};
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
			 name=> $cpan->{name} , id=> $cpan->{id}, distribution => $cpan->{dist},
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

	save_recent_html(\@persons, "test", $html_filename);

