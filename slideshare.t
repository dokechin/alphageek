use strict;
use warnings;
use Test::More;
use alphageek;

my $name = slideshare_name("istofautomob2");
my $count = slideshare_count("istofautomob2");

#my $name = slideshare_name("yusukebe");
#my $count = slideshare_count("yusukebe");

printf "name=%s\n", $name;
printf "count=%d\n", $count;

#my $slidecount = count_slideshows("Perl");
#printf "slidecount=%d\n", $slidecount;


