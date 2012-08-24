use strict;
use warnings;
use Test::More;
use alphageek;

my @persons = (
  {id => "Anta", name => "Hoge hoge", distributions_count => 100,
   homepage_url => "http://yahoo.co.jp", homepage_title => "yahoo yapan",
   github_url => "http://hoge.co.jp", public_gists => 100,
   blog_url => "jp", blog_title => "Neko's blog",
   category => "Japanese", blog_url => "http://", hatena_url => "http://hatena.co.jp", hatena_count => 50,
   total => 200},
  {id => "Beck", name => "Hoge hoge", distributions_count => 60,
   homepage_url => "http://yahoo.co.jp", homepage_title => "yahoo yapan",
   github_url => "http://hoge.co.jp", public_gists => 80,
   blog_url => "jp", blog_title => "Wan blog",
   category => "Japanese", blog_url => "http://", hatena_url => "http://hatena.co.jp", hatena_count => 50,
   total => 140},
  {id => "Sick", name => "Hoge hoge", distributions_count => 80,
   homepage_url => "http://yahoo.co.jp", homepage_title => "yahoo yapan",
   github_url => "http://hoge.co.jp", public_gists => 50,
   blog_url => "jp", blog_title => "Block blog",
   category => "Japanese", blog_url => "http://", hatena_url => "http://hatena.co.jp", hatena_count => 50,
   total => 130},
   );

save_html(\@persons, "British", "./release/test.html");

my @categoryinfos = (
  {category => "Japanese", country => "jp", count => 100},
  {category => "Japanese", country => "jp", count => 100},
  {category => "Japanese", country => "jp", count => 100},
  {category => "Japanese", country => "jp", count => 100},
  {category => "Japanese", country => "jp", count => 100},
  {category => "Japanese", country => "jp", count => 100},
  {category => "Japanese", country => "jp", count => 100},
  {category => "Japanese", country => "jp", count => 100},
  {category => "Japanese", country => "jp", count => 100},
  {category => "Japanese", country => "jp", count => 100},
  {category => "Japanese", country => "jp", count => 100},
  {category => "Japanese", country => "jp", count => 100},
  {category => "Japanese", country => "jp", count => 100},
  {category => "Japanese", country => "jp", count => 100},
  {category => "Japanese", country => "jp", count => 100},
  {category => "Japanese", country => "jp", count => 100},
  {category => "Japanese", country => "jp", count => 100},
  {category => "Japanese", country => "jp", count => 100},
  {category => "Japanese", country => "jp", count => 100},
  {category => "Japanese", country => "jp", count => 100},
  {category => "Japanese", country => "jp", count => 100},
  {category => "Japanese", country => "jp", count => 100},
  {category => "Japanese", country => "jp", count => 100},
  {category => "Japanese", country => "jp", count => 100},
  {category => "Japanese", country => "jp", count => 100},
  {category => "Japanese", country => "jp", count => 100},
  {category => "Japanese", country => "jp", count => 100},
  {category => "Japanese", country => "jp", count => 100},
  {category => "Spanish",  country => "es", count => 200});

save_top_html(\@categoryinfos, "./release/test_top.html");

done_testing();

