#!/usr/bin/perl
print "\n*****************************************************************************\n";
print "  3070 auto debug script <v0.94>\n";
print "  Author: Noon Chen\n";
print "  A Professional Tool for Test.\n";
print "  ",scalar localtime;
print "\n*****************************************************************************\n";

#-----------------------------------------------------------------------------------------
# ver 0.6 has updated and validated for pins, shorts auto debug. 2025/2/17
# ver 0.7 has optimized shorts processing bugs. 2025/2/18
# ver 0.8 has updated for analog auto debug. 2025/2/19
# ver 0.9 has updated for multiple board 'pins','shorts','analog'.
# ver 0.91 has optimized for multiple board tacitly approve or covert selection. 2025/2/21
# ver 0.93 has optimized read file error handling. 2025/2/25
# ver 0.94 has added log output. 2025/2/28

use strict;
use warnings;
use List::Util 'uniq';

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

print "\n";
print  "	"."!----!" x 10,"\n";
print  "	>>> make sure there is KGB in fixture and all wiring is OK.\n";
print  "	"."!----!" x 10,"\n";

############################### extract fixed nodes ######################################
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

#-----------------------------------------------------------------------------------------
print "	1, auto debug pins\n";
print "	2, auto debug shorts\n";
print "	3, auto debug analog\n";
print "	>>> Please select an item to carry out auto debug: ";
   my $option=<STDIN>;
   chomp $option;
print "\n";

if ($option =~ "#")
{
	$num = substr($option,2); 
	$option = substr($option,0,1); 
# 	print $option,$num,"\n";
	}

if ($option == 1) {debugPins();}
if ($option == 2) {debugShorts();}
if ($option == 3) {debugAnalog();}

############################### auto debug "pins" ########################################
sub debugPins{
print  "	>>> debugging Pins ... \n";

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
# 				print substr($pins,0, index($pins,'%')+1),"\n";
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
if($pinsCount > 0)
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
print  "	>>> debugging Shorts ... \n";

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
# 		print "$array\n";
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
			if(substr($array,0,1) eq "!"){
				$array =~ s/(^\s+|\s+$)//g;                     	#clear all spacing
				# print $array,"\n";
				push(@untestNodes, $array."\n");
				}
			elsif(substr($array,0,5) eq "nodes"){
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
# 						print $Fnode."\|".$Tnode."\|".$comdev."\n";
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
# 				print $thres."\|".$Fnode."\|".$Tnode."\|".$comdev."\n";

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
# 		print $nodeList[0].$nodeList[1];
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
# 	print $testList[2],"\n";
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
print  "	>>> debugging Analog ... \n";

(my $sec, my $min, my $hour, my $mday, my $mon, my $year,my $wday,my $yday,my $isdst) = localtime(time);
my $alog = ('auDebug'."-".$hour.$min.$sec.'.log');
open (Alog, ">$alog");

my @analogfiles = ();
my $path = "";
my $swap_count = 0;

print "\tPlease input 'Version' or press 'ENTER' to continue: ";
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
# 		print $array;
		last if (substr($array,0,4) eq "test");
		last if ($array =~ "to ground");
		last if ($array =~ "to pins");
		if (substr($array,0,13) eq "connect i to " or substr($array,0,13) eq "connect s to ")	# all bus
		{
			$array =~ s/( +)/ /g; 
# 			print "\t",$array;
			push(@parametric, $array);
			my @ibus = split('\"', $array);
			
			if ($multiBoard == 1)										# for multiboard
			{
				$ibus[1] = substr($ibus[1],2);
# 				print $ibus[1],"\n";
				}
			
			if ($ibus[1] eq $ground and $ibus[0] eq "connect s to ")			# s bus is ground, no swap action.
			{
				$swap = 3;
				$GND = 3;
# 				print "\t S-G ",$ibus[1],"\n";
				next;
				}
			elsif (grep{ $_ eq $ibus[1]} @fixednode and $ibus[1] eq $ground and $array =~ "connect i to ")		# i bus is ground, swap it anyway.
			{
				$swap = 1;
				$GND = 1;
# 				print "\t i-G ",$ibus[1],"\n";
				}
			elsif (grep{ $_ eq $ibus[1]} @fixednode and $array =~ "connect s to ")			# s bus is fixed node.
			{
				$swap = 1;
				$fixed++;
# 				print "\t S-F ",$ibus[1],"\n";
				}
			elsif (grep{ $_ eq $ibus[1]} @fixednode and $array =~ "connect i to ")			# i bus is fixed node.
			{
				$swap = 1;
				$fixed++;
# 				print "\t i-F ",$ibus[1],"\n";
				}
			elsif(grep{ $_ ne $ibus[1]} @fixednode and $array =~ "connect i to ")			# other signal
			{
				$fixed = 3;
# 				print "----\t",$ibus[1],"\n";
				next;
				}
			}
		else	# comments and parametric.
		{
# 			print $array;
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
# 		print @parametric,"\n";
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
# 		print @parametric,"\n";

		my $temp_file = $path."analog/temp.txt";
		open (Temp, ">$temp_file");
			print Temp @parametric;
		close Temp;

		$analogfiles[$i] =~ s/(^\s+|\s+$)//g;
		rename($analogfiles[$i], $analogfiles[$i].".ori") or die "Failed to rename file: $!\n";
		rename($temp_file, $analogfiles[$i]) or die "Failed to rename file: $!\n";
		print Alog $analogfiles[$i]." has been updated.\n";
		}
	}
	print "\n\tauto debugged test: ",$swap_count,"\n";
	close Alog;
}

print "\n\t>>> done ...\n\n";
#system 'pause';