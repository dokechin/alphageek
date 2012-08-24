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

use Data::Dumper;

my $cache;

my $github = WebService::Simple->new(
     base_url => "https://api.github.com/",
     response_parser => 'JSON',
     ache    => $cache
);

    $github->show_progress(1);
    my $response = $github->get( 'users/seasonhuang', {});
    my $ref= $response->parse_response;



