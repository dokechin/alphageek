use strict;
use warnings;
use WWW::SlideShare;
use Data::Dumper;
use Storable;
use Cache::File;
use alphageek;

  if ($#ARGV <= 0) {
    print "スライドシェアのapiキーとsecretキーを指定してください。\n";
    exit(1);
  }
  
  my $api_key = $ARGV[0];
  my $secret = $ARGV[1];
  
  my $ss = WWW::SlideShare->new('api_key' => $api_key, 'secret' => $secret);

  my $hashref = {};
  my @usernames;
  my $page = 1;

 my $total = count_slideshows("Perl", $api_key, $secret);

 printf "total=%d\n", $total;

  while(1){
    eval{
      my $slideshows = $ss -> search_slideshows({ 'q' => "Perl", 'page' => $page, 'items_per_page' => 50});
    
      for my $slideshow(@$slideshows){

        for my $key( keys %$slideshow){
            my $username = $slideshow->{_data}->{Username};
            #末尾の空白文字を削除!(改行ふくむ）
            $username =~ s/\s*$//s;
            push @usernames, $username;
            printf "%s\n", $username;
        }
      }

#      if ($page == 3) {
#        last;
#      }

      printf "page=%d,download_count=%d\n", $page, $page * 50;

      if ($page * 50  > $total) {
        last;
      }

      $page++;
      if ($page % 50 == 0) {
        $ss = WWW::SlideShare->new('api_key' => $api_key, 'secret' => $secret);
      }


    };
    if ($@){
        last;
    }
  }
 
  foreach my $value ( @usernames ){
        $hashref->{$value} = 1;
  }

  my @uniq_usernames = keys %$hashref;

  printf "uniq_user_count=%d\n", $#uniq_usernames + 1;

  my $index = 0;
  my @coros;

  foreach my $uniq_user( @uniq_usernames) {
	  push @coros,async {
      my $name;
      $name = slideshare_name($uniq_user);
      printf "id=%s,name=%s\n", $uniq_user, $name;
	  $hashref ->{$uniq_user} = slideshare_name($uniq_user);
	  }
  }

  $_->join for @coros;

  store $hashref, 'slideshare_name.store';



 