#!/usr/bin/perl -w

use strict;
use warnings;
use experimental 'smartmatch';

#copyright by yongzhong liang
#any problem, please give feedback to yong.zhong.liang@ericsson.com

my $dn_h={};

sub init1($$$$$)
{
  my ($i,$err,$re,$list,$lines)=($_[0],$_[1],$_[2],$_[3],$_[4]);
  while (my $line1 = shift @$lines) {
     $i++;
     if($line1 =~ /$re/) {
         my $tmp = $1;
         $tmp =~ s/\s+//g;
         push(@$list,lc($tmp)); 
         next;
     } 
     last if ($line1 =~ /\s*\}\s*/);
     next if ($line1 =~ /^\s*#/ || $line1 =~ /^\s*$/); 
     print "line $i error!\n";
     $err++;
   }
   return ($i,$err);
}

sub  init()
{
   my  @eps_apn;
   my  @gprs_apn;
   my  @eps_tac;
   my  @gprs_lac_rac;
   my  @dns_servers;
   my  @eps_mmegi_mmec;
   my  @amf_region_set_pt;

   return  if(!open(FD, "./dns.dat"));
   my @lines = <FD>;
   close(FD);
   my $i=0;
   my $err=0;
   while (my $line = shift @lines) {
      $i++;
      next if ($line =~ /^\s*#/ || $line =~ /^\s*$/); 
      if($line =~ /^\s*DNS_SERVERS\s*=\s*\{\s*/) { 
        $dn_h->{DNS_SERVERS}=\@dns_servers;
        ($i,$err) = init1($i,$err,'^\s*([A-Za-z]+\w*\s*\:\s*\d+(\.\d+){3})\s*$',\@dns_servers,\@lines);
        next;
      } 

      if ( $line =~ /^\s*EPS_APN\s*=\s*\{\s*$/) { 
        $dn_h->{EPS_APN}=\@eps_apn;
        ($i,$err) = init1($i,$err,'^\s*([A-Za-z]+\w*(.[A-Za-z]+\w*)*)\s*$',\@eps_apn,\@lines);
        next;
      } 
  
      if ( $line =~ /^\s*GPRS_APN\s*=\s*\{\s*$/) { 
        $dn_h->{GPRS_APN}=\@gprs_apn;
        ($i,$err) = init1($i,$err,'^\s*([A-Za-z]+\w*(.[A-Za-z]+\w*)*)\s*$',\@gprs_apn,\@lines);
        next;
      }

      if ($line =~ /^\s*EPS_TAC\s*=\s*\{\s*$/) { 
        $dn_h->{EPS_TAC}=\@eps_tac;
        ($i,$err) = init1($i,$err,'^\s*(\d+)s*$',\@eps_tac,\@lines);
        next;
      } 

      if ($line =~ /^\s*GPRS_LAC_RAC\s*=\s*\{\s*$/) { 
        $dn_h->{GPRS_LAC_RAC}=\@gprs_lac_rac;
        ($i,$err) = init1($i,$err,'^\s*(\d+\-\d+)s*$',\@gprs_lac_rac,\@lines);
        next;
      } 

      if ($line =~ /^\s*EPS_MMEGI_MMEC\s*=\s*\{\s*$/) { 
        $dn_h->{EPS_MMEGI_MMEC}=\@eps_mmegi_mmec;
        ($i,$err) = init1($i,$err,'^\s*(\d+\-\d+)s*$',\@eps_mmegi_mmec,\@lines);
        next;
      } 

      if ($line =~ /^\s*5GS_AMF_REGION_SET_PT\s*=\s*\{\s*$/) { 
        $dn_h->{AMF_REGION_SET_PT}=\@amf_region_set_pt;
        ($i,$err) = init1($i,$err,'^\s*(\d+\-\d+-\d+)s*$',\@amf_region_set_pt,\@lines);
        next;
      } 

      print "line $i error!\n";
      $err++;
      next;
   }

   die "Please correct the error!\n" if($err == 1);
   die "Please correct the errors!\n" if($err > 1);
}


sub  get_tac_hb_lb($)
{
   my $t = sprintf("%04x", $_[0]);
   my ($hb,$lb) = (substr($t,0,2),substr($t,2,2));
   return ("tac-lb${lb}.tac-hb${hb}");
}

sub  get_lac_rac_hex($)
{
   my ($lac,$rac) = split(/\-/,$_[0]); 
   $lac = sprintf("%04x",$lac);
   $rac = sprintf("%04x",$rac);
   return ("rac${rac}.lac${lac}");
}

sub  get_gprs_apn_list()
{
   my @apn = qw(cmnet cmwap);
   return (\@apn) if(!exists($dn_h->{GPRS_APN}));
   return ($dn_h->{GPRS_APN});
}

sub  get_eps_apn_list()
{
   my @apn = qw (cmnet cmwap ims);
   return (\@apn) if(!exists($dn_h->{EPS_APN}));
   return ($dn_h->{EPS_APN});
}

sub  get_tac_list()
{
   return ($dn_h->{EPS_TAC}) if (exists($dn_h->{EPS_TAC}));
   my @t = qx(/usr/bin/gsh show_mme_tracking_area );
   my $tac_l = [];
   foreach (@t) {
      push (@$tac_l,$1) if (/460\-00\-(\d+)/);
   }
   return ($tac_l);
} 

sub  get_lac_rac_list()
{
   return ($dn_h->{GPRS_LAC_RAC}) if(exists($dn_h->{GPRS_LAC_RAC}));
   my @t = qx(/usr/bin/gsh list_ra all | grep gsm | grep -v grep);
   my $lac_rac_l = [];
   foreach my $t (@t) {
      my @t1 = split(/\s+/,$t);
      push (@$lac_rac_l,"$t1[7]\-$t1[9]") if($t1[14] =~ /true/);
   }
   return ($lac_rac_l);
} 

sub  get_mmegi_mmec_list()
{
   return ($dn_h->{EPS_MMEGI_MMEC}) if (exists($dn_h->{EPS_MMEGI_MMEC}));
   my $tmp  = [];
   my @t = qx(/usr/bin/gsh get_ne | egrep -e "mgi|^mc" | grep -v grep);
   my $tmp1 = shift @t;
   $tmp1 =~ /(\d+)/;
   $tmp1 = $1;
   my $tmp2 = shift @t;
   $tmp2 =~ /(\d+)/;
   $tmp2 = $1;
   push (@$tmp,"${tmp1}\-$tmp2") if($tmp1 && $tmp2);
   return ($tmp);
} 

sub  get_mmegi_mmec_hex($)
{
   my ($mmegi,$mmec) = split(/\-/,$_[0]);
   $mmegi = sprintf("%04x",$mmegi);
   $mmec = sprintf("%02x",$mmec);
   return ("mmec${mmec}.mmegi${mmegi}");
}

sub  get_amf_region_set_pt_list()
{
   return ($dn_h->{AMF_REGION_SET_PT}) if (exists($dn_h->{AMF_REGION_SET_PT}));
   return (my $tmp = []);
} 

sub  get_amf_region_set_pt_hex($)
{
   my ($region,$set,$pt) = split(/\-/,$_[0]);
   $region = sprintf("%02x",$region);
   $set = sprintf("%03x",$set);
   $pt = sprintf("%02x",$pt);
   return ("pt${pt}.set${set}.region${region}");
}

sub  get_mmegi_mmec_from_amfi($)
{
   my ($region,$set,$pt) = split(/\-/,$_[0]);
   my $tmp = (($set << 6)&0xffc0) + $pt;
   my $mmegi = (($region<<8)&0xff00) + (($tmp>>8)&0x00ff);
   my $mmec = $tmp&0x00ff;
   return ("$mmegi\-$mmec");
}

sub  get_dns_client()
{
   my $t = qx(/usr/bin/gsh list_ip_service_address | grep DNS | grep -v grep );
   $t =~ /(\d+(\.\d+){3})/;
   die "Can't find any DNS client\n" if (!$1);
   return ($1);
}

sub  get_dns_servers()
{
   my $dns_h = {};
   if(exists($dn_h->{DNS_SERVERS})) {
      my $tmp = $dn_h->{DNS_SERVERS};
      foreach (@$tmp) {
         my ($s,$ip) = split(/\:/);
	 $dns_h->{$s} = $ip;
      }
      return ($dns_h);
   }
   my @t = qx(/usr/bin/gsh list_dns_server_address | grep mnc|grep mcc | grep -v grep);
   foreach my $t (@t) {
      my @l = split(/\s+/, $t);
      my @tmp = split(/\./, $l[5]);
      $dns_h->{lc($tmp[0])} = $l[7];
   }
   my @t1 = keys %$dns_h;
   die "Can't find any DNS server\n" if (!@t1);
   return ($dns_h);
}


sub  exec_dig($$$$)
{
   my ($d,$c,$s,$f)=($_[0],$_[1],$_[2],$_[3]);
   print $f "dig \@$s -b $c $d any\n";
   my @t = qx(/usr/bin/dig \@$s -b $c $d any);
   return (\@t);
} 

sub  exec_dig1($$$)
{
   my ($d,$c,$s)=($_[0],$_[1],$_[2]);
   my @t = qx(/usr/bin/dig \@$s -b $c $d any | grep -v dns | grep -v SOA | grep -v NS | grep -v grep );
   my @t1;
   foreach (@t) {
      s/\s+/\ /g;
      push (@t1,"${_}\n");
   }
   @t = grep (/ IN /, @t1);
   @t1 = sort(@t);
   return (\@t1);
}

sub  dig_apn($$$)
{
  my ($s,$i,$f) = ($_[0],$_[1],$_[2]);
  my $apn_l = get_eps_apn_list();
  my $c = get_dns_client();
  my $d = "epc.mnc000.mcc460.3gppnetwork.org.";

  foreach my $apn (@$apn_l) {
     print "  digging EPS APN $apn to the DNS server $s...\n";
     print $f "EPS APN $apn dig results from the DNS server $s:\n";
     print $f "---------------------------------------------------------------------------------------------------\n";
     my $t = exec_dig("${apn}.apn.$d", $c, $i,$f); 
     print $f ($_) foreach (@$t);
     print $f "EPS APN $apn dig end.\n\n"
  }
  $apn_l = get_gprs_apn_list();
  $d = "mnc000.mcc460.gprs.";
  foreach my $apn (@$apn_l) {
     print "  digging GPRS APN $apn to the DNS server $s...\n";
     print  $f "GPRS APN $apn dig results from the DNS server $s:\n";
     print $f "---------------------------------------------------------------------------------------------------\n";
     my $t = exec_dig("${apn}.$d", $c, $i,$f); 
     print $f ($_) foreach (@$t);
     print $f "GPRS APN $apn dig end.\n\n"
  }
}

sub  dig_tai($$$)
{
  my ($s,$i,$f) = ($_[0],$_[1],$_[2]);
  my $tac_l = get_tac_list();
  my $c = get_dns_client();
  my $d = "epc.mnc000.mcc460.3gppnetwork.org.";

  foreach my $tac (@$tac_l) {
     print "  digging TAC $tac to the DNS server $s...\n";
     print $f "TAC $tac dig results from the DNS server $s:\n";
     my $tmp = get_tac_hb_lb($tac);
     my $d = "${tmp}.tac.$d";
     print $f "---------------------------------------------------------------------------------------------------\n";
     my $t = exec_dig($d,$c,$i,$f);
     print $f ($_) foreach (@$t);
     print $f "TAC $tac dig end.\n\n"
  }
}

sub  dig_rai($$$)
{
  my ($s,$i,$f) = ($_[0],$_[1],$_[2]);
  my $lac_rac_l = get_lac_rac_list();
  my $c = get_dns_client();
  my $d = "mnc0000.mcc0460.gprs.";
  foreach my $lac_rac (@$lac_rac_l) {
     print "  digging GPRS LAC-RAC $lac_rac to the DNS server $s...\n";
     print $f "GPRS LAC\-RAC $lac_rac dig results from the DNS server $s:\n";
     my $tmp = get_lac_rac_hex($lac_rac);
     print $f "---------------------------------------------------------------------------------------------------\n";
     my $t = exec_dig("$tmp.$d",$c,$i,$f);
     print $f ($_) foreach (@$t);
     print $f "GPRS LAC-RAC $lac_rac dig end.\n\n"
  }

  $d = "epc.mnc000.mcc460.3gppnetwork.org.";
  foreach my $lac_rac (@$lac_rac_l) {
     print "  digging EPS LAC-RAC $lac_rac to the DNS server $s...\n";
     print $f "EPS LAC\-RAC $lac_rac dig results from the DNS server $s:\n";
     my $tmp = get_lac_rac_hex($lac_rac);
     print $f "---------------------------------------------------------------------------------------------------\n";
     my $t = exec_dig("$tmp.rac.$d",$c,$i,$f);
     print $f ($_) foreach (@$t);
     print $f "EPS LAC-RAC $lac_rac dig end.\n\n"
  }
}

sub  dig_mmegi_mmec($$$)
{
  my ($s,$i,$f) = ($_[0],$_[1],$_[2]);
  my $mmegi_mmec_l = get_mmegi_mmec_list();
  my $c = get_dns_client();
  my $d = "epc.mnc000.mcc460.3gppnetwork.org.";

  foreach my $mmegi_mmec (@$mmegi_mmec_l) {
     print "  digging MME $mmegi_mmec to the DNS server $s...\n";
     print $f "MMEGI-MMEC $mmegi_mmec dig results from the DNS server $s:\n";
     my $tmp = get_mmegi_mmec_hex($mmegi_mmec);
     $d = "$tmp.mme.$d";
     print $f "---------------------------------------------------------------------------------------------------\n";
     my $t = exec_dig($d,$c,$i,$f);
     print $f ($_) foreach (@$t);
     print $f "MMEGI-MMEC $mmegi_mmec dig end.\n\n"
  }
}


sub  dig_amf_region_set_pt($$$)
{
  my ($s,$i,$f) = ($_[0],$_[1],$_[2]);
  my $region_set_pt_l = get_amf_region_set_pt_list();
  my $c = get_dns_client();
  my $d1 = "5gc.mnc000.mcc460.3gppnetwork.org.";
  my $d2 = "epc.mnc000.mcc460.3gppnetwork.org.";

  foreach my $amfi (@$region_set_pt_l) {
     print "  digging AMFI $amfi to the DNS server $s...\n";
     print $f "AMFI $amfi dig results from the DNS server $s:\n";
     my $tmp = get_amf_region_set_pt_hex($amfi);
     my $d = "${tmp}.amfi.$d1";
     print $f "---------------------------------------------------------------------------------------------------\n";
     my $t = exec_dig($d,$c,$i,$f);
     print $f ($_) foreach (@$t);
     print $f "AMFI $amfi dig end.\n\n";

     my $mmegi_mmec = get_mmegi_mmec_from_amfi($amfi);
     print "  digging MME $mmegi_mmec(amfi:$amfi) to the DNS server $s...\n";
     print $f "MME $mmegi_mmec(amfi:$amfi) dig results from the DNS server $s:\n";
     $tmp = get_mmegi_mmec_hex($mmegi_mmec);
     $d = "${tmp}.mme.$d2";
     print $f "---------------------------------------------------------------------------------------------------\n";
     $t = exec_dig($d,$c,$i,$f);
     print $f ($_) foreach (@$t);
     print $f "MME $mmegi_mmec(amfi:$amfi) dig end.\n\n"
  }
}

sub  test_dns()
{
   my $f;
   my @f;
   my $s = get_dns_servers();
   die "No DNS server found !\n" if(!(keys %$s));
   foreach  (keys %$s) {
     my $s1 =  "${_}\($s->{$_}\)";
     print "Start testing DNS server $s1......\n";
     $f = "./${_}.txt";
     push (@f,$f);
     die "Can't create the file $f\n" if(!open(FD,">$f"));
     dig_apn($_,$s->{$_},\*FD);
     dig_tai($_,$s->{$_},\*FD);
     dig_rai($_,$s->{$_},\*FD);
     dig_mmegi_mmec($_,$s->{$_},\*FD);
     dig_amf_region_set_pt($_,$s->{$_},\*FD);
     close(FD);
     print "Stop testing DNS server $s1.\n";
     print "--------------------------------------------------------------------------\n";
   }
   my $t = join(' ',@f);
   print "DNS testing over!\n\n";
   print "Please check the file $t for detailed testing results!\n\n"; 
}

sub  cmp_dns1($$)
{
  my $apn1 = get_eps_apn_list();
  my @apn = @$apn1;
  my $c = get_dns_client();
  my $d1 = "epc.mnc000.mcc460.3gppnetwork.org.";
  my $d2 = "mnc000.mcc460.gprs.";
  my $d3 = "mnc0000.mcc0460.gprs.";
  my $d4 = "5gc.mnc000.mcc460.3gppnetwork.org";

  my ($s1,$s2) = ($_[0],$_[1]);
  foreach my $apn (@apn) {
     my $t1 = exec_dig1("${apn}.apn.$d1",$c,$s1);     
     my $t2 = exec_dig1("${apn}.apn.$d1",$c,$s2);     
     if (@$t1 ~~ @$t2) {
        print "  EPS APN $apn dig matched\n";
     } else {
        print "  EPS APN $apn dig unmatched\n";
        print "$s1:\n-----------------------------------------------------------------------------------\n";
        print "@$t1\n"; 
        print "$s2:\n-----------------------------------------------------------------------------------\n";
        print "@$t2\n";
     }
  }

  $apn1 = get_gprs_apn_list();
  @apn = @$apn1;
  foreach my $apn (@apn) {
     my $t1 = exec_dig1("${apn}.$d2",$c,$s1);     
     my $t2 = exec_dig1("${apn}.$d2",$c,$s2);     
     if (@$t1 ~~ @$t2) {
        print "  GPRS APN $apn dig matched\n";
     } else {
        print "  GPRS APN $apn dig unmatched\n";
        print "$s1:\n-----------------------------------------------------------------------------------\n";
        print "@$t1\n"; 
        print "$s2:\n-----------------------------------------------------------------------------------\n";
        print "@$t2\n";
     }
  }

  my $tac_l = get_tac_list();
  foreach my $tac (@$tac_l) {
     my $tmp = get_tac_hb_lb($tac);
     my $d = "$tmp.tac.$d1";
     my $t1 = exec_dig1($d,$c,$s1);     
     my $t2 = exec_dig1($d,$c,$s2);     
     if (@$t1 ~~ @$t2) {
        print "  TAC $tac dig matched.\n";
     } else {
        print "  TAC $tac dig unmatched.\n";
        print "$s1:\n-----------------------------------------------------------------------------------\n";
        print "@$t1\n"; 
        print "$s2:\n----------------------------------------------------------------------------------\n";
        print "@$t2\n";
     }
  }

  my $lac_rac_l = get_lac_rac_list();
  foreach my $lac_rac (@$lac_rac_l) {
     my $tmp = get_lac_rac_hex($lac_rac);
     my $d = "$tmp.$d3";
     my $t1 = exec_dig1($d,$c,$s1);     
     my $t2 = exec_dig1($d,$c,$s2);     
     if (@$t1 ~~ @$t2) {
        print "  GPRS LAC-RAC $lac_rac dig matched.\n";
     } else {
        print "  GPRS LAC-RAC $lac_rac dig unmatched.\n";
        print "$s1:\n-----------------------------------------------------------------------------------\n";
        print "@$t1\n"; 
        print "$s2:\n----------------------------------------------------------------------------------\n";
        print "@$t2\n";
     }
  }

  foreach my $lac_rac (@$lac_rac_l) {
     my $tmp = get_lac_rac_hex($lac_rac);
     my $d = "$tmp.$d1";
     my $t1 = exec_dig1($d,$c,$s1);     
     my $t2 = exec_dig1($d,$c,$s2);     
     if (@$t1 ~~ @$t2) {
        print "  EPS LAC-RAC $lac_rac dig matched.\n";
     } else {
        print "  EPS LAC-RAC $lac_rac dig unmatched.\n";
        print "$s1:\n-----------------------------------------------------------------------------------\n";
        print "@$t1\n"; 
        print "$s2:\n----------------------------------------------------------------------------------\n";
        print "@$t2\n";
     }
  }

  my $mmegi_mmec_l = get_mmegi_mmec_list();
  foreach my $mmegi_mmec (@$mmegi_mmec_l) {
     my $mme1 = get_mmegi_mmec_hex($mmegi_mmec);
     my $d = "${mme1}.mme.$d1";
     my $t1 = exec_dig1($d,$c,$s1);
     my $t2 = exec_dig1($d,$c,$s2);
     if (@$t1 ~~ @$t2) {
        print "  EPS MMEGI-MMEC $mmegi_mmec dig matched.\n";
     } else {
        print "  EPS MMEGI-MMEC $mmegi_mmec dig unmatched.\n";
        print "$s1:\n-----------------------------------------------------------------------------------\n";
        print "@$t1\n"; 
        print "$s2:\n----------------------------------------------------------------------------------\n";
        print "@$t2\n";
     }
  }

  my $amfi_l = get_amf_region_set_pt_list();
  foreach my $amfi (@$amfi_l) {
     my $amfi1 = get_amf_region_set_pt_hex($amfi);
     my $d = "${amfi1}.amfi.$d4";
     my $t1 = exec_dig1($d,$c,$s1);
     my $t2 = exec_dig1($d,$c,$s2);
     if (@$t1 ~~ @$t2) {
        print "  AMF REGION-SET-PT $amfi dig matched.\n";
     } else {
        print "  AMF REGION-SET-PT $amfi dig unmatched.\n";
        print "$s1:\n-----------------------------------------------------------------------------------\n";
        print "@$t1\n"; 
        print "$s2:\n----------------------------------------------------------------------------------\n";
        print "@$t2\n";
     }
     my $mmegi_mmec = get_mmegi_mmec_from_amfi($amfi);
     my $tmp = get_mmegi_mmec_hex($mmegi_mmec);
     $d = "$mmegi_mmec.mme.$d1";
     $t1 = exec_dig1($d,$c,$s1);
     $t2 = exec_dig1($d,$c,$s2);
     if (@$t1 ~~ @$t2) {
        print "  AMF(Eric) MMEGI-MMEC $mmegi_mmec(amfi:$amfi) dig matched.\n";
     } else {
        print "  AMF(Eric) MMEGI-MMEC $mmegi_mmec(amfi:$amfi) dig unmatched.\n";
        print "$s1:\n-----------------------------------------------------------------------------------\n";
        print "@$t1\n"; 
        print "$s2:\n----------------------------------------------------------------------------------\n";
        print "@$t2\n";
     }
  }
}

sub  cmp_dns()
{
    my $s = get_dns_servers();
    my @k = keys %$s;
    die "Number of DNS servers less than 2 !\n" if(@k < 2);
    my $k = shift (@k);
    foreach (@k) {
      print "Start dig comparing between DNS server $k and $_...\n"; 
      cmp_dns1($s->{$k}, $s->{$_});
      print "End dig comparing.\n";
    }
}

sub  list_dns_servers()
{
    my $s = get_dns_servers();
    my @k = keys %$s;
    die "No DNS server found !\n" if(!@k);
    print "The DNS server list is as following:\n";
    print "  $_: $s->{$_}\n" foreach (@k);
}
    
       
if (@ARGV != 1 ) {
  print "Usage: $0 <-t> | <-c> | <-l> \n";
  print "  -c: compare DNS dig results.\n";
  print "  -t: dig test to all DNS servers.\n";
  print "  -l: list all DNS servers.\n";
  exit(0);
}    

init();

if($ARGV[0] =~/\A-t/) {
  test_dns();
  exit(0);
}

if($ARGV[0] =~ /\A\-c/) {
   cmp_dns();
   exit();
}

if($ARGV[0] =~ /\A\-l/) {
   list_dns_servers();
   exit();
}

die "Usage: $0 <-t> | <-c> | <-l>\n";

