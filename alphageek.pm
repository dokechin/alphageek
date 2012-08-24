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
use Text::LevenshteinXS qw(distance);
use Digest::SHA1 qw(sha1_hex);
use Data::Dumper;



sub save_html {
    my %widget = (
    'British' => '<iframe src="http://rcm-uk.amazon.co.uk/e/cm?t=leafroalp-21&o=2&p=16&l=st1&mode=books-uk&search=Perl&fc1=000000&lt1=_blank&lc1=3366FF&bg1=FFFFFF&f=ifr" marginwidth="0" marginheight="0" width="468" height="336" border="0" frameborder="0" style="border:none;" scrolling="no"></iframe>' ,
    'French' => '<iframe src="http://rcm-fr.amazon.fr/e/cm?t=leafroalp0c-21&o=8&p=16&l=st1&mode=books-fr&search=Perl program&fc1=000000&lt1=_blank&lc1=3366FF&bg1=FFFFFF&f=ifr" marginwidth="0" marginheight="0" width="468" height="336" border="0" frameborder="0" style="border:none;" scrolling="no"></iframe>' ,
    'Japanese' => '<iframe src="http://rcm-jp.amazon.co.jp/e/cm?t=thickbeard-22&o=9&p=16&l=st1&mode=books-jp&search=Perl&fc1=000000&lt1=_blank&lc1=3366FF&bg1=FFFFFF&f=ifr" marginwidth="0" marginheight="0" width="468" height="336" border="0" frameborder="0" style="border:none;" scrolling="no"></iframe>' ,
    );

    my ($persons, $category, $filename) = @_;
    my $number = @$persons;
    printf "--------------%d%s-----------\n", $number, $filename;
    
    for my $person( @$persons){
        
		printf "%s,%d\n" ,$person->{id}, $person->{distributions_count};
    }

    my $template = Template->new(
     LOAD_TEMPLATES => [ Template::Provider::Encoding->new ],
     STASH          => Template::Stash::ForceUTF8->new,);
    my $html;
    $template->process( "alphageek.tt", { persons => $persons, category => $category, widget => $widget{$category}},  \$html )
    or die $template->error;
    my $io = IO::File->new($filename, 'w');
    $io->print($html);
#    print $html;
    $io->close;
}

sub save_recent_html {
    my ($persons, $category, $filename) = @_;
    my $number = @$persons;
    printf "--------------%d%s-----------\n", $number, $filename;
    
    for my $person( @$persons){
        
		printf "%s,%d\n" ,$person->{id}, $person->{distribution};
    }

    my $template = Template->new(
     LOAD_TEMPLATES => [ Template::Provider::Encoding->new ],
     STASH          => Template::Stash::ForceUTF8->new,);
    my $html;
    $template->process( "alphageek_recent.tt", { persons => $persons, category => $category},  \$html )
    or die $template->error;
    my $io = IO::File->new($filename, 'w');
    $io->print($html);
#    print $html;
    $io->close;
}

sub save_top100_html {
    my ($persons, $category, $filename) = @_;
    my $number = @$persons;
    printf "--------------%d%s-----------\n", $number, $filename;
    
    for my $person( @$persons){
        
		printf "%s,%d\n" ,$person->{id}, $person->{rank};
    }

    my $template = Template->new(
     LOAD_TEMPLATES => [ Template::Provider::Encoding->new ],
     STASH          => Template::Stash::ForceUTF8->new,);
    my $html;
    $template->process( "alphageek_top100.tt", { persons => $persons, category => $category},  \$html )
    or die $template->error;
    my $io = IO::File->new($filename, 'w');
    $io->print($html);
#    print $html;
    $io->close;
}

sub save_top_html {

    my ($categories,$filename) = @_;

    (my $second,my $minute,my $hour, my $day, my $month, my $year) = localtime;
    my $update_date = sprintf "%d/%d/%d %d:%d:%d", $year+1900,$month +1 , $day, $hour, $minute, $second;

    my $template = Template->new(
     LOAD_TEMPLATES => [ Template::Provider::Encoding->new ],
     STASH          => Template::Stash::ForceUTF8->new,);

    my $html;
    $template->process( "alphageek_top.tt", { categories => $categories, update_date => $update_date},  \$html )
    or die $template->error;
    my $io = IO::File->new($filename, 'w');
    $io->print($html);
    $io->close;
}

sub count_slideshows{

    my ($q,$api_key, $secret) = @_;

    my $cache = Cache::File->new(
               cache_root      => "/tmp/mycache",
               default_expires => "30 min",
           );

    my $ts = time;
    my $hash = lc(sha1_hex($secret,$ts));

    my $slideshare = WebService::Simple->new(
           base_url => "http://www.slideshare.net/api/2/",
           param    => { api_key => $api_key, ts => $ts, hash => $hash},
           ache    => $cache
    );

    my $response   = $slideshare->get('search_slideshows',{ q => $q});
    
    print $response->code;
    my $xml = $response->parse_response;
    print Dump($xml);

    return $xml->{Meta}->{TotalResults};

}

sub slideshare_count{

    my ($id) = @_;
    my $ua = LWP::UserAgent->new;
    $ua->timeout(10);
    $ua->env_proxy;
 
    my $response = $ua->get('http://www.slideshare.net/'. $id);

    if ($response->code =~ /200/ ) {
       my $content = $response->decoded_content;
       if ( $content =~ m#(\d*)\s+SlideShares# ){
	     return 0+$1;
       }
       else{
         return 0;
       }
    }
    else{
      return 0;
    }
}

sub slideshare_name{

    my ($id) = @_;


    my $ua = LWP::UserAgent->new;
    $ua->timeout(10);
    $ua->env_proxy;
 
    my $response = $ua->get('http://www.slideshare.net/'. $id);

    if ($response->code =~ /200/ ) {
       my $content = $response->decoded_content;

        if ( $content =~ m#<meta property="slideshare:name"\s+content="(.*?)"\s*/>#g ){
	      return $1;
        }
        else{
          return "";
        }
    }
    else{
      return "";
    }

}

sub search_github {
    my ($name) = @_;

    my $cache = Cache::File->new(
               cache_root      => "/tmp/mycache",
               default_expires => "30 min",
           );
           
    my $github = WebService::Simple->new(
     base_url => "https://api.github.com/",
     response_parser => 'JSON',
     ache    => $cache
    );

    $github->show_progress(1);
    my $ref;
    eval{
        my $response = $github->get( 'legacy/user/search/' . $name, {});
        $ref= $response->parse_response;
    };
    if ( $@ ) {
        #retry
        eval{
            my $response = $github->get( 'legacy/user/search/' . $name, {});
            $ref= $response->parse_response;
        };
        if ( $@ ) {
            printf "error in legacy/user/search/%s" , $name;
            return ('','',0);
        }
    }

#    print Dump($ref);
    my $distance;
    my $username;
    my $git_name_save;

    foreach my $result (@{$ref->{users}}){
        my $username_tmp = $result->{username};
        my $git_name = $result->{name};
        
        if (!defined $git_name) {
            next;
        }

        my $dis = distance(uc $name, uc $git_name);

        if ($dis == 0 ){
            $username = $username_tmp;
            $distance = 0;
            last;
        }

        if (!defined $distance || $distance > $dis){
            $username = $username_tmp;
            $distance = $dis;
            $git_name_save = $git_name;
        }
    }

    #‹t‚à”äŠr
    if ( defined $distance && $distance != 0) {
        my $reverse_name = reverse_name($name);
        foreach my $result (@{$ref->{users}}){
            my $username_tmp = $result->{username};
            my $git_name = $result->{name};
            
            if (!defined $git_name) {
                next;
            }

            my $dis = distance( uc $reverse_name , uc $git_name);

            if ($dis == 0 ){
                $username = $username_tmp;
                $distance = 0;
                last;
            }

            if ($distance > $dis){
                $username = $username_tmp;
                $distance = $dis;
                $git_name_save = $git_name;
            }

        }
    }

    if (!defined  $distance || $distance != 0) {
        return ('','',0);
    }


    eval{
        my $response = $github->get('users/' . $username, {});
        $ref= $response->parse_response;
    };
    if ( $@ ) {
        eval{
            my $response = $github->get( 'users/' . $username, {});
            $ref= $response->parse_response;
        };
        if ( $@ ) {
            eval{
                my $response = $github->get( 'users/' . $username, {});
                $ref= $response->parse_response;
            };
            if ( $@ ) {
                return ('','',0);
            }
        }
    }

	if (!defined $ref->{public_gists}){
		return ($ref->{html_url}, $ref->{blog}, 0);
	}
	else{
        return ($ref->{html_url}, $ref->{blog}, $ref->{public_gists});
   }

}

sub reverse_name{
        my ($name) = @_;

        my @item = split(/ /, $name);

        return join (" ", reverse (@item));
}

1;
