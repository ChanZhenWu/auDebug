#!/usr/bin/perl
print "\n*****************************************************************************\n";
print "  3070 auto debug script <v0.99>\n";
print "  Author: Noon Chen\n";
print "  A Professional Tool for Test.\n";
print "  ",scalar localtime;
print "\n*****************************************************************************\n";
print "\n";
#-----------------------------------------------------------------------------------------
# ver 0.6 has updated and validated for pins, shorts auto debug. 2025/2/17
# ver 0.7 has optimized shorts processing bugs. 2025/2/18
# ver 0.8 has updated for analog auto debug. 2025/2/19
# ver 0.9 has updated for multiple board 'pins','shorts','analog'.
# ver 0.91 has optimized for multiple board tacitly approve or covert selection. 2025/2/21
# ver 0.93 has optimized read file error handling. 2025/2/25
# ver 0.94 has added log output. 2025/2/28
# ver 0.95 has merged wiring check and analog parameters extracting script. 2025/3/11
# ver 0.96 has merged analog parameters updating script. 2025/3/13
# ver 0.97 has merged Bdg runner script. 2025/3/15
# ver 0.98 has added compile action. 2025/3/16
# ver 0.99 has updated auto version screen and added comments for 'ALLCOMP_statement'. 2025/3/18

use strict;
use warnings;
use List::Util 'uniq';
use Excel::Writer::XLSX;
use File::Copy;
use Time::HiRes qw(time);

my $multiBoard = 0;
my $num = 1;
my $array = '';
my $ground = '';
my $node = '';
my $pins = '';
my @fixednode = ();
my @filehead = ();
my @failPins = ();
my @testPins = ();
my @inaccePins = ();
my @extraPins = ();
my @testShorts = ();
my @untestShorts = ();
my @testNodes = ();
my @untestNodes = ();
my @openFail = ();
my @shortFail = ();
my @groupFail = ();
my @Fgroup = ();
my @addShort = ();
my @sortNodes = ();
my @shortSeg1 = ();
my @shortSeg2 = ();
my @shortSeg3 = ();
my @shortSeg4 = ();
my @shortSeg5 = ();
my @shortSeg6 = ();
my @failAnalog = ();

#-----------------------------------------------------------------------------------------
print "	1, fixture wiring check\n";
print "	2, auto debug pins\n";
print "	3, auto debug shorts\n";
print "	4, auto debug analog\n";
print "	5, extracting analog parameters\n";
print "	6, updating analog parameters\n";
print "	7, Bdg runner\n";
print "\n	>>> Please select an item to carry out: ";
	my $option=<STDIN>;
	chomp $option;
print "\n";

if ($option =~ "#")
{
	$num = substr($option,2); 
	$option = substr($option,0,1); 
# 	print $option,$num,"\n";
	}

if ($option == 1) {wiring_check();}
if ($option == 2) {head(); debugPins();}
if ($option == 3) {head(); debugShorts();}
if ($option == 4) {head(); extract_fixnode(); version_screen(); debugAnalog();}
if ($option == 5) {extract_analog();}
if ($option == 6) {version_screen(); update_analog();}
if ($option == 7) {Bdg_runner();}


#-----------------------------------------------------------------------------------------
############################### version screen ###########################################
sub version_screen{
our $VR = "False";
print  "	>>> version screening ... \n";
open (Config, "<config") or warn "\t!!! Failed to open 'config' file: $!.\n\n";
if ($! eq "No such file or directory"){print "\n\t>>> program exiting ...\n"; <STDIN>; exit;}
while($array = <Config>)
{
	$array =~ s/(^\s+|\s+$)//g;
	$array =~ s/( +)/ /g;
	if ($array eq "enable multiple board versions"){$VR = "True";}
	}
close Config;
print  "\tVersion: ".$VR."\n";
}


############################### head content #############################################
sub head{
print  "	"."!----!" x 10,"\n";
print  "	>>> make sure there is KGB in fixture and all wiring is OK.\n";
print  "	"."!----!" x 10,"\n";
}


############################### extract fixed nodes ######################################
sub extract_fixnode{
print  "\n	>>> extracting fixed nodes from Board ... \n";
open (Board, "<board") or warn "\t!!! Failed to open 'board' file: $!.\n\n";
if ($! eq "No such file or directory"){print "\n\t>>> program exiting ...\n"; <STDIN>; exit;}
	while ($array = <Board>)
	{
		$array =~ s/(^\s+|\s+$)//g;
		if (substr($array,0, 6) eq "BOARDS"){$multiBoard = 1;}
		if($array =~ "FIXED NODE OPTIONS")
		{
			#print $array,"\n";
			while($array = <Board>)
			{
				$array =~ s/(^\s+|\s+$)//g;
				$ground = substr($array,0,index($array,"GROUND;"));
				$ground =~ s/(^\s+|\s+$)//g;
				last if ($array =~ "GROUND;");
				$node = substr($array,0,index($array,"Family"));
				$node =~ s/(^\s+|\s+$)//g;
				push(@fixednode, $node);
				#print $node,"\n";
				}
			}
		}
close Board;
# print @fixednode,"\n";
# print "\tmultiple board: ",$multiBoard,"\n";
print  "\tFixedNode Scale: ".scalar@fixednode."\n";
print  "\tground node is: ".$ground,"\n\n";
}


############################### process fixture.o ########################################
sub wiring_check{
print  "\n  >>> processing fixture.o ... \n\n";
my $Nnum = 0;	#node numbers
my $Wnum = 0;   #Wire numbers
my @shorts = ();
my @Spins =();
my @pins =();
my $short_pair = '';
my $BRC = '';
my $BRCbuffer = '';
my @node = '';
my @nodes = '';
my $panel = "";

my $wirelist = "wirelist.o";

if(-e $wirelist){
	print "  project files found.\n\n";
	}
else{
	print "  fixture only project.\n\n";
# Generate the demo config file for full bank
	open (Config, ">config");
	print Config "!!!!    5    0    2 1493432712  Vc903                                         \n";
	print Config "target hp3073 standard\n";
	print Config "enable common delimiter\n";
	print Config "enable express fixturing\n";
	print Config "enable software revision b\n";

	print Config "module 0\n";
	print Config "cards 1 asru c revision\n";
	print Config "cards 2 to 5 hybrid standard double density\n";
	print Config "cards 6 control xt\n";
	print Config "cards 7 to 11 hybrid standard double density\n";
	print Config "end module\n";

	print Config "module 1\n";
	print Config "cards 1 asru c revision\n";
	print Config "cards 2 to 5 hybrid standard double density\n";
	print Config "cards 6 control xt\n";
	print Config "cards 7 to 11 hybrid standard double density\n";
	print Config "end module\n";

	print Config "module 2\n";
	print Config "cards 1 asru c revision\n";
	print Config "cards 2 to 5 hybrid standard double density\n";
	print Config "cards 6 control xt\n";
	print Config "cards 7 to 11 hybrid standard double density\n";
	print Config "end module\n";

	print Config "module 3\n";
	print Config "cards 1 asru c revision\n";
	print Config "cards 2 to 5 hybrid standard double density\n";
	print Config "cards 6 control xt\n";
	print Config "cards 7 to 11 hybrid standard double density\n";
	print Config "end module\n";

	close Config;
	#my $value = system ("comp 'config' -l > Null");
	
# Generate the demo board file
	open (Board, ">board");
	print Board "HEADING\n";
	close Board;
	#system ("check board 'board'");
	#$value = system ("bcomp 'board' -l > Null");
	
# Gerarate the demo board_xy file
	open (Boardxy, ">board_xy");
	print Boardxy "!!!!   15    1    1 1469081253   0000                                         \n";
	print Boardxy "	UNITS  MILS;\n";
	print Boardxy "	SCALE  0.1;\n";

	open (Fixture, "<fixture/fixture.o");
	while (my $array = <Fixture>)
	{
		$array =~ s/(^\s+|\s+$)//g;
		if($array =~ "PLACEMENT")
		{
			print Boardxy "	",$array,"\n";
			while($array = <Fixture>)
			{
				$array =~ s/(^\s+|\s+$)//g;
				last if ($array =~ "NODE|BOARD|KEEPOUT");
				print Boardxy "	",$array,"\n";
				}
			}
		}
	close Fixture;
	close Boardxy;
	#$value = system ("bcomp 'board_xy' -l > Null");

# Gerarate the demo wirelist file
	open (Wirelist, ">wirelist");
	print Wirelist "!!!!   10    0    1 1504779331   0000                                         \n";
#	print Wirelist "test shorts \"fix_pins\"","\n";
#	print Wirelist "end test\n";
#	print Wirelist "test shorts \"fix_shorts\"","\n";
#	print Wirelist "end test\n";
	close Wirelist;
	#$value = system ("wcomp 'wirelist' -l > Null");

}


open (fix_pins, ">fix_pins");
open (fix_shorts, ">fix_shorts");
print fix_pins "!!!!   16    0    1 1460865776   0000                                         \n";
print fix_shorts "!!!!    9    0    1 1460733871   0000                                         \n";

open (Fixture, "< ./fixture/fixture.o");
open (Report, ">Details.txt");
	while(my $LIST = <Fixture>)
	{
		$LIST =~ s/(^\s+|\s+$)//g;		#clear all non-character symbol
		next if(!$LIST);				#goto next if it's empty
		my @nodes = split('\s+', $LIST);
		last if ($LIST eq "PROTECTED UNIT");
		if ($LIST =~ "END PANEL"){$panel = "True";}

		if($nodes[0] eq "NODE")
		{
			$LIST = <Fixture>;
			$LIST =~ s/(^\s+|\s+$)//g;
			next if(!$LIST);			#goto next if it's empty
			if($LIST ne "PROBES")
			{
				$Nnum++;
				if($nodes[1] =~ '\%'){$nodes[1] = substr($nodes[1], 3, -1)}
				if($nodes[1] =~ '\"'){$nodes[1] = substr($nodes[1], 1, -1)}
				#next if($nodes[1] =~ /(^NC_|_NC$|NONE)/);	#eliminate NC nets
				print "Probe\#:$Nnum	$nodes[1]\n";
				print Report "	#$Nnum\n";
				print Report "$nodes[1]\n";
				while($LIST = <Fixture>)
				{
					$LIST =~ s/(^\s+|\s+$)//g;
					last if(!$LIST);		#exit loop if it's none-character symbol				
					if($LIST eq "WIRES")
					{
						my @pair = ();
						#print @pair."\n";
						my $BRCnum = 0;	#BRC numbers
						while($LIST = <Fixture>)
						{
							$LIST =~ s/(^\s+|\s+$)//g;	   #clear all non-character symbol
							goto NEXT_NODE if(!$LIST);		#exit loop if it's none-character symbol
							@node = split('\s+', $LIST);
							if($node[0] !~ /(\D+)/) {($BRC) = $node[0] =~ /(\d+)/;
								next if(substr($BRC,-2) =~ /(19|20|39|40|59|60)/);	#eliminate fixed GROUND
								next if(substr($BRC,0,3) =~ /(201|213|111|123|106|118|206|218)/);	#eliminate ASRU/Control card				
								next if($BRCbuffer eq $BRC);
								$Wnum++;
								print "   Wire\#:$Wnum	",$BRC,"\n";
								print Report $BRC."\n";
								$BRCbuffer = $BRC;
								unshift(@pair, $BRC);
								if($BRCnum > 0)		#collect shorts data
								{
									#print $BRC,"\n";
									if($BRC < $pair[$BRCnum]){$short_pair = $BRC." to ".$pair[$BRCnum]."\n";}
									if($BRC > $pair[$BRCnum]){$short_pair = $pair[$BRCnum]." to ".$BRC."\n";}
									print Report " -- ".$short_pair;
									#push(@shorts, "short ".$short_pair);
									push(@shorts, 'failure '.'" >> Node: '.$nodes[1].'"'."\n"."  short ".$short_pair);
									push(@pins, "nodes  ".$BRC."  \!$nodes[1]\n");
									push(@Spins, 'failure '.'" >> Node: '.$nodes[1].'"'."\n"."  nodes  ".$BRC."\n");
									#print @shorts;
									}
								else		#collect pins data
								{
									push(@pins, "nodes  ".$BRC."  \!$nodes[1]\n");
									push(@Spins, 'failure '.'" >> Node: '.$nodes[1].'"'."\n"."  nodes  ".$BRC."\n");
									}
								$BRCnum++;
								}
							}
						}
					}
				}
			}
		NEXT_NODE:
		}
	my @unique_pins = uniq @pins;
	my @unique_Spins = uniq @Spins;
	my @unique_shorts = uniq @shorts;

	print "\n\tShorts Scale: ".scalar@unique_shorts."\n";
	print fix_shorts "! Shorts Scale: ".scalar@unique_shorts."\n";
	print "\tNodes Scale: ".scalar@unique_Spins;
	print fix_shorts "! Nodes Scale: ".scalar@unique_Spins."\n";
	print fix_pins "! Nodes Scale: ".scalar@unique_pins."\n";

	print fix_shorts "  threshold 12\n  settling delay 1m\n";
	print fix_shorts sort @unique_shorts;
	print fix_shorts 'failure ""'."\n";
	print fix_shorts '!#########################################################################################'."\n";

	print fix_shorts "  threshold 1000\n";
	print fix_shorts sort @unique_Spins;
	print fix_shorts 'failure ""'."\n";
	print fix_pins sort @unique_pins;

close Report;
close Fixture;
close fix_shorts;
close fix_pins;


	open (Wirelist, ">>wirelist");
	print Wirelist "\ntest shorts \"fix_pins\"","\n";
	print Wirelist "end test\n";
	print Wirelist "test shorts \"fix_shorts\"","\n";
	print Wirelist "end test\n";
	close Wirelist;

if ($panel eq "True"){
	rename "fix_pins", "1%fix_pins";
	rename "fix_shorts", "1%fix_shorts";
	print  "\n	>>> '1%fix_pins','1%fix_shorts' file generated ... \n";
	}
else{
	print  "\n	>>> 'fix_pins','fix_shorts' file generated ... \n";
	}

}


############################### auto debug "pins" ########################################
sub debugPins{
print  "\n	>>> debugging Pins ... \n";

my $pinsCount = 0;

	# extracting debug report
open (Debug, "<debug/report") or warn "\t!!! Failed to open 'debug/report' file: $!.\n\n";
if (not -e "debug/report"){return;}
	while ($array = <Debug>)
		{
			$array =~ s/(^\s+|\s+$)//g;
			if ($array =~ '----------------------------------------'){next;}
			elsif ($array =~ 'Shorts Report for "'){print "\n\t!!! 'debug/report' is not corresponding to 'pins'.\n\n"; last;}
			
			if ($array =~ '\(\d*\)')
			{
				$pins = substr($array,index($array, ' '));
				$pins =~ s/(^\s+|\s+$)//g;
				#print substr($pins,0, index($pins,'%')+1),"\n";
				if($multiBoard == 1)								# for multiboard
				{
					if(substr($pins, 0, index($pins,'%')+1) eq "$num%"){$pins = substr($pins, index($pins, '%')+1); push(@failPins, $pins);}
					}
				if($multiBoard == 0){push(@failPins, $pins);}		# for singalboard
				#print $pins."\n";
				}
			}
close Debug;
print  "\tfailedPins Scale: ".scalar@failPins."\n";

	# extracting pins test
open (Pins, "<pins") or open (Pins, "< $num%pins") or warn "\t!!! Failed to open 'pins' file: $!.\n\n";
if ($! eq "No such file or directory"){return;}
	while ($array = <Pins>)
	{
		$array =~ s/^ +//g;
		#print $array."\n";
		if (substr($array,0,4) eq "!!!!" or substr($array,0,5) eq "!IPG:") {push(@filehead, $array);}
		elsif (substr($array,0,1) eq "!" and $array =~ "nodes") {push(@inaccePins, $array);}
		elsif (substr($array,0,5) eq "nodes") {push(@testPins, $array);}
		elsif ($array =~ /\w+/) {push(@extraPins, $array);}
		#else {push(@extraPins, $array);}
		}
close Pins;

# print scalar @testPins,"\n";
# print scalar @inaccePins,"\n";
# print scalar @filehead,"\n";
# print scalar @extraPins,"\n";

	# handling failed pins
foreach my $i (0..@testPins-1)
{
	my @list = split('\"', $testPins[$i]);
# 	print $list[1],"\n";
# 	print substr($list[1],index($list[1],'%')+1),"\n";
	if ($multiBoard == 0)				# for singalboard
	{
		if (grep{ $_ eq $list[1]} @failPins)
		{
			$pinsCount++;
			$testPins[$i] =~ s/(^\s+|\s+$)//g;
			$testPins[$i] = "!# nodes \"".$list[1]."\"\t\t!auDeb\n";
			print "\t\tprocessing ".$testPins[$i];
			}
		}
	if ($multiBoard == 1)				# for multiboard
	{
		if (grep{ $_ eq substr($list[1],index($list[1],'%')+1)} @failPins)
		{
			$pinsCount++;
			$testPins[$i] =~ s/(^\s+|\s+$)//g;
			$testPins[$i] = "!$num% nodes \"".$list[1]."\"\t\t!auDeb\n";
			print "\t\tprocessing ".$testPins[$i];
			}
		}
	}

	# sorting pins data
@testPins = sort @testPins;
@inaccePins = sort @inaccePins;
@extraPins = sort @extraPins;
print  "\ttestedPins Scale: ".scalar@testPins."\n";
print  "\tinaccePins Scale: ".scalar@inaccePins."\n";
print  "\textraPins Scale: ".scalar@extraPins."\n";
#rename "pins", "pins~";

	# output pins test
if($pinsCount > 0 or not -e "pins.ori" and not -e "$num%pins.ori")
{
	if ($multiBoard == 0){open (Pins, ">pins1");}					# for singalboard
	if ($multiBoard == 1){open (Pins, ">$num%pins1");}				# for multiboard
		print Pins @filehead;
		print Pins @testPins;
		print Pins @inaccePins;
		print Pins @extraPins;
	close Pins;
	rename("pins", "pins.ori") or rename("$num%pins", "$num%pins.ori") or die "Failed to rename file: $!\n";
	rename("pins1", "pins") or rename("$num%pins1", "$num%pins") or die "Failed to rename file: $!\n";
	}
print  "\n\tauto debugged pins: ".$pinsCount."\n";

}


############################### auto debug "shorts" ######################################
sub debugShorts{
print  "\n	>>> debugging Shorts ... \n";

my @testShorts = ();
my $thres = '';
my $delay = '';
my $node_name = '';
my $Fnode = '';
my $Tnode = '';
my $comdev = '';
my $shortCount = 0;

# extracting shorts test
if ($multiBoard ==0)
{
my $file = "shorts.ori";
if (-e $file)
	{open (Shorts, "< shorts.ori")  or warn "\t!!! Failed to open 'shorts' file: $!.\n\n";}
else
	{open (Shorts, "< shorts")  or warn "\t!!! Failed to open 'shorts' file: $!.\n\n";}
	}
if ($multiBoard ==1)
{
my $file = "$num%shorts.ori";
if (-e $file)
	{open (Shorts, "< $num%shorts.ori")  or warn "\t!!! Failed to open 'shorts' file: $!.\n\n";}
else
	{open (Shorts, "< $num%shorts")  or warn "\t!!! Failed to open 'shorts' file: $!.\n\n";}
	}
if ($! eq "No such file or directory"){return;}

	while ($array = <Shorts>)
	{
		chomp $array;
		$array =~ s/^ +//g;	   #clear head of line spacing
		#print "$array\n";

			# extracting threshold
		if (substr($array,0,9) =~ "threshold") 
		{
			$thres = substr($array, index($array,"threshold")+10);
			if ($array =~ "\!"){$thres = substr($array, 10, index($array,"\!")-10);}
			elsif (int($thres) == 22){$thres = substr($array, index($array,"threshold")+10);}
			elsif (int($thres) == 61){$thres = substr($array, index($array,"threshold")+10);}
			elsif (int($thres) == 180){$thres = substr($array, index($array,"threshold")+10);}
			elsif (int($thres) == 405){$thres = substr($array, index($array,"threshold")+10);}
			$thres =~ s/(^\s+|\s+$)//g;                     	#clear all spacing
			}
			# extracting delay
		if ($array =~ "delay") 
		{
			$delay = substr($array, index($array,"delay")+6);
			$delay =~ s/(^\s+|\s+$)//g;                     	#clear all spacing
			}

			# extracting shorts test
		if ($array =~ "short")
		{
		#print "$array\n";
			if(substr($array,0,1) eq "!"){
				$array =~ s/(^\s+|\s+$)//g;                     	#clear all spacing
				# print $array,"\n";
				push(@untestShorts, $array."\n");
				}
			elsif(substr($array,0,5) eq "short"){
				$array =~ s/(^\s+|\s+$)//g;
				# print $array,"\n";
				$array =~ s/( +)/ /g; 
				#print $array,"\n";
				push(@testShorts, $array."\n");
				}
			}

			# extracting nodes test
		if ($array =~ "nodes")
		{
			if(substr($array,0,1) eq "!")
			{
				$array =~ s/(^\s+|\s+$)//g;                     	#clear all spacing
				# print $array,"\n";
				push(@untestNodes, $array."\n");
				}
			elsif(substr($array,0,5) eq "nodes")
			{
				$array =~ s/(^\s+|\s+$)//g;
				$array =~ s/( +)/ /g; 
				#print $thres."\|".$delay."\|".$array,"\n";
				push(@testNodes, $thres."\|".$delay."\|".$array);
				}
			}
		if (substr($array,0,4) eq "!!!!" or substr($array,0,5) eq "!IPG:") {push(@filehead, $array."\n");}
	}
close Shorts;

# print @testShorts,"\n";
# print @untestShorts,"\n";
# print @testNodes,"\n";
# print @untestNodes,"\n";

print  "\ttestedShorts Scale: ".scalar@testShorts."\n";
print  "\tuntestShorts Scale: ".scalar@untestShorts."\n";
print  "\ttestedNodes Scale: ".scalar@testNodes."\n";
print  "\tuntestNodes Scale: ".scalar@untestNodes."\n";

# 	testedShorts Scale: 83/121
# 	untestShorts Scale: 492/502
# 	testedNodes Scale: 950
# 	untestNodes Scale: 2598

# extracting debug report
open (Debug, "<debug/report") or warn "\t!!! Failed to open 'debug/report' file: $!.\n\n";
if (not -e "debug/report"){return;}
	while ($array = <Debug>)
	{
		$array =~ s/(^\s+|\s+$)//g;
		#print $array,"\n";
		
		if ($array =~ '----------------------------------------'){next;}
		elsif ($array =~ 'CHEK-POINT Report for "'){print "\n\t!!! 'debug/report' is not corresponding to 'shorts'.\n"; last;}

		$comdev = "None";
		# extracting open data
		if (substr($array,0,6) eq "Open #")
		{
				while ($array = <Debug>)
				{
					$array =~ s/(^\s+|\s+$)//g;
					#print $array,"\n";
					last if ($array eq "----------------------------------------");
					# extract From node
					if (substr($array,0,5) eq "From:")
					{
						my @list = split(" ", $array);
						#print substr($list[1],0,2),"\n";
						if ($multiBoard == 0)				# for singalboard
						{
							$Fnode = $list[1];
							if ($list[1] eq "v")
							{
								$array = <Debug>;
								$array =~ s/(^\s+|\s+$)//g;
								$Fnode = $array;
								}
							}
							
						if ($multiBoard == 1 and substr($list[1],0,length($num)+1) eq "$num%")				# for multiboard
						{
							$Fnode = "#%".substr($list[1], index($list[1], '%')+1);
							if ($list[1] eq "v")
							{
								$array = <Debug>;
								$array =~ s/(^\s+|\s+$)//g;
								$Fnode = "#%".substr($array, index($array, '%')+1);
								}
							}
						#print $Fnode,"\n";
						}
					
					# extract To node
					if (substr($array,0,3) eq "To:")
					{
					my @list = split(" ", $array);
						if ($multiBoard == 0)										# for singalboard
						{
							$Tnode = $list[1];
							if ($list[1] eq "v")
							{
								$array = <Debug>;
								$array =~ s/(^\s+|\s+$)//g;
								$Tnode = $array;
								}
							}
						
						if ($multiBoard == 1 and substr($list[1],0,length($num)+1) eq "$num%")		# for multiboard
						{
							$Tnode = "#%".substr($list[1], index($list[1], '%')+1);
							if ($list[1] eq "v")
							{
								$array = <Debug>;
								$array =~ s/(^\s+|\s+$)//g;
								$Tnode = "#%".substr($array, index($array, '%')+1);
								}
							}
						#print $Tnode,"\n";
						}
					
					if (substr($array,0,15) eq "Common Devices:")
					{
						$array = <Debug>;
						$array =~ s/(^\s+|\s+$)//g;
						$comdev = $array;
						}
					}
					if ($Fnode ne "" and $Tnode ne "")
					{
						#print $Fnode."\|".$Tnode."\|".$comdev."\n";
						push(@openFail, $Fnode."\|".$Tnode."|".$comdev);
						}
			}
		
	# extract shorts data
		@shortFail = ();
		@groupFail = ();
		if (substr($array,0,7) eq "Short #")
		{
		my $Fnode = "";
		my $Fthres = "";
		my $Tnode = "";
		my $Tthres = "";
		my $comdev = "";
		my @list = ();
		$comdev = "None";
		
		$thres = substr($array, index($array," Thresh ")+8, index($array,", Delay ")-(index($array," Thresh ")+8));
		#print $thres,"\n";
			while ($array = <Debug>)
			{
				$array =~ s/(^\s+|\s+$)//g;
				#print $array,"\n";
				last if ($array eq "----------------------------------------");
				next if ($array =~ "&");
				my @list = split(" +", $array);
				
			# extract From node
				if (substr($array,0,5) eq "From:")
				{
 					my @list = split(" ", $array);
					$Fthres = $list[3];
					#print  substr($list[1],0,2),"\n";
					
					if ($multiBoard == 0)										# for singalboard
					{
						$Fnode = $list[1];
						if ($list[1] eq "v")
						{
							$array = <Debug>;
							$array =~ s/(^\s+|\s+$)//g;
							$Fnode = $array;
							}
						}
					if ($multiBoard == 1 and substr($list[1],0,length($num)+1) eq "$num%")		# for multiboard
						{
							$Fnode = "#%".substr($list[1], index($list[1], '%')+1);
							if ($list[1] eq "v")
							{
								$array = <Debug>;
								$array =~ s/(^\s+|\s+$)//g;
								$Fnode = "#%".substr($array, index($array, '%')+1);
								}
							}
					#print $Fnode,"\n";
					}
					
			# extract To node
				if (substr($array,0,3) eq "To:")
				{
 					my @list = split(" ", $array);
					$Tthres = $list[3];

					if ($multiBoard == 0)										# for singalboard
					{
						$Tnode = $list[1];
						if ($list[1] eq "v")
						{
							$array = <Debug>;
							$array =~ s/(^\s+|\s+$)//g;
							$Tnode = $array;
							}
						}
						
					if ($multiBoard == 1 and substr($list[1],0,length($num)+1) eq "$num%")		# for multiboard
						{
							$Tnode = "#%".substr($list[1], index($list[1], '%')+1);
							if ($list[1] eq "v")
							{
								$array = <Debug>;
								$array =~ s/(^\s+|\s+$)//g;
								$Tnode = "#%".substr($array, index($array, '%')+1);
								}
							}
					#print $Tnode,"\n";
					}
					
				if (substr($array,0,15) eq "Common Devices:")
				{
					$array = <Debug>;
					$array =~ s/(^\s+|\s+$)//g;
					$comdev = $array;
					}
					
			# list all short nodes
				if (scalar @list == 3 and $list[1] =~ /\d+$/ and $list[2] =~ /\d+$/)
				{
					
					if ($multiBoard == 0)										# for singalboard
					{
						if ($list[0] eq "v")
						{
							$array = <Debug>;
							$array =~ s/(^\s+|\s+$)//g;
							$list[0] = $array;
							}
						#print $list[0],"\|",$list[2],"\n";
						push(@groupFail, "\|".$list[0]."\|".$list[2]);
						}
					
					if ($multiBoard == 1 and substr($list[0],0,length($num)+1) eq "$num%")		# for singalboard
					{
						if ($list[0] eq "v")
						{
							$array = <Debug>;
							$array =~ s/(^\s+|\s+$)//g;
							$list[0] = $array;
							}
						#print "#%".substr($list[0], index($list[0], '%')+1);
						$list[0] = "#%".substr($list[0], index($list[0], '%')+1);
						#print $list[0],"\|",$list[2],"\n";
						push(@groupFail, "\|".$list[0]."\|".$list[2]);
						}
					}
				}
				#print $thres."\|".$Fnode."\|".$Tnode."\|".$comdev."\n";

				next if ($Fnode eq "");
				if ($Fnode ne "")
				{
					$shortCount++;
					#print $thres."\|".$Fnode."\|".$Tnode."\|".$comdev."\n";
					push(@shortFail, $thres."\|".$Fnode."\|".$Fthres."\|".$Tnode."\|".$Tthres."\|".$comdev."\|".@groupFail);
					}
			@shortFail = (@shortFail,@groupFail);
			@Fgroup = (@Fgroup,@shortFail);
			
#  			print @shortFail,"\n";
#  			print @groupFail,"\n";
#  			print scalar @Fgroup,"\n";
# 			print scalar @shortFail,"\n";
# 			print scalar @groupFail,"\n";

		# handling add shorts
		#	use experimental 'smartmatch';
			@list = split('\|', $shortFail[0]);
			# handling 2nodes failure
			if (int($list[2]) <= 8 and int($list[4]) <= 8)
			{
				my $pair = "short \"".$list[1]."\" to \"".$list[3]."\"\ !$num% auDeb/".$list[5]."\n";
				#unless ($pair ~~ @testShorts)	# smart match
				unless (grep{$_ eq $pair} @testShorts)
				{
					#print "short \"".$list[1]."\" to \"".$list[3]."\"\  !# auDeb/".$list[5]."\n";
					if ($multiBoard == 0)
					{
						print "\t\tauto debugging - short \"".$list[1]."\" to \"".$list[3]."\""."\n";
						push (@addShort, "short \"".$list[1]."\" to \"".$list[3]."\"\ !# auDeb/".$list[5]."\n");
						}
					if ($multiBoard == 1)
					{
						print "\t\tauto debugging - $num%short \"".$list[1]."\" to \"".$list[3]."\""."\n";
						push (@addShort, "short \"".$list[1]."\" to \"".$list[3]."\"\ !$num% auDeb/".$list[5]."\n");
						}
					}
				}
			elsif (int($list[2]) <= 8 and int($list[4]) > 8)
			{
				#print $list[3]."\t".$list[4]."\n";		# 'To' node > 8ohm
				push (@sortNodes, $list[3]."\|".$list[4]."\n");
				}
			elsif (int($list[2]) > 8 and $list[3] eq "")
			{
				#print "$list[1]	$list[2] -> phantoms failure\n";
				push (@sortNodes, $list[1]."\|".$list[2]."\n");
				}
			
		# handling >2nodes failure
			if (scalar @shortFail > 1)
			{
				foreach my $i (0..@groupFail-1)
				{
					my @list2 = split('\|', $groupFail[$i]);
					#print $list2[1],"\t",$list2[2],"\n";
					#my $shortExist = 0;
					if (int($list[2]) <= 8 and int($list2[2]) <= 8)
					{
						my $pair = "short \"".$list[1]."\" to \"".$list2[1]."\"\ !$num% auDeb/".$list[5]."\n";
						#unless ($pair ~~ @testShorts)	# smart match
						unless (grep{$_ eq $pair} @testShorts)
						{
							#print "short \"".$list[1]."\" to \"".$list2[1]."\"\  !# auDeb/".$list[5]."\n";
							if ($multiBoard == 0)
							{
								print "\t\tauto debugging - short \"".$list[1]."\" to \"".$list2[1]."\""."\n";
								push (@addShort, "short \"".$list[1]."\" to \"".$list2[1]."\"\ !# auDeb/".$list[5]."\n");
								}
							if ($multiBoard == 1)
							{
								print "\t\tauto debugging - $num%short \"".$list[1]."\" to \"".$list2[1]."\""."\n";
								push (@addShort, "short \"".$list[1]."\" to \"".$list2[1]."\"\ !$num% auDeb/".$list[5]."\n");
								}
							}
						}
					# handling >2nodes > 8ohm failure
					else
					{
						#print $list2[1]."\t".$list2[2]."\n";		# rest node > 8ohm
						push (@sortNodes, $list2[1]."\|".$list2[2]."\n");
						}
					}
				}
			}
		}
close Debug;

# print @openFail, "openFail: ", scalar @openFail,"\n";
# print @addShort, "addShort ", scalar @addShort,"\n";
# print @sortNodes, "sortNodes ", scalar @sortNodes,"\n";
# print @testShorts, "\n	testShorts ", scalar @testShorts,"\n\n";

# handling open item
foreach my $i (0..@testShorts-1)
{
	my @testList = split('\"', $testShorts[$i]);
	#print $testList[1],"\t",$testList[3],"\n";
	foreach my $s (0..@openFail-1)
	{
		my @openList = split('\|', $openFail[$s]);
		#print $openList[0],"\t",$openList[1],"\n";
		if (($testList[1] eq $openList[0] and $testList[3] eq $openList[1]) 
		or ($testList[3] eq $openList[0] and $testList[1] eq $openList[1]) )
		{
			#print $testShorts[$i],"\n"; 
			if ($multiBoard == 0)
			{
				print "\t\tauto debugging - ".$testShorts[$i];
				$testShorts[$i] = "!# auDeb/$openList[2] ".$testShorts[$i];
				}
			
			if ($multiBoard == 1)
			{
				print "\t\tauto debugging - $num%".$testShorts[$i];
				$testShorts[$i] = "!$num% auDeb/$openList[2] ".$testShorts[$i];
				}
			#print $testShorts[$i],"\n"; 
			}
		}
	}

# handling nodes item
$delay = "";
my $delaySeg1 = "";
my $delaySeg2 = "";
my $delaySeg3 = "";
my $delaySeg4 = "";
my $delaySeg5 = "";
my $delaySeg6 = "";

foreach my $i (0..@testNodes-1)
{
	my $updatedelay = "";
	my @testList = ();
	@testList = split('\|', $testNodes[$i]);
	my @Snode = split('\"', $testNodes[$i]);
#  	print $testList[1]."\n";
#  	print int(substr($testList[1], 0, rindex($testList[1],"m")))."\n";
	if ($testList[1] !~ "\!" and substr($testList[1], rindex($testList[1],"m"), 1) eq "m" and int(substr($testList[1], 0, rindex($testList[1],"m"))) < 2) { $updatedelay = $testList[1];}
	elsif ($testList[1] =~ "\!") { $updatedelay = $testList[1];}
	elsif ($testList[1] !~ "\!" and substr($testList[1], rindex($testList[1],"m"), 1) eq "m" and int(substr($testList[1], 0, rindex($testList[1],"m"))) >= 2) { $updatedelay = (substr($testList[1], 0, rindex($testList[1],"m"))/2)."m  ! ".$testList[1];}
#  	print "updated ".$updatedelay."\n";

	if(substr($testList[1], rindex($testList[1],"u"), 1) eq "u"){$testList[1] = $testList[1];}
	elsif(substr($testList[1], rindex($testList[1],"m"), 1) eq "m"){$testList[1] = $updatedelay;}
	else{$testList[1] = "210m  ! ".$testList[1];}
#  	print $testList[1]."\n";

	foreach my $s (0..@sortNodes-1)
	{
		my @nodeList = split('\|', $sortNodes[$s]);
		if ($Snode[1] eq $nodeList[0])
		{
		
			if ($delay ne $testList[1] and $delay ne "")
			{}
			else
			{
				$nodeList[0] = $testList[2];
				}
			if (int($nodeList[1]) <= 45)
			{
				if (scalar @shortSeg1 == 0 or $delaySeg1 ne $testList[1]){push (@shortSeg1, "settling delay        ".$testList[1]."\n");}
				push (@shortSeg1, $nodeList[0]."\n");
				$delaySeg1 = $testList[1];
				goto Next;
				}
			elsif (int($nodeList[1]) <= 95)
			{
				if (scalar @shortSeg2 == 0 or $delaySeg2 ne $testList[1]){push (@shortSeg2, "settling delay        ".$testList[1]."\n");}
				push (@shortSeg2, $nodeList[0]."\n");
				$delaySeg2 = $testList[1];
				goto Next;
				}
			elsif (int($nodeList[1]) <= 210)
			{
				if (scalar @shortSeg3 == 0 or $delaySeg3 ne $testList[1]){push (@shortSeg3, "settling delay        ".$testList[1]."\n");}
				push (@shortSeg3, $nodeList[0]."\n");
				$delaySeg3 = $testList[1];
				goto Next;
				}
			elsif (int($nodeList[1]) <= 455)
			{
				if (scalar @shortSeg4 == 0 or $delaySeg4 ne $testList[1]){push (@shortSeg4, "settling delay        ".$testList[1]."\n");}
				push (@shortSeg4, $nodeList[0]."\n");
				$delaySeg4 = $testList[1];
				goto Next;
				}
			elsif (int($nodeList[1]) < 1000)
			{
				if (scalar @shortSeg5 == 0 or $delaySeg5 ne $testList[1]){push (@shortSeg5, "settling delay        ".$testList[1]."\n");}
				push (@shortSeg5, $nodeList[0]."\n");
				$delaySeg5 = $testList[1];
				goto Next;
				}
			else
			{
				if (scalar @shortSeg6 == 0 or $delaySeg6 ne $testList[1]){push (@shortSeg6, "settling delay        ".$testList[1]."\n");}
				push (@shortSeg6, $nodeList[0]."\n");
				$delaySeg6 = $testList[1];
				goto Next;
				}
			}
		}

		if (int($testList[0]) <= 45 and int($testList[0]) != 22)
		{
			if (scalar @shortSeg1 == 0 or $delaySeg1 ne $testList[1]){push (@shortSeg1, "settling delay        ".$testList[1]."\n");}
			push (@shortSeg1, $testList[2]."\n");
			$delaySeg1 = $testList[1];
			goto Next;
			}
		elsif (int($testList[0]) <= 95 and int($testList[0]) != 45)
		{
			if (scalar @shortSeg2 == 0 or $delaySeg2 ne $testList[1]){push (@shortSeg2, "settling delay        ".$testList[1]."\n");}
			push (@shortSeg2, $testList[2]."\n");
			$delaySeg2 = $testList[1];
			goto Next;
			}
		elsif (int($testList[0]) <= 210 and int($testList[0]) != 95)
		{
			if (scalar @shortSeg3 == 0 or $delaySeg3 ne $testList[1]){push (@shortSeg3, "settling delay        ".$testList[1]."\n");}
			push (@shortSeg3, $testList[2]."\n");
			$delaySeg3 = $testList[1];
			goto Next;
			}
		elsif (int($testList[0]) <= 455 and int($testList[0]) != 210)
		{
			if (scalar @shortSeg4 == 0 or $delaySeg4 ne $testList[1]){push (@shortSeg4, "settling delay        ".$testList[1]."\n");}
			push (@shortSeg4, $testList[2]."\n");
			$delaySeg4 = $testList[1];
			goto Next;
			}
		elsif (int($testList[0]) < 1000 and int($testList[0]) != 455)
		{
			if (scalar @shortSeg5 == 0 or $delaySeg5 ne $testList[1]){push (@shortSeg5, "settling delay        ".$testList[1]."\n");}
			push (@shortSeg5, $testList[2]."\n");
			$delaySeg5 = $testList[1];
			goto Next;
			}
		else
		{
			if (scalar @shortSeg6 == 0 or $delaySeg6 ne $testList[1]){push (@shortSeg6, "settling delay        ".$testList[1]."\n");}
			push (@shortSeg6, $testList[2]."\n");
			$delaySeg6 = $testList[1];
			goto Next;
			}
Next:
	}

# generating new shorts fail
print  "\n\topenFail count: ".scalar@openFail."\n";
print  "\tshortFail count: ".$shortCount."\n";

my $file = "shorts.ori";
if (not -e $file){rename "shorts", "shorts.ori";}
$file = "$num%shorts.ori";
if (not -e $file){rename "$num%shorts", "$num%shorts.ori";}


if ($multiBoard == 0){open (Shorts, ">shorts");}				# for multiboard
if ($multiBoard == 1){open (Shorts, ">$num%shorts");}				# for multiboard
	print Shorts sort @filehead;
	print Shorts "threshold           15\n";
	print Shorts "settling delay 50.00u\n";
	print Shorts "report common devices, netlist\n";
	print Shorts "!----!!----!!----!!----!!-- new added --!!----!!----!!----!!----!!----!!----!\n";
	print Shorts @addShort;
	print Shorts "!----!!----!!----!!----!!-- last item --!!----!!----!!----!!----!!----!!----!\n";
	print Shorts sort @testShorts;
	print Shorts sort @untestShorts;
	print Shorts "!----!" x 13,"\n";
	print Shorts "report phantoms","\n";
	if (scalar @shortSeg6 > 0){print Shorts "threshold          1000","\n";}
	print Shorts @shortSeg6;
	if (scalar @shortSeg5 > 0){print Shorts "threshold          405","\n";}
	print Shorts @shortSeg5;
	if (scalar @shortSeg4 > 0){print Shorts "threshold          180","\n";}
	print Shorts @shortSeg4;
	if (scalar @shortSeg3 > 0){print Shorts "threshold          61","\n";}
	print Shorts @shortSeg3;
	if (scalar @shortSeg2 > 0){print Shorts "threshold          22","\n";}
	print Shorts @shortSeg2;
	if (scalar @shortSeg1 > 0){print Shorts "threshold          8","\n";}
	print Shorts @shortSeg1;
	print Shorts sort @untestNodes;
close Shorts;

# 10/15/16.9/20/22/24.9/33/42/47/49.9/51/68/100/113/150/169/180/200/220/240/249/270/300/340/360/470/499/576/590/665/680/715
# 8/33/91/210/455/1000

}


############################### auto debug "analog" ######################################
sub debugAnalog{
our $VR;
print  "	>>> debugging Analog ... \n";

(my $sec, my $min, my $hour, my $mday, my $mon, my $year,my $wday,my $yday,my $isdst) = localtime(time);
my $alog = ('auDebug'."-".$hour.$min.$sec.'.log');
open (Alog, ">$alog");

my @analogfiles = ();
my $path = "";
my $swap_count = 0;

print "\tPlease input 'Version' or tap 'ENTER' for 'Base': ";
my $version=<STDIN>;
chomp $version;

	# read analog files.
if ($version)
{
# 	print "\tVersion: $version\n";
  	print "\n\tgathering Version '$version' analog list...\n";
	@analogfiles = <$version/analog/*.o>;
	$path = "$version/";
	foreach (@analogfiles){ $_ =~ s/(\.o)/\n/g}
  	}
else
{
  	print "\n\tgathering all analog test ...\n";
	@analogfiles = <analog/*.o>;
	$path = "";
	foreach (@analogfiles){ $_ =~ s/(\.o)/\n/g}
	}
# print "path: ",$path,"\n";
# print @analogfiles, "\n\tanalog Scale: ", scalar@analogfiles, "\n";
print "\tanalog Scale: ", scalar@analogfiles, "\n";

	# handling analog file.
foreach my $i (0..@analogfiles-1)
{
my $RCL = 0;	# indicates Res,Cap,Ind
my $swap = 0;	# swap tag.
my $GND = 0;	# judge if ground on i bus tag.
my $fixed = 0;	# for i/s bus both is fixed.
my $fixed1 = 0;	# for i bus is fixed node and another signal.
my @parametric = ();
my $file = "";

# 	print $analogfiles[$i];
# 	$file = substr($analogfiles[$i],rindex($analogfiles[$i],"\/")+1);
	open (Analog, "<$analogfiles[$i]") or warn "\t!!! Failed to open '".substr($analogfiles[$i],0,-1)."' file: $!.\n";
	if ($! eq "No such file or directory"){next;}
	while ($array = <Analog>)
	{
		$array =~ s/^ +//g;	   #clear head of line spacing
		#$array =~ s/( +)/ /g; 
		#print $array;
		last if (substr($array,0,4) eq "test");
		last if ($array =~ "to ground");
		last if ($array =~ "to pins");
		if (substr($array,0,13) eq "connect i to " or substr($array,0,13) eq "connect s to ")	# all bus
		{
			$array =~ s/( +)/ /g; 
			#print "\t",$array;
			push(@parametric, $array);
			my @ibus = split('\"', $array);
			
			if ($multiBoard == 1)										# for multiboard
			{
				$ibus[1] = substr($ibus[1],2);
				#print $ibus[1],"\n";
				}
			
			if ($ibus[1] eq $ground and $ibus[0] eq "connect s to ")			# s bus is ground, no swap action.
			{
				$swap = 3;
				$GND = 3;
				#print "\t S-G ",$ibus[1],"\n";
				next;
				}
			elsif (grep{ $_ eq $ibus[1]} @fixednode and $ibus[1] eq $ground and $array =~ "connect i to ")		# i bus is ground, swap it anyway.
			{
				$swap = 1;
				$GND = 1;
				#print "\t i-G ",$ibus[1],"\n";
				}
			elsif (grep{ $_ eq $ibus[1]} @fixednode and $array =~ "connect s to ")			# s bus is fixed node.
			{
				$swap = 1;
				$fixed++;
				#print "\t S-F ",$ibus[1],"\n";
				}
			elsif (grep{ $_ eq $ibus[1]} @fixednode and $array =~ "connect i to ")			# i bus is fixed node.
			{
				$swap = 1;
				$fixed++;
				#print "\t i-F ",$ibus[1],"\n";
				}
			elsif(grep{ $_ ne $ibus[1]} @fixednode and $array =~ "connect i to ")			# other signal
			{
				$fixed = 3;
				#print "----\t",$ibus[1],"\n";
				next;
				}
			}
		else	# comments and parametric.
		{
			#print $array;
			if (substr($array,0,1) ne "\!" and $array =~ "resistor|capacitor|jumper|fuse")	# only swap bus for these types.
			{
				$RCL = 1;
				}
			push(@parametric, $array);
			}
		}
close Analog;

# 	print "swap $swap ## GND $GND ## fixed $fixed ## swapped: ".$analogfiles[$i];
# 	if ($RCL == 1 and $swap == 1){print "swap $swap ## GND $GND ## fixed $fixed ## swapped: ".$analogfiles[$i];}
	if ($RCL == 1 and $swap == 1 and $GND < 3 and $fixed < 2)
	{
		$swap_count++;
		print "\t# bus swapped: ".$analogfiles[$i];
		#print @parametric,"\n";
		foreach my $i (0..@parametric-1)
		{
			if ($parametric[$i] =~ "connect i to "){$parametric[$i] = "connect #s to ".substr($parametric[$i],13);}
			if ($parametric[$i] =~ "connect s to "){$parametric[$i] = "connect #i to ".substr($parametric[$i],13);}
			}
		foreach my $i (0..@parametric-1)
		{
			if ($parametric[$i] =~ "connect #i to "){$parametric[$i] = "connect i to ".substr($parametric[$i],14);}
			if ($parametric[$i] =~ "connect #s to "){$parametric[$i] = "connect s to ".substr($parametric[$i],14);}
			}
		#print @parametric,"\n";

		my $temp_file = $path."analog/temp.txt";
		open (Temp, ">$temp_file");
		print Temp @parametric;
		close Temp;

		$analogfiles[$i] =~ s/(^\s+|\s+$)//g;
		rename($analogfiles[$i], $analogfiles[$i].".ori") or die "Failed to rename file: $!\n";
		rename($temp_file, $analogfiles[$i]) or die "Failed to rename file: $!\n";

		print Alog $analogfiles[$i]." has been updated,\t";

		my $value = "";
 		if ($VR eq "True")
 			{$value = system ("acomp -V $version $analogfiles[$i] > NULL");}
 		else
 			{$value = system ("acomp $analogfiles[$i] -l > NULL");}

		if ($value eq 0)
		{
			print Alog "[Object Produced]\n";				# compile passed
			print "\t\t\tObject Produced...\n";
			}
		else
		{
			print Alog "[Compile FAILED!!!]\n";				# compile failed
			print "\t\t\tCompile FAILED!!!\n";
			}

		}
	}
	print "\n\tauto debugged test: ",$swap_count,"\n";
	close Alog;
}


############################### extracting "analog" ######################################
sub extract_analog{
print  "	>>> extracting analog parameters ... \n";

my @analogfiles = ();
my $analogfiles1 = "";
my @parametric1 = ();
my @parametric2 = ();
my @parametric3 = ();
my @parametric4 = ();

print "\tPlease input 'Version' or tap 'ENTER' for 'Base': ";
my $version=<STDIN>;
chomp $version;

if ($version)
{
	print "\n";
	print "	Version is: $version\n";
	print "\n	Getting all COMP list...\n";
	@analogfiles = <$version/analog/*.o>;
	print "	>>> done ...\n";
	open (LIST, ">ALLCOMP_Statement_$version");
	open (UnExtFile, ">ALLCOMP_UnExtracted_$version");  
	}
else
{
	print "\n	Getting all COMP list...\n";
	@analogfiles = <analog/*.o>;
	print "	>>> done ...\n";
	open (LIST, ">ALLCOMP_Statement");
	open (UnExtFile, ">ALLCOMP_UnExtracted");
	}

foreach my $analogfiles (@analogfiles)
{
	$analogfiles =~ s/\.o//g;

	open COMP,"<$analogfiles";
# 	print $analogfiles,"\n";
#	$str =~ s/$/ ' 'x(N - length)/e		# 动态补空格。输出固定长度
	$analogfiles1 = $analogfiles;
	$analogfiles1 =~ s/$/ ' ' x (50 - length($analogfiles1))/e;
	while(my $line = <COMP>)
	{
		chomp($line);
		#print $line,"\n";
		$line =~ s/^ +//;		# clear head space
		$line =~ s/( +)/ /g; 	# clear multiple space
		next if (substr($line,0,1) eq "\!" or $line eq "" or $line eq "\r");
		my @type = split(" ", $line, 2);
		$type[0] =~ s/(^\s+|\s+$)//g;	# clear head space
		#*************************************** extract *********************************
		if ($type[0] =~ /^(fuse|jumper)$/ and $type[1] !~ '\"')
		{
		$type[1] =~ s/\s+//g;
		my @param = split(",", $type[1], 2);
			$type[0] =~ s/$/ ' ' x (15 - length($type[0]))/e;
			$param[0] =~ s/$/ ' ' x (15 - length($param[0]))/e;
			push(@parametric1, $analogfiles1.$type[0].$param[0].",".$param[1]."\n");
			last;
			}
		elsif ($type[0] =~ /^(zener|capacitor|resistor|inductor)$/ and $type[1] !~ '\"')
		{
		$type[1] =~ s/\s+//g;
		my @param = split(",", $type[1], 4);
			$type[0] =~ s/$/ ' ' x (15 - length($type[0]))/e;
			$param[0] =~ s/$/ ' ' x (15 - length($param[0]))/e;
			$param[1] =~ s/$/ ' ' x (15 - length($param[1]))/e;
			$param[2] =~ s/$/ ' ' x (15 - length($param[2]))/e;
			push(@parametric2, $analogfiles1.$type[0].$param[0].",".$param[1].",".$param[2].",".$param[3]."\n");
			last;
			}
		elsif ($type[0] =~ /^(diode)$/ and $type[1] !~ '\"')
		{
		$type[1] =~ s/\s+//g;
		my @param = split(",", $type[1], 3);
			$type[0] =~ s/$/ ' ' x (15 - length($type[0]))/e;
			$param[0] =~ s/$/ ' ' x (15 - length($param[0]))/e;
			$param[1] =~ s/$/ ' ' x (15 - length($param[1]))/e;
			push(@parametric3, $analogfiles1.$type[0].$param[0].",".$param[1].",".$param[2]."\n");
			last;
			}
		elsif ($type[0] =~ /^(fuse|jumper|diode|zener|capacitor|resistor|inductor)$/ and $type[1] =~ '\"')
		{
		$type[1] =~ s/\s+//g;
		my @param = split(",", $type[1], 4);
			$type[0] =~ s/$/ ' ' x (15 - length($type[0]))/e;
			$param[0] =~ s/$/ ' ' x (20 - length($param[0]))/e;
			$param[1] =~ s/$/ ' ' x (15 - length($param[1]))/e;
			$param[2] =~ s/$/ ' ' x (15 - length($param[2]))/e;
			push(@parametric4, $analogfiles1.$type[0].$param[0].",".$param[1].",".$param[2].",".$param[3]."\n");
			}
		elsif ($analogfiles =~ "discharge"){last;}
		elsif (eof){print UnExtFile $analogfiles1; print UnExtFile "\tby code NONE\n"; print "  Warning --> $analogfiles \thas no parameter found by code NONE!!!\n"; last;}
		elsif ($line =~ "powered"){print UnExtFile $analogfiles1; print UnExtFile "\tby code PWD\n"; print "  Warning --> $analogfiles \thas no parameter found by code PWD !!!\n"; last;}
		}
	}
print LIST "#>> Items ",'- ' x 19,">> Type ",'- ' x 3,">> Thres ",'- ' x 3,">> Parameters ",'- ' x 15,"\n";
print LIST sort @parametric1;
print LIST "#>> Items ",'- ' x 19,">> Type ",'- ' x 3,">> Nomial ",'- ' x 3,">> Hilim ",'- ' x 3,">> Lolim ",'- ' x 4,">> Parameters ",'- ' x 15,"\n";
print LIST sort @parametric2;
print LIST "#>> Items ",'- ' x 19,">> Type ",'- ' x 3,">> Hilim ",'- ' x 3,">> Lolim ",'- ' x 4,">> Parameters ",'- ' x 15,"\n";
print LIST sort @parametric3;
print LIST "#>> Items ",'- ' x 19,">> Type ",'- ' x 3,">> sub-name ",'- ' x 4,">> Hilim ",'- ' x 4,">> Lolim ",'- ' x 4,">> Parameters ",'- ' x 15,"\n";
print LIST sort @parametric4;
}


############################### updating "analog" ########################################
sub update_analog{
our $VR;
my $version = "";
my $dev = "";

(my $sec, my $min, my $hour, my $mday, my $mon, my $year,my $wday,my $yday,my $isdst) = localtime(time);
my $alog = ('ALLCOMP_LOG'."-".$hour.$min.$sec.'.log');

print "	Specify a file to be update (or tap 'Enter' for 'ALLComp_Statement'): ";
   my $file=<STDIN>;
   chomp $file;
    if ($file eq "")
       {$file = "ALLComp_Statement";}

open (LOG, ">$alog");

open (LIST, "<$file");
while(my $device = <LIST>)
{
	#print "\n";
	my $ori_param = "";
	my $new_param = "";
	next if (substr($device,0,3) eq "#>>");					# skip comments
	last if (index($device,"\"") != -1);					# multiple item
	my $dev = substr($device,0,index($device,"\ "));		# dev name
# 	print $dev,"\n";
	my $type = substr($device,50,15);						# dev type
	$type =~ s/\s//g;
# 	print $type,"\n";
	$new_param = substr($device,65,length($device) - 65);	# new dev parameter
	$new_param =~ s/\s//g;
# 	print $new_param,"\n";

	my $count = $dev =~ tr/\///;
	if($count == 2){$VR = "True"; $version = substr($dev,0,index($dev,"\/"));}
# 	print substr($dev,0,index($dev,"\/")),"\n";
	#****************************** Hilimit Check ****************************************
	if ($type eq "capacitor")
	{
		#print $dev,"\n";
		my $hilimit = (substr($device,81,15));
		$hilimit =~ s/\s+//g;
		#print $hilimit,"\n";
		if($hilimit > 40)
		{
			print "\tWarning !!! $dev High Limit is out of Range 40%.\n";
			print LOG "\tWarning !!! $dev High Limit is out of Range 40%.\n";
			}
		}
	elsif ($type eq "resistor")
	{
		#print $dev,"\n";
		my $hilimit = (substr($device,81,15));
		$hilimit =~ s/\s+//g;
		#print $hilimit,"\n";
		if($hilimit > 40)
		{
			print "\tWarning !!! $dev High Limit is out of Range 40%.\n";
			print LOG "\tWarning !!! $dev High Limit is out of Range 40%.\n";
			}
		}

	#****************************** Lolimit Check ****************************************
	if ($type eq "capacitor")
	{
		#print $dev,"\n";
		my $lolimit = (substr($device,97,15));
		$lolimit =~ s/\s+//g;
		#print $lolimit,"\n";
		if($lolimit > 40)
		{
			print "\tWarning !!! $dev Low Limit is out of Range 40%.\n";
			print LOG "\tWarning !!! $dev Low Limit is out of Range 40%.\n";
			}
		}
	elsif ($type eq "resistor")
	{
		#print $dev,"\n";
		my $lolimit = (substr($device,97,15));
		$lolimit =~ s/\s+//g;
		#print $lolimit,"\n";
		if($lolimit > 40)
		{
			print "\tWarning !!! $dev Low Limit is out of Range 40%.\n";
			print LOG "\tWarning !!! $dev Low Limit is out of Range 40%.\n";
			}
		}

	#****************************** compare parameters ***********************************

	open(ALL, "<$dev");
	open(Temp, ">temp");
	
	while(my $line = <ALL>)
	{
		$line =~ s/^ +//;
		if (substr($line,0,length($type)) eq $type)
		{
			$ori_param = substr($line,index($line,"\ "),length($line) - index($line,"\ "));		# ori parameter
			#print $line,"\n";
			$ori_param =~ s/\s//g;
			$new_param =~ s/\s//g;
			#print $ori_param,"\n";
			#print $new_param,"\n";
			if ($new_param eq $ori_param)
			{
				print Temp $type,"\ ",$ori_param,"\n";						# ori parameter
				}
			else
			{
				print Temp $type,"\ ",$new_param,"\n";						# new parameter
				print LOG $dev; print LOG "\tUpdated,\t";					# Log
				print $dev; print "\tUpdated,\t";							# display in screen
		  		}
		}
		else 
		{
			print Temp $line;												# normal line
			}
		}
	
	close ALL;
	close Temp;
	
	#****************************** update device ****************************************
	use Time::HiRes qw ( sleep time );

	if ($new_param ne $ori_param)
	{
		sleep (0.1);
		#print $ori_param,"\n";
		#print $new_param,"\n";
		rename $dev, "$dev~";
		rename "temp", $dev;
		my $value = "";
 		if ($VR eq "True")
 			{$value = system ("acomp -V $version $dev > NULL");}
 		else
 			{$value = system ("acomp $dev -l > NULL");}

		if ($value eq 0)
		{
			print LOG "[Object Produced]\n";				# compile passed
			print "[Object Produced]\n";
			}
		else
		{
			print LOG "[Compile FAILED!!!]\n";				# compile failed
			print "[Compile FAILED!!!]\n";
			}
		}
	unlink "temp";
	}
close LIST;


open (LIST, "<$file");
my $dev_ori = "";
my $dev_u = "";
############################### updating multiple "analog" item ##########################
while(my $device = <LIST>)
{if (index($device,"\"") != -1)
{
	#print "\n";
	my $ori_param = "";
	my $new_param = "";
	$dev = substr($device,0,index($device,"\ "));			# dev name
	my $subname = substr($device,index($device,"\"") + 1, rindex($device,"\"") - index($device,"\"") - 1);
# 	print $dev,"\n";
# 	print $subname."\n";
	my $type = substr($device,50,15);							# dev type
	$type =~ s/\s//g;
# 	print $type,"\n";
	$new_param = substr($device,85,length($device) - 85);		# new dev parameter
	$new_param =~ s/\s//g;
# 	print $new_param,"\n";

	#****************************** update device ****************************************
	use Time::HiRes qw ( sleep time );
	
	if($dev_u eq "updated" and $dev ne $dev_ori)
	{
		sleep (0.1);
		my $value = "";
		
 		if ($VR eq "True")
 			{$value = system ("acomp -V $version $dev > NULL");}
 		else
 			{$value = system ("acomp $dev -l > NULL");}
		
		if ($value eq 0)
		{
			print LOG "\t".$dev_ori."\t[Object Produced]\n";			# compile passed
			print "\t".$dev_ori."\t[Object Produced]\n";
			}
		else
		{
			print LOG "\t".$dev_ori."\t[Compile FAILED!!!]\n";			# compile failed
			print "\t".$dev_ori."\t[Compile FAILED!!!]\n";
			}
		}
	if($dev ne $dev_ori) { $dev_u = "";}
  
	#****************************** compare parameters ***********************************	
	if(!-e "$dev.ori")
	{
		rename $dev, "$dev.ori";
		copy ("$dev.ori", $dev) or warn "\t!!! failed to copy '$dev', $!";
		}
	
	open(ALL, "<$dev");
	open(Temp, ">temp");
	$dev_ori = $dev;

	while(my $line = <ALL>)
	{
		$line =~ s/^ +//;
		my $subname1 = substr($line,index($line,"\"") + 1, rindex($line,"\"") - index($line,"\"") - 1);
		# print $subname1."\n";
		# print substr($line,0,length($type)),"\n";
		if (substr($line,0,length($type)) eq $type and $subname eq $subname1)
		{
			$ori_param = substr($line,index($line,"\,"),length($line)- index($line,"\,"));		# ori parameter
			# print $line,"\n";
			$ori_param =~ s/\s//g;
			$new_param =~ s/\s//g;
			# print $ori_param,"\n";
			# print $new_param,"\n";
			if ($new_param eq $ori_param)
			{
				print Temp $type,"\ \"",$subname1, "\"", $ori_param,"\n";							# ori parameter
				}
			else
			{
				print Temp $type,"\ \"",$subname1, "\"",$new_param,"\n";							# new parameter
				print LOG $dev."/".$subname; print LOG "\tUpdated.\n";			# Log
				print $dev."/".$subname; print "\tUpdated.\n";					# display in screen
				$dev_u = "updated";
				}
			}
		else 
		{
			print Temp $line;																		# normal line
			}
		}
	close ALL;
	close Temp;

# 	rename $dev, "$dev~";
	rename "temp", $dev;
	}}

close LIST;

unlink "NULL";
close LOG;

print  "\n	Completed. Please check 'ALLCOMP_LOG' for updated items.\n";
}


############################### Bdg runner ###############################################
sub Bdg_runner{
(my $sec, my $min, my $hour, my $mday, my $mon, my $year,my $wday,my $yday,my $isdst) = localtime(time);
my $start_time = time();

#创建一个新的Excel文件
my $log_report = Excel::Writer::XLSX->new('CPK_report'."-".$hour.$min.$sec.'.xlsx');

#添加一个工作表
my $summary = $log_report-> add_worksheet('Summary');
my $workbook = $log_report-> add_worksheet('CPK_report');

$workbook-> freeze_panes(1,11);			# 冻结行、列
$workbook-> set_column(0,0,20);			# 设置列宽
$summary-> set_column(0,5,20);			# 设置列宽
$workbook-> set_row(0,20);				# 设置行高
$summary-> activate();					# 设置初始可见
#$workbook-> protect("drowssap");		# 设置密码
$workbook->set_header('&CUpdated at &D &T');	# 设置页脚
$workbook->set_landscape();				# 设置横排格式
$log_report->set_size(1680, 1180);		# 设置初始窗口尺寸


#新建一个格式
my $format_item = $log_report-> add_format(bold=>1, align=>'left', border=>1, size=>12, bg_color=>'cyan');
my $format_head = $log_report-> add_format(bold=>1, align=>'vcenter', border=>1, size=>12, bg_color=>'lime');
my $format_data = $log_report-> add_format(align=>'center', border=>1);
my $format_Fcpk = $log_report-> add_format(align=>'center', border=>1, bg_color=>'orange');
my $format_Pcpk = $log_report-> add_format(bold=>0, align=>'center', border=>1, bg_color=>'lime');
my $format_Hcpk = $log_report-> add_format(bold=>0, align=>'center', border=>1, bg_color=>'yellow');
my $format_FPY  = $log_report-> add_format(align=>'center', border=>1, num_format=> '10');

#写入文件头
my $row = 0; my $col = 0;
$summary-> write($row, $col, 'SN', $format_head);
$row = 0; $col = 1;
$summary-> write($row, $col, 'Results', $format_head);
$row = 0; $col = 2;
$summary-> write($row, $col, 'TestTime(s)', $format_head);
$row = 0; $col = 3;
$summary-> write($row, $col, 'Criteria', $format_item);
$row = 0; $col = 4;
$summary-> write($row, $col, 'Test Items', $format_item);

$row = 1; $col = 3;
$summary-> write($row, $col, 'CPK >= 1.33', $format_data);
$row = 2; $col = 3;
$summary-> write($row, $col, 'CPK < 1.33', $format_data);
$row = 3; $col = 3;
$summary-> write($row, $col, 'FPY', $format_data);

$row = 1; $col = 4;
$summary-> write($row, $col, '=COUNTIFS(CPK_report!K2:K9999,">=1.33")', $format_data);
$row = 2; $col = 4;
$summary-> write($row, $col, '=COUNTIFS(CPK_report!K2:K9999,"<1.33")', $format_data);
$row = 3; $col = 4;
$summary-> write_formula(3, 4, "=1-(E3/E2)", $format_FPY);  #输出FPY

# my $chart = $log_report-> add_chart( type => 'pie', embedded => 1 );
# $chart->add_series(
#     name       => '=Summary!$B$1',
#     categories => '=Summary!$D$2:$D$3',
#     values     => '=Summary!$E$2:$E$3',
#     data_labels => {value => 1},
# );
# $summary->insert_chart('D7',$chart,0,0,1.0,1.6);

$row = 0; $col = 0;
$workbook-> write($row, $col, 'Test Items', $format_head);
$row = 0; $col = 1;
$workbook-> write($row, $col, 'TYPE', $format_head);
$row = 0; $col = 2;
$workbook-> write($row, $col, 'Nominal Value', $format_head);
$row = 0; $col = 3;
$workbook-> write($row, $col, 'HiLimit', $format_head);
$row = 0; $col = 4;
$workbook-> write($row, $col, 'LowLimit', $format_head);
$row = 0; $col = 5;
$workbook-> write($row, $col, 'Max (Marginal)', $format_head);
$row = 0; $col = 6;
$workbook-> write($row, $col, 'Min (Marginal)', $format_head);
$row = 0; $col = 7;
$workbook-> write($row, $col, 'Average', $format_head);
$row = 0; $col = 8;
$workbook-> write($row, $col, 'StdDev', $format_head);  #Standard deviation of data
$row = 0; $col = 9;
$workbook-> write($row, $col, 'CP', $format_head);
$row = 0; $col = 10;
$workbook-> write($row, $col, 'CPK', $format_head);


$workbook-> conditional_formatting('J2:K9999',
{
	type     => 'cell',
 	criteria => 'between',
 	minimum  => 1.33,
 	maximum  => 10,
 	format   => $format_Pcpk,
	});

$workbook-> conditional_formatting('J2:K9999',
{
	type     => 'cell',
 	criteria => 'greater than',
 	value    => 10,
 	format   => $format_Hcpk,
	});

$workbook-> conditional_formatting('J2:K9999',
{
	type     => 'cell',
 	criteria => 'greater than',
 	value    => 0,
 	format   => $format_Fcpk,
	});

$workbook-> write_formula(1, 5, "=MAX(L2:AAA2)", $format_data);  		#输出Max
$workbook-> write_formula(1, 6, "=MIN(L2:AAA2)", $format_data);			#输出Min
$workbook-> write_formula(1, 7, "=AVERAGE(L2:AAA2)", $format_data);  	#输出Average
$workbook-> write_formula(1, 8, "=STDEV(L2:AAA2)", $format_data);  		#输出标准差
$workbook-> write_formula(1, 9, "=IF(I2>0,(D2-E2)/6/I2)", $format_data);  #输出CP
$workbook-> write_formula(1, 10, "=MIN((D2-H2),(H2-E2))/I2/3", $format_data);  #输出CPK

######################### create head ####################################################
$row = 1;
$col = 0;
my $colSN = 11;
my $log_counter = 0;
my $board = "";
my $headN = "";
my $line = "";
my $title = "";
my $subtitle = "";
my @Titles = ();

print "=> extracting header ... ","\n";

my @analogfiles = <*.log>;
foreach my $analogfiles (@analogfiles)
{
	open LogN,"<$analogfiles";
	$log_counter++;

	if ($log_counter == 1)
	{
		open NLog,">head";

		$workbook-> write(0, $colSN, $analogfiles, $format_head);	#写入第一个log name
    	$colSN++;

		while(my $line = <LogN>)
    	{
    		chomp $line;
    		my @string = split('\|', $line);
			if ($line =~ "\@BTEST")
    		{
    			#print $string[12]."\n";
    			if ($string[12] eq "1"){$board = "single";}
    			else {$board = "panel";}
    			print $board;
				print "\n".$analogfiles;
    			}

    	elsif ($line =~ "\@BLOCK")
       	{
       		$col = 0;
       		$headN = $string[1];
       		if($board eq "panel"){$headN = substr($string[1], index($string[1],"%")+1);}
       		#print "\n".$headN;
       		#$workbook-> write($row, $col, $headN, $format);
       		#$row++;
       		}

        elsif ($line =~ "\@LIM2" and $line =~ "\@A-JUM")    # Jumper
       	{
       		#print $headN, "\r";
       		print NLog $headN, "\r";
       		push(@Titles, $headN);
       		$workbook-> write($row, $col, $headN, $format_item);					#输出测试名，单项测试
			$workbook-> write($row, 1, substr($line,4,3), $format_data);			#输出TYPE
       		$workbook-> write($row, 3, $string[3], $format_data);					#输出上限值
       		$workbook-> write($row, 4, substr($string[4],0,13), $format_data);		#输出下限值
			$workbook-> write_formula($row, 5, "=MAX(L".($row+1).":AAA".($row+1).")", $format_data);  #输出Max
			$workbook-> write_formula($row, 6, "=MIN(L".($row+1).":AAA".($row+1).")", $format_data);  #输出Min
			$workbook-> write_formula($row, 7, "=AVERAGE(L".($row+1).":AAA".($row+1).")", $format_data);  #输出Average
			$workbook-> write_formula($row, 8, "=STDEV(L".($row+1).":AAA".($row+1).")", $format_data);  #输出标准差
			$workbook-> write_formula($row, 9, "=IF(I".($row+1).">0,(D".($row+1)."-E".($row+1).")/6/I".($row+1).")", $format_data);  #输出CP
			$workbook-> write_formula($row, 10, "=MIN((D".($row+1)."-H".($row+1)."),(H".($row+1)."-E".($row+1)."))/I".($row+1)."/3", $format_data);  #输出CPK

       		$workbook-> conditional_formatting($row, 5,
    		{
    			type     => 'cell',
    		 	criteria => 'greater than',
    		 	value    => "=D".($row+1)."*0.75",
    		 	format   => $format_Fcpk,
    			});
       		$row++;
       		}
        elsif ($line =~ "\@LIM2" and $line =~ "\@A-DIO" and scalar @string == 5)    # Diode
       	{
       		#print $headN, "\r";
       		print NLog $headN, "\r";
       		push(@Titles, $headN);
       		$workbook-> write($row, $col, $headN, $format_item);					# 输出测试名，单项测试
			$workbook-> write($row, 1, substr($line,4,3), $format_data);			# 输出TYPE
       		$workbook-> write($row, 3, $string[3], $format_data);
       		$workbook-> write($row, 4, substr($string[4],0,13), $format_data);
			$workbook-> write_formula($row, 5, "=MAX(L".($row+1).":AAA".($row+1).")", $format_data);  # 输出Max
			$workbook-> write_formula($row, 6, "=MIN(L".($row+1).":AAA".($row+1).")", $format_data);  # 输出Min
			$workbook-> write_formula($row, 7, "=AVERAGE(L".($row+1).":AAA".($row+1).")", $format_data);  # 输出Average
			$workbook-> write_formula($row, 8, "=STDEV(L".($row+1).":AAA".($row+1).")", $format_data);  # 输出标准差
			$workbook-> write_formula($row, 9, "=IF(I".($row+1).">0,(D".($row+1)."-E".($row+1).")/6/I".($row+1).")", $format_data);  #输出CP
			$workbook-> write_formula($row, 10, "=MIN((D".($row+1)."-H".($row+1)."),(H".($row+1)."-E".($row+1)."))/I".($row+1)."/3", $format_data);  #输出CPK

       		$workbook-> conditional_formatting($row, 5,
    		{
    			type     => 'cell',
    		 	criteria => 'greater than',
    		 	value    => "=D".($row+1)."-(D".($row+1)."-E".($row+1).")*0.2",
    		 	format   => $format_Fcpk,
    			});

       		$workbook-> conditional_formatting($row, 6,
    		{
    			type     => 'cell',
    		 	criteria => 'less than',
    		 	value    => "=E".($row+1)."+(D".($row+1)."-E".($row+1).")*0.2",
    		 	format   => $format_Fcpk,
    			});
    		
       		$row++;
       		}
        elsif ($line =~ "\@LIM2" and $line =~ "\@A-DIO" and scalar @string == 6)    # Diode
       	{
       		$subtitle = substr ($line, 24, rindex($line,"\{\@LIM") - 24);
       		#print "\n".$headN."/".$subtitle; 
       		print NLog $headN."/".$subtitle, "\n";
       		push(@Titles, $headN."/".$subtitle);
       		$workbook-> write($row, $col, $headN."/".$subtitle, $format_item);		# 输出测试名，多项测试
			$workbook-> write($row, 1, substr($line,4,3), $format_data);  			# 输出TYPE
       		$workbook-> write($row, 3, $string[4], $format_data);
       		$workbook-> write($row, 4, substr($string[5],0,13), $format_data);
			$workbook-> write_formula($row, 5, "=MAX(L".($row+1).":AAA".($row+1).")", $format_data);  # 输出Max
			$workbook-> write_formula($row, 6, "=MIN(L".($row+1).":AAA".($row+1).")", $format_data);  # 输出Min
			$workbook-> write_formula($row, 7, "=AVERAGE(L".($row+1).":AAA".($row+1).")", $format_data);  # 输出Average
			$workbook-> write_formula($row, 8, "=STDEV(L".($row+1).":AAA".($row+1).")", $format_data);  # 输出标准差
			$workbook-> write_formula($row, 9, "=IF(I".($row+1).">0,(D".($row+1)."-E".($row+1).")/6/I".($row+1).")", $format_data);  #输出CP
			$workbook-> write_formula($row, 10, "=MIN((D".($row+1)."-H".($row+1)."),(H".($row+1)."-E".($row+1)."))/I".($row+1)."/3", $format_data);  #输出CPK

       		$workbook-> conditional_formatting($row, 5,
    		{
    			type     => 'cell',
    		 	criteria => 'greater than',
    		 	value    => "=D".($row+1)."-(D".($row+1)."-E".($row+1).")*0.2",
    		 	format   => $format_Fcpk,
    			});

       		$workbook-> conditional_formatting($row, 6,
    		{
    			type     => 'cell',
    		 	criteria => 'less than',
    		 	value    => "=E".($row+1)."+(D".($row+1)."-E".($row+1).")*0.2",
    		 	format   => $format_Fcpk,
    			});
    		
       		$row++;
       		}
        elsif ($line =~ "\@LIM2" and scalar @string == 5)    # single step Volts
       	{
       		#print $headN, "\r";
       		print NLog $headN, "\r";
       		push(@Titles, $headN);
       		$workbook-> write($row, $col, $headN, $format_item);					# 输出测试名，单项测试
			$workbook-> write($row, 1, substr($line,4,3), $format_data);			# 输出TYPE
       		$workbook-> write($row, 3, $string[3], $format_data);
       		$workbook-> write($row, 4, substr($string[4],0,13), $format_data);
			$workbook-> write_formula($row, 5, "=MAX(L".($row+1).":AAA".($row+1).")", $format_data);  # 输出Max
			$workbook-> write_formula($row, 6, "=MIN(L".($row+1).":AAA".($row+1).")", $format_data);  # 输出Min
			$workbook-> write_formula($row, 7, "=AVERAGE(L".($row+1).":AAA".($row+1).")", $format_data);  # 输出Average
			$workbook-> write_formula($row, 8, "=STDEV(L".($row+1).":AAA".($row+1).")", $format_data);  # 输出标准差
			$workbook-> write_formula($row, 9, "=IF(I".($row+1).">0,(D".($row+1)."-E".($row+1).")/6/I".($row+1).")", $format_data);  #输出CP
			$workbook-> write_formula($row, 10, "=MIN((D".($row+1)."-H".($row+1)."),(H".($row+1)."-E".($row+1)."))/I".($row+1)."/3", $format_data);  #输出CPK

       		$workbook-> conditional_formatting($row, 5,
    		{
    			type     => 'cell',
    		 	criteria => 'greater than',
    		 	value    => "=D".($row+1)."-(D".($row+1)."-E".($row+1).")*0.2",
    		 	format   => $format_Fcpk,
    			});
       		$workbook-> conditional_formatting($row, 6,
    		{
    			type     => 'cell',
    		 	criteria => 'less than',
    		 	value    => "=E".($row+1)."+(D".($row+1)."-E".($row+1).")*0.2",
    		 	format   => $format_Fcpk,
    			});
    		
       		$row++;
       		}
        elsif ($line =~ "\@LIM3" and scalar @string == 6)     # LCR
       	{
       		#print $headN, "\r";
       		print NLog $headN, "\r";
       		push(@Titles, $headN);
       		$workbook-> write($row, $col, $headN, $format_item);								# 输出测试名，单项测试
			$workbook-> write($row, 1, substr($line,4,3), $format_data);						# 输出TYPE
       		$workbook-> write($row, 2, substr($line,index($line,"\@LIM")+6,13), $format_data);  # 输出正常值
       		$workbook-> write($row, 3, $string[4], $format_data);
       		$workbook-> write($row, 4, substr($string[5],0,13), $format_data);
			$workbook-> write_formula($row, 5, "=MAX(L".($row+1).":AAA".($row+1).")", $format_data);  # 输出Max
			$workbook-> write_formula($row, 6, "=MIN(L".($row+1).":AAA".($row+1).")", $format_data);  # 输出Min
			$workbook-> write_formula($row, 7, "=AVERAGE(L".($row+1).":AAA".($row+1).")", $format_data);  # 输出Average
			$workbook-> write_formula($row, 8, "=STDEV(L".($row+1).":AAA".($row+1).")", $format_data);  # 输出标准差
			$workbook-> write_formula($row, 9, "=IF(I".($row+1).">0,(D".($row+1)."-E".($row+1).")/6/I".($row+1).")", $format_data);  #输出CP
			$workbook-> write_formula($row, 10, "=MIN((D".($row+1)."-H".($row+1)."),(H".($row+1)."-E".($row+1)."))/I".($row+1)."/3", $format_data);  #输出CPK

			#Hli = 41.25-(41.25-28.05)*0.25
			#Lli = 28.05+(41.25-28.05)*0.25
       		$workbook-> conditional_formatting($row, 5,
    		{
    			type     => 'cell',
    		 	criteria => 'greater than',
    		 	value    => "=D".($row+1)."-(D".($row+1)."-E".($row+1).")*0.2",
    		 	format   => $format_Fcpk,
    			});
       		$workbook-> conditional_formatting($row, 6,
    		{
    			type     => 'cell',
    		 	criteria => 'less than',
    		 	value    => "=E".($row+1)."+(D".($row+1)."-E".($row+1).")*0.2",
    		 	format   => $format_Fcpk,
    			});
    		
       		$row++;
       		}

       	elsif ($line =~ "\@A-")        # Volts
       	{
       		$subtitle = substr ($line, 24, rindex($line,"\{\@LIM") - 24);
       		#print "\n".$headN."/".$subtitle; 
       		print NLog $headN."/".$subtitle, "\n";
       		push(@Titles, $headN."/".$subtitle);
       		$workbook-> write($row, $col, $headN."/".$subtitle, $format_item);		# 输出测试名，多项测试
			$workbook-> write($row, 1, substr($line,4,3), $format_data);  			# 输出TYPE
       		$workbook-> write($row, 3, $string[4], $format_data);
       		$workbook-> write($row, 4, substr($string[5],0,13), $format_data);
			$workbook-> write_formula($row, 5, "=MAX(L".($row+1).":AAA".($row+1).")", $format_data);  # 输出Max
			$workbook-> write_formula($row, 6, "=MIN(L".($row+1).":AAA".($row+1).")", $format_data);  # 输出Min
			$workbook-> write_formula($row, 7, "=AVERAGE(L".($row+1).":AAA".($row+1).")", $format_data);  # 输出Average
			$workbook-> write_formula($row, 8, "=STDEV(L".($row+1).":AAA".($row+1).")", $format_data);  # 输出标准差
			$workbook-> write_formula($row, 9, "=IF(I".($row+1).">0,(D".($row+1)."-E".($row+1).")/6/I".($row+1).")", $format_data);  #输出CP
			$workbook-> write_formula($row, 10, "=MIN((D".($row+1)."-H".($row+1)."),(H".($row+1)."-E".($row+1)."))/I".($row+1)."/3", $format_data);  #输出CPK

       		$workbook-> conditional_formatting($row, 5,
    		{
    			type     => 'cell',
    		 	criteria => 'greater than',
    		 	value    => "=D".($row+1)."-(D".($row+1)."-E".($row+1).")*0.2",
    		 	format   => $format_Fcpk,
    			});
       		$workbook-> conditional_formatting($row, 6,
    		{
    			type     => 'cell',
    		 	criteria => 'less than',
    		 	value    => "=E".($row+1)."+(D".($row+1)."-E".($row+1).")*0.2",
    		 	format   => $format_Fcpk,
    			});
			
       		$row++;
       		}
    	}close NLog;}
    elsif($log_counter != 1)
    {
    	print "\n".$analogfiles;
    	#print "\n"." # # # ";
    	$workbook-> write(0, $colSN, $analogfiles, $format_head);		#写入剩余log name
    	$colSN++;
    	}
close LogN;
}

print "\n   Scale: ",scalar @Titles,"\n";
# print @Titles,"\n";

########################## create data ###################################################
print "=> extracting data ... ","\n"; 

my %matrix;
my $value;

%matrix = map { $_ => $Titles[$_] } 0..$#Titles;			# convert array to hash
# my @keys = keys %matrix;
# my $size = @keys;
# print "2 - 哈希大小: $size\n";

foreach my $key (values %matrix) {$matrix{$key} = "";}		# initialize values
# my @keys = keys %matrix;
# my $size = @keys;
# print "2 - 哈希大小: $size\n";
# 
# foreach my $key (keys %matrix) {
#     print $matrix{$key}, "\n";
# }


$row = 0;
$col = 1;
@analogfiles = <*.log>;
foreach my $analogfiles (@analogfiles)		#log
{
	my $counter = 1;
	open LogN,"<$analogfiles";

	if ($board eq 'single'){
	while($line = <LogN>)	
    {
    	chomp $line;
    	next if (substr($line,0,3) ne "\{\@B");
    	next if (substr($line,0,5) eq "\{\@RPT");
    	last if (eof);
    	#print $line,"\n";
    	#print $title,"\n";
    	#print substr($line,8,length($line)-11),"\n";
		my @string = split('\|', $line);
		next if scalar @string < 3;
		next if ($string[2] ne "00");
		#print $string[1];

		if ($string[0] eq "\{\@BTEST" and $counter == 1)	# 写SN到Summary中
		{
			$summary-> write($col, 0, $string[1], $format_item);
			if($string[2] eq "00"){$summary-> write($col, 1, "Pass", $format_Pcpk);}
			else{$summary-> write($col, 1, "Fail", $format_Fcpk);}
			$summary-> write($col, 2, $string[4], $format_data);
			$counter++;
			$col++;
			}
    	#elsif ($title !~ "\/" and $string[1] eq $title and $string[2] eq "00")		# 单项测试数据
    	elsif (exists($matrix{$string[1]}))			# 单项测试数据
		{
			while($line = <LogN>)
			{
				chomp $line;
				if ($line =~ "\@A-")	#result line matching
				{
					#print $line."\n";
					$value = $matrix{$string[1]};
					#print $value,"\n";
					$matrix{$string[1]} = $value.substr ($line,10,13)."\t";
					#$workbook-> write($row, $col, substr ($line,10,13), $format_data); 
					last;
					}
				}
			}
		#elsif ($title =~ "\/" and $string[1] eq substr($title,0,index($title,"\/")) and $string[2] eq "00")		# 多项测试数据
		else
		{
			while($line = <LogN>)
			{
				chomp $line;
				last if ($line eq "\}");
				last if (eof);
				my @string1 = split('\|', $line);
				#print "/".substr($string1[3],0,length($string1[3])-6),"\n";
				if ($line =~ "\@A-"	and exists($matrix{$string[1]."/".substr($string1[3],0,length($string1[3])-6)}))	#subname matching
				{
					#print $line."\n";
					$value = $matrix{$string[1]."/".substr($string1[3],0,length($string1[3])-6)};
					#print $value,"\n";
					$matrix{$string[1]."/".substr($string1[3],0,length($string1[3])-6)} = $value.substr ($line,10,13)."\t";
					#$workbook-> write($row, $col, substr ($line,10,13), $format_data); 
					}
				}
			}
		}
	}

	if ($board eq 'panel'){
	while($line = <LogN>)	
    {
    	chomp $line;
    	next if (substr($line,0,3) ne "\{\@B");
    	next if (substr($line,0,5) eq "\{\@RPT");
    	last if (eof);
    	
    	#print $line,"\n";
    	my @string = split('\|', $line);
    	next if scalar @string < 3;
    	next if ($string[2] ne "00");
    	$string[1] = substr($string[1],index($string[1],"%")+1);
		#print $string[1],"\n";

		if ($string[0] eq "\{\@BTEST" and $counter == 1)	# 写SN到Summary中
		{
			$summary-> write($col, 0, $string[1], $format_item);
			if($string[2] eq "00"){$summary-> write($col, 1, "Pass", $format_Pcpk);}
			else{$summary-> write($col, 1, "Fail", $format_Fcpk);}
			$summary-> write($col, 2, $string[4], $format_data);
			$counter++;
			$col++;
			}

		#elsif ($title !~ "\/" and substr($string[1],index($string[1],"%")+1) eq $title and $string[2] eq "00")	# 单项测试数据
		elsif (exists($matrix{$string[1]}))	# 单项测试数据
		{
			while($line = <LogN>)
			{
				chomp $line;
				if ($line =~ "\@A-")	#result line matching
				{
					#print $line."\n";
					$value = $matrix{$string[1]};
					#print $value,"\n";
					$matrix{$string[1]} = $value.substr ($line,10,13)."\t";
					#$workbook-> write($row, $col, substr ($line,10,13), $format_data); 
					#print substr($line,10,13)."\n";
					last;
					}
				}
			}
		#elsif ($title =~ "\/" and substr($string[1], index($string[1],"%")+1) eq substr($title,0,index($title,"\/")) and $string[2] eq "00")	# 多项测试数据
		else
		{
			while($line = <LogN>)
			{
				chomp $line;
				last if ($line eq "\}");
				last if (eof);
				my @string1 = split('\|', $line);
				#print "/".substr($string1[3],0,length($string1[3])-6),"\n";
				if ($line =~ "\@A-"	and exists($matrix{$string[1]."/".substr($string1[3],0,length($string1[3])-6)}))	#subname matching
				{
					#print $line."\n";
					$value = $matrix{$string[1]."/".substr($string1[3],0,length($string1[3])-6)};
					#print $value,"\n";
					$matrix{$string[1]."/".substr($string1[3],0,length($string1[3])-6)} = $value.substr ($line,10,13)."\t";
					#$workbook-> write($row, $col, substr ($line,10,13), $format_data); 
					}
				}
			}
		}
	}
	close LogN;
	}

# print "PPDCIN_AON/OUTPUT value is: $matrix{'PPDCIN_AON/OUTPUT'} \n";
# print "rn304 value is: $matrix{'rn304'} \n";
# 
# my @group = split("\t",$matrix{'PPDCIN_AON/OUTPUT'});
# $size = @group;
# print "z - 哈希大小: $size\n";

# $workbook-> write_row (2, 11, \@group, $format_data); 


foreach my $i (0..@Titles-1)		# output array to Excel.
{
# 	print $Titles[$i],"\n";
	my @group = split("\t",$matrix{$Titles[$i]});
	$workbook-> write_row ($i+1, 11, \@group, $format_data); 
	}

# unlink "head";
$log_report->close();

my $end_time = time();
my $duration = $end_time - $start_time;
printf "	runtime: %.4f Sec\n", $duration;

}


#-----------------------------------------------------------------------------------------
print "\n\t>>> done ...\n\n";
# system 'pause';