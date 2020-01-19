#!/usr/bin/perl
#
# abfuhrtermine-gvu-stp - fetch abfuhrtermine from GVU St. Pölten and provide as iCalendar.
#
# Klaus Maria Pfeiffer 2016 - 2020
# https://github.com/hoedlmoser/abfuhrtemine-gvu-stp
#

use strict;
use warnings;
use utf8;
binmode(STDOUT, ":utf8");

use HTML::TreeBuilder;
use POSIX qw(strftime);
use Data::Dumper;
use Getopt::Long;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use Time::Local;
use Time::localtime;


my $opt_jahr = strftime("%Y", gmtime);
my ($opt_gemeinde, $opt_gemid, $opt_verbandid, $opt_haushalt, $opt_gebiet, $opt_liste, $opt_raw, $opt_debug);
GetOptions ('haushalt:s' => \$opt_haushalt, 
            'gebiet:i' => \$opt_gebiet,
            'gemeinde:s' => \$opt_gemeinde,
            'gemeindeid:i' => \$opt_gemid,
            'verbandid:s' => \$opt_verbandid,
            'jahr:i' => \$opt_jahr,
            'liste' => \$opt_liste,
            'raw' => \$opt_raw,
            'debug' => \$opt_debug,
);
print "$opt_jahr $opt_gemid $opt_gemeinde $opt_gebiet $opt_haushalt\n" if $opt_debug;


my %umlaute = ("ä" => "ae", "Ä" => "Ae", "ü" => "ue", "Ü" => "Ue", "ö" => "oe", "Ö" => "Oe", "ß" => "ss" );
my $umlautkeys = join ("|", keys(%umlaute));


my %verbaende = (
  'St. Pölten Bezirk' => 'pl',
  'Tulln' => 'tu',
);
my %verbandHost = (
  'pl' => 'stpoeltenland',
  'tu' => 'tulln',
);



for my $verbandLong ( sort keys %verbaende ) {
  my $verbandShort = $verbaende{$verbandLong};
  print "$verbandLong, $verbandShort\n" if $opt_debug;
  if ((defined($opt_verbandid) && lc $opt_verbandid eq $verbandShort) || !defined($opt_verbandid)) {
    print "$verbandLong, \U$verbandShort\n" if $opt_liste;
    getGemeinde($verbandShort);
  }
}



sub getGemeinde {
  my ($vbid) = @_;

  my $url = "http://$verbandHost{$vbid}.umweltverbaende.at/?portal=verband&vb=$vbid&kat=32";
  print "$url\n" if $opt_debug;

  my $tree = HTML::TreeBuilder->new_from_url($url);

  foreach my $p ($tree->look_down(_tag => "option"))
  {
    my $gemeinde = $p->as_text;
    my $gemid = $p->attr('value');

    next if $gemeinde =~ /alle Gemeinden/;
    print "$gemeinde $gemid\n" if $opt_debug;
    $gemeinde =~ s/($umlautkeys)/$umlaute{$1}/g;  
    print "$gemeinde $gemid\n" if $opt_debug;

    if (defined($opt_liste)) {
      print "  $gemeinde, $gemid\n";
    } elsif ((defined($opt_gemid) && $opt_gemid == $gemid) || (defined($opt_gemeinde) && $opt_gemeinde eq $gemeinde) || (!defined($opt_gemid) && !defined($opt_gemeinde))) {
      printiCal($vbid, $gemid, $gemeinde, $opt_jahr);
    }
  }
  $tree->delete;
}



