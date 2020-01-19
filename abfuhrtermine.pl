#!/usr/bin/perl
#
# abfuhrtermin - fetch abfuhrtermine from GVU St. Pölten and provide as ics.
#
# initially
# by Klaus Maria Pfeiffer 2016-06 kmp@kmp.or.at
#


use strict;
use warnings;
#use feature "switch";
use utf8;

use HTML::TreeBuilder;
use POSIX qw(strftime);
#use DBI();
use Data::Dumper;
use Getopt::Long;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use Time::Local;
use Time::localtime;

# http://www.perlmonks.org/?node_id=1036317
#no warnings 'experimental::smartmatch';

binmode(STDOUT, ":utf8");

#my $DEBUG = 1;
my $DEBUG;


my ($opt_haushalt, $opt_gebiet);
my ($url, $paragraph, $abfuhrdate, $abfuhrtype, $abfuhrhaushalt, $abfuhrtimeend, $abfuhrdateend);
my ($tree, $p);
my %abfuhr;



GetOptions ('haushalt:s' => \$opt_haushalt, 'gebiet:i' => \$opt_gebiet);

print "$opt_haushalt $opt_gebiet\n" if $DEBUG;


my $timestamp = strftime("%Y%m%dT%H%M%SZ", gmtime);

#$url = "http://www.umweltverbaende.at/?gem_nr=31947&jahr=2017&kat=5039&portal=verband&vb=pl";
#$url = "http://stpoeltenland.abfallverband.at/?gem_nr=31947&jahr=2018&kat=5039&portal=verband&vb=pl";
#$url = "http://stpoeltenland.abfallverband.at/?gem_nr=31947&jahr=2019&portal=verband&vb=pl&kat=32";
$url = "http://stpoeltenland.abfallverband.at/?gem_nr=31947&jahr=2020&portal=verband&vb=pl&kat=32";

print "$url\n" if $DEBUG;

$tree = HTML::TreeBuilder->new_from_url($url);

print "$tree\n" if $DEBUG;
print Dumper($tree) if $DEBUG;

foreach my $p ($tree->look_down(_tag => "div", class => "tunterlegt"))
{
  print "$p\n" if $DEBUG;
  my $paragraph = $p->as_text;
  print "$paragraph\n" if $DEBUG;
  if ($paragraph =~ /(\d{2})\.(\d{2})\.(\d{4}).*? ([\w ]*?)\s*$/) {
    $abfuhrdate = "$3$2$1";
    $abfuhrtimeend = timelocal(0, 0, 0, $1, $2 - 1, $3) + 24 * 60 * 60;
    $abfuhrdateend = sprintf("%04d%02d%02d", localtime($abfuhrtimeend)->year() + 1900, localtime($abfuhrtimeend)->mon() + 1, localtime($abfuhrtimeend)->mday);
    $abfuhrtype = "$4";
    print "$abfuhrdate $abfuhrdateend $abfuhrtype" if $DEBUG;
    $abfuhr{"$abfuhrdate"}{"$abfuhrtype"}{"st"} = 1;
    $abfuhr{"$abfuhrdate"}{"$abfuhrtype"}{"end"} = $abfuhrdateend;
  }
  if ($paragraph =~ /Entsorgungsgebiet (\d)/) {
    print " $1" if $DEBUG;
    if (!defined($abfuhr{"$abfuhrdate"}{"$abfuhrtype"}{"eg"}) || ($abfuhr{"$abfuhrdate"}{"$abfuhrtype"}{"eg"} !~ m/$1/)) {
      $abfuhr{"$abfuhrdate"}{"$abfuhrtype"}{"eg"} .= "$1";
    }
  }
  if ($paragraph =~ /(Mehr|Ein)personenhaushalt/) {
    print " $1" if $DEBUG;
    $abfuhrhaushalt = lc substr $1, 0, 1;
    if (!defined($abfuhr{"$abfuhrdate"}{"$abfuhrtype"}{"ph"}) || ($abfuhr{"$abfuhrdate"}{"$abfuhrtype"}{"ph"} !~ m/$abfuhrhaushalt/)) {
      $abfuhr{"$abfuhrdate"}{"$abfuhrtype"}{"ph"} .= $abfuhrhaushalt;
    }
  }
  print "\n" if $DEBUG;

}

print Dumper(%abfuhr) if $DEBUG;



($abfuhrdate, $abfuhrtype) = undef;

print "BEGIN:VCALENDAR\r\n";
print "VERSION:2.0\r\n";
print "PRODID:-//kmp.or.at//NONSGML abfuhrtermine v0.1//EN\r\n";

#while ( my ($abfuhrdate, $hashabfuhrtype) = each(%abfuhr) ) {
foreach my $abfuhrdate (sort keys %abfuhr) {
  my $hashabfuhrtype = $abfuhr{$abfuhrdate};
  while ( my ($abfuhrtype, $hashabfuhr) = each(%$hashabfuhrtype) ) {
    if (((!defined($hashabfuhr->{'eg'})) || (!defined($opt_gebiet)) || ($hashabfuhr->{'eg'} =~ $opt_gebiet)) && ((!defined($hashabfuhr->{'ph'})) || (!defined($opt_haushalt)) || ($hashabfuhr->{'ph'} =~ $opt_haushalt))) {

      print "BEGIN:VEVENT\r\n";
      print "UID:" . md5_hex($abfuhrdate . $abfuhrtype) . "\@abfuhrtermine.kmp.or.at\r\n";
      print "DTSTAMP:$timestamp\r\n";
      #print "$abfuhrdate $abfuhrtype";
      print "DTSTART;VALUE=DATE:$abfuhrdate\r\n";
      print "DTEND;VALUE=DATE:$hashabfuhr->{'end'}\r\n";
      print "SUMMARY:$abfuhrtype";
      if (defined($hashabfuhr->{'eg'}) && !defined($opt_gebiet)) {
        $hashabfuhr->{'eg'} = join '',sort split('',$hashabfuhr->{'eg'});
        if ($hashabfuhr->{'eg'} ne "12") {
          print " $hashabfuhr->{'eg'}";
        }
      }
      if (defined($hashabfuhr->{'ph'}) && !defined($opt_haushalt)) {
        $hashabfuhr->{'ph'} = join '',sort split('',$hashabfuhr->{'ph'});
        if ($hashabfuhr->{'ph'} ne "em") {
          print " $hashabfuhr->{'ph'}";
        }
      }
      print "\r\n";
      print "STATUS:CONFIRMED\r\n";
      print "END:VEVENT\r\n";

    }
  }
}

print "END:VCALENDAR\r\n";