sub printiCal {
  my ($vbid, $gemid, $gemeinde, $jahr) = @_;
  
  print "$gemeinde";

  $gemeinde =~ tr/ \./-/d;  
  my $iCalFile = "abfuhrtermine_${gemeinde}_${gemid}_${jahr}";
  print "$iCalFile\n" if $opt_debug;

  my $timestamp = strftime("%Y%m%dT%H%M%SZ", gmtime);

  my $url = "http://$verbandHost{$vbid}.umweltverbaende.at/?gem_nr=$gemid&jahr=$jahr&portal=verband&vb=$vbid&kat=32";
  print "$url\n" if $opt_debug;

  my $tree = HTML::TreeBuilder->new_from_url($url);

  my %abfuhr;

  open(my $fhRaw, '>:encoding(UTF-8)', $iCalFile . '.out') if $opt_raw or die "could not open file '$iCalFile.out' $!";

  foreach my $p ($tree->look_down(_tag => "div", class => "tunterlegt"))
  {
    my ($abfuhrdate, $abfuhrtype);
    my $abfuhrinfo = $p->as_text;
    print "$abfuhrinfo\n" if $opt_debug;
    print $fhRaw "$abfuhrinfo\n" if $opt_raw;
    next if $abfuhrinfo =~ m/Wohnhausanlagen/;
    if ($abfuhrinfo =~ /(\d{2})\.(\d{2})\.(\d{4}).*? ([\w ]*?)\s*$/) {
      $abfuhrdate = "$3$2$1";
      my $abfuhrtimeend = timelocal(0, 0, 0, $1, $2 - 1, $3) + 24 * 60 * 60;
      my $abfuhrdateend = sprintf("%04d%02d%02d", localtime($abfuhrtimeend)->year() + 1900, localtime($abfuhrtimeend)->mon() + 1, localtime($abfuhrtimeend)->mday);
      $abfuhrtype = "$4";
      print "   -> $abfuhrdate $abfuhrdateend $abfuhrtype " if $opt_debug;
      $abfuhr{"$abfuhrdate"}{"$abfuhrtype"}{"st"} = 1;
      $abfuhr{"$abfuhrdate"}{"$abfuhrtype"}{"end"} = $abfuhrdateend;
    }
    if ($abfuhrinfo =~ /(Entsorgungsgebiet|Haushalte) (\d)/) {
      print "$2" if $opt_debug;
      if (!defined($abfuhr{"$abfuhrdate"}{"$abfuhrtype"}{"eg"}) || ($abfuhr{"$abfuhrdate"}{"$abfuhrtype"}{"eg"} !~ m/$2/)) {
        $abfuhr{"$abfuhrdate"}{"$abfuhrtype"}{"eg"} .= "$2";
      }
    }
    if ($abfuhrinfo =~ /(Mehr|Ein)personenhaushalt/) {
      print "$1" if $opt_debug;
      my $abfuhrhaushalt = lc substr $1, 0, 1;
      if (!defined($abfuhr{"$abfuhrdate"}{"$abfuhrtype"}{"ph"}) || ($abfuhr{"$abfuhrdate"}{"$abfuhrtype"}{"ph"} !~ m/$abfuhrhaushalt/)) {
        $abfuhr{"$abfuhrdate"}{"$abfuhrtype"}{"ph"} .= $abfuhrhaushalt;
      }
    }
    print "\n" if $opt_debug;
  }

  close $fhRaw if $opt_raw;

  $tree->delete;

  print " -> $iCalFile.ics\n";

  open(my $fh, '>:encoding(UTF-8)', $iCalFile . '.ics') or die "could not open file '$iCalFile.ics' $!";
    
  print $fh "BEGIN:VCALENDAR\r\n";
  print $fh "VERSION:2.0\r\n";
  print $fh "PRODID:-//kmp.or.at//NONSGML abfuhrtermine v0.1//EN\r\n";

  foreach my $abfuhrdate (sort keys %abfuhr) {
    my $hashabfuhrtype = $abfuhr{$abfuhrdate};
    while ( my ($abfuhrtype, $hashabfuhr) = each(%$hashabfuhrtype) ) {
      if (((!defined($hashabfuhr->{'eg'})) || (!defined($opt_gebiet)) || ($hashabfuhr->{'eg'} =~ $opt_gebiet)) && ((!defined($hashabfuhr->{'ph'})) || (!defined($opt_haushalt)) || ($hashabfuhr->{'ph'} =~ $opt_haushalt))) {
        print $fh "BEGIN:VEVENT\r\n";
        print $fh "UID:" . md5_hex($gemid . $abfuhrdate . $abfuhrtype) . "\@abfuhrtermine.kmp.or.at\r\n";
        print $fh "DTSTAMP:$timestamp\r\n";
        print $fh "DTSTART;VALUE=DATE:$abfuhrdate\r\n";
        print $fh "DTEND;VALUE=DATE:$hashabfuhr->{'end'}\r\n";
        print $fh "SUMMARY:$abfuhrtype";
        if (defined($hashabfuhr->{'eg'}) && !defined($opt_gebiet)) {
          $hashabfuhr->{'eg'} = join '',sort split('',$hashabfuhr->{'eg'});
          if ($hashabfuhr->{'eg'} ne "12") {
            print $fh " $hashabfuhr->{'eg'}";
          }
        }
        if (defined($hashabfuhr->{'ph'}) && !defined($opt_haushalt)) {
          $hashabfuhr->{'ph'} = join '',sort split('',$hashabfuhr->{'ph'});
          if ($hashabfuhr->{'ph'} ne "em") {
            print $fh " $hashabfuhr->{'ph'}";
          }
        }
        print $fh "\r\n";
        print $fh "STATUS:CONFIRMED\r\n";
        print $fh "END:VEVENT\r\n";
      }
    }
  }
  print $fh "END:VCALENDAR\r\n";

  close $fh;
}

