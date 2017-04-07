#!/bin/bash

## variable
EXTRACT="/tmp/extract"
COMBINE="/tmp/combine"
num=0

## extract file tar.xz
var (){
	LIST=($(tar tf $TAR))
	HOST=$(IFS=$'\n';echo "${LIST[*]}"|grep "sos_commands/general/hostname")
	SAR=$(IFS=$'\n';echo "${LIST[*]}"|grep "var/log/sa/$")
	MEMINFO=$(IFS=$'\n';echo "${LIST[*]}"|grep "proc/meminfo")
	CPUINFO=$(IFS=$'\n';echo "${LIST[*]}"|grep "proc/cpuinfo")
	DF=$(IFS=$'\n';echo "${LIST[*]}"|grep "sos_commands/filesys/df_-al")
	ETH=$(IFS=$'\n';echo "${LIST[*]}"|grep "ifcfg-eth")
}

cleanup (){
	rm -rf $EXTRACT
	rm -rf $COMBINE
}

#if [ -d $EXTRACT ];then
#	cleanup;
#fi

rule (){
echo "this is script to combine sosreport"
read -p "dev/prod :" devprod;
read -p "path directory : " dest
}

extract (){
mkdir -p $EXTRACT
echo "extracting sosreport"
for TAR in $dest/*.tar.xz;do var
tar xf $TAR -C $EXTRACT $HOST $SAR $MEMINFO $CPUINFO $DF $ETH
done
}

servername (){
	HOSTNAME=($(cat $EXTRACT/*/sos_commands/general/hostname))
}

bulan (){
	lmonth=$(date -d "$(stat $(ls $dest/*.tar.xz|head -n1)|grep Mod|awk '{print $2}')" +%B)

}
combine (){
mkdir -p $COMBINE
echo "combine"
	for host in ${HOSTNAME[*]};do
		echo $host
		mkdir -p $COMBINE/$host/sar
		for sar in $EXTRACT/$host-*;do
			if [ -d $sar/var/log/sa ];then
				list=$(ls -l -d -1 $sar/var/log/sa/*|grep "sar"|awk '{print $9}');
				cp $list $COMBINE/$host/sar
			else
				echo "directory report/var/log/sa not found"
				echo "report for $host cannot proccess !!!"
			fi
		done
	done
}

cpfile (){
for host in ${HOSTNAME[*]};do
	dest=$(ls $EXTRACT/|grep $host|head -n1)
	cp -rf $EXTRACT/$dest/{etc,proc,sos_commands/filesys/df_-al} $COMBINE/$host
done
}

merger (){
if [ -d report/$lmonth/$devprod/sar ];then
	rm -rf report/$lmonth/$devprod/sar
	mkdir -p report/$lmonth/$devprod/sar
else
	mkdir -p report/$lmonth/$devprod/sar
fi
for host in ${HOSTNAME[*]};do
if [[ $(ls -A $COMBINE/$host/sar) ]];then
perl - $COMBINE/$host/sar/* <<'__HERE__'>> report/$lmonth/$devprod/sar/$host
while (<>)
{
    while (m%(\d\d)(?::\d\d:\d\d) (AM|PM)%)
    {
        my $hh = $1;
        $hh -= 12 if ($2 eq 'AM' && $hh == 12);
        $hh += 12 if ($2 eq 'PM' && $hh != 12);
        s%(\d\d)(:\d\d:\d\d) (?:AM|PM)%$hh$2%;
    }
    print;
}
__HERE__
else
	echo "directory report/var/log/sa not found"
	echo "report for $host cannot proccess !!!"
fi
done
}

addr (){
unset INTERFACE eth COUNT IP
INTERFACE=($(grep "^IPADDR" $REPORT/etc/sysconfig/network-scripts/ifcfg-eth* -lr))
eth=($(IFS=$'\n';echo "${INTERFACE[*]}"|cut -d\/ -f8|sed 's/ifcfg-//g'))
COUNT=$(IFS=$'\n';echo "${INTERFACE[*]}"|wc -l|awk '{print $1-1}')
for listeth in ${INTERFACE[*]};do \
IP+=($(cat $listeth|grep IPADDR|cut -d\= -f2));\
done
}

## function
memory (){
	# memory function
	mkdir /tmp/sar
	for sar in $(ls -tr $REPORT/sar/*|grep sar);do
	grep -A 200 "kbmemfree" $sar|sed -e '/Average/q'|sed '/Average\|kb/d' >> /tmp/sar/$HOSTNAME;\
	done
	memlist=($(awk '{print $4}' /tmp/sar/$HOSTNAME|sort -nr))
	sum=$( IFS="+"; bc <<< "${memlist[*]}" )
	line=$(IFS=$'\n'; echo "${memlist[*]}"|wc -l)
	## variable
	memtotal=$(cat $REPORT/proc/meminfo |head -n1|awk '{print "scale=2;"$2"/1048576"}'|bc)
	maxmem=$(echo "scale=2;${memlist[0]}/1048576"|bc|sed 's/^\./0./')
	minmem=$(echo "scale=2;${memlist[-1]}/1048576"|bc|sed 's/^\./0./')
	avemem=$(echo "scale=2;$sum/$line/1048576"|bc|sed 's/^\./0./')
	rm -rf /tmp/sar
}

cpu (){
	## total core
	core=$(grep "processor" $REPORT/proc/cpuinfo|wc -l)
	## load cpu/ source from sar
	cpulist=($(grep " all " $REPORT/sar/*|sed '/Average\|kb/d'|awk '{print $4}'|sort -nr))
	sum=$( IFS="+"; bc <<< "${cpulist[*]}" )
	line=$(IFS=$'\n'; echo "${cpulist[*]}"|wc -l)
	## variable
	maxcpu="${cpulist[0]}"
	mincpu="${cpulist[-1]}"
	avecpu=$(echo "scale=2;$sum/$line"|bc|sed 's/^\./0./')
}

disk (){
	partition=($(grep "^\/dev" $REPORT/df_-al|awk '{print $1}'))
	totaldisk=($(grep "^\/dev" $REPORT/df_-al|awk '$2=sprintf("%.2f",$2/2^20)'  | awk '{print $2}'))
	useddisk=($(grep "^\/dev" $REPORT/df_-al|awk '$3=sprintf("%.2f",$3/2^20)'  | awk '{print $3}'))
	freedisk=($(grep "^\/dev" $REPORT/df_-al|awk '$4=sprintf("%.2f",$4/2^20)'  | awk '{print $4}'))
	percent=($(grep "^\/dev" $REPORT/df_-al| awk '{print $5}'))
}

number (){
	num=$((num+1)) 
}


option (){
echo "Hay Mr.$USER"
echo "What will you doing"
echo "1. generate summary report"
echo "2. combine sar"
read -p "Input (1/2) : " opt
if [ $opt = 1 ];then
	echo "Generating summary report..."
	summary
elif [ $opt = 2 ];then
	echo "Combining sar..."
	combinesar
else
	echo "sorry input error"
fi
}

summary (){
rule
bulan
extract
servername
combine
cpfile
header
for REPORT in $COMBINE/*;do
HOSTNAME=$(echo $REPORT|sed "s|$COMBINE/||")
if [[ $(ls -A $REPORT/sar) ]];then
number;addr;memory;cpu;disk;table
else
	echo "directory report/var/log/sa not found"
	echo "report for $HOSTNAME cannot proccess !!!"
fi
done
footer
cleanup
}

combinesar (){
rule
bulan
extract
servername
combine
merger
cleanup
}

table (){
cat >> report/$lmonth/$devprod/summary.html << EOF
   <tr height="18" style='height:13.50pt;mso-height-source:userset;mso-height-alt:270;'>
    <td class="xl92" height="18" align="right" style='height:13.50pt;'>$num</td>
    <td class="xl93"><pre>$HOSTNAME
$(for i in $(seq 0 $COUNT);do echo "${eth[$i]} | ${IP[$i]}";done)</pre></td>
    <td class="xl94"><pre>Total
Max
Min
Avg</pre></td>
    <td class="xl95"><pre>$memtotal
$maxmem
$minmem
$avemem</pre></td>
    <td class="xl96"><pre>Core
Max
Min
Avg</pre></td>
    <td class="xl95"><pre>$core
$maxcpu
$mincpu
$avecpu</pre></td>
    <td class="xl93"><pre>$(IFS=$'\n';echo "${partition[*]}")</pre></td>
    <td class="xl93"><pre>$(IFS=$'\n';echo "${totaldisk[*]}")</pre></td>
    <td class="xl93"><pre>$(IFS=$'\n';echo "${useddisk[*]}")</pre></td>
    <td class="xl93"><pre>$(IFS=$'\n';echo "${freedisk[*]}")</pre></td>
    <td class="xl97"><pre>$(IFS=$'\n';echo "${percent[*]}")</pre></td>
   </tr>
EOF

}

header (){
	mkdir -p report/$lmonth/$devprod

cat > report/$lmonth/$devprod/summary.html << EOF
<html xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:x="urn:schemas-microsoft-com:office:excel" xmlns="http://www.w3.org/TR/REC-html40">
 <head>
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
  <style>
tr
	{mso-height-source:auto;
	mso-ruby-visibility:none;}
col
	{mso-width-source:auto;
	mso-ruby-visibility:none;}
br
	{mso-data-placement:same-cell;}
.style0
	{mso-number-format:"General";
	text-align:general;
	vertical-align:middle;
	white-space:nowrap;
	mso-rotate:0;
	mso-pattern:auto;
	mso-background-source:auto;
	color:#5B6469;
	font-size:11.0pt;
	font-weight:400;
	font-style:normal;
	text-decoration:none;
	font-family:Calibri;
	mso-generic-font-family:auto;
	mso-font-charset:134;
	border:none;
	mso-protection:locked visible;
	mso-style-name:"Normal";
	mso-style-id:0;}
.style16
	{mso-pattern:auto none;
	background:#A9D08E;
	color:#FFFFFF;
	font-size:11.0pt;
	font-weight:400;
	font-style:normal;
	text-decoration:none;
	font-family:Calibri;
	mso-generic-font-family:auto;
	mso-font-charset:0;
	mso-style-name:"60% - Accent6";}
.style17
	{mso-pattern:auto none;
	background:#C6E0B4;
	color:#5B6469;
	font-size:11.0pt;
	font-weight:400;
	font-style:normal;
	text-decoration:none;
	font-family:Calibri;
	mso-generic-font-family:auto;
	mso-font-charset:0;
	mso-style-name:"40% - Accent6";}
.style18
	{mso-pattern:auto none;
	background:#8EA9DB;
	color:#FFFFFF;
	font-size:11.0pt;
	font-weight:400;
	font-style:normal;
	text-decoration:none;
	font-family:Calibri;
	mso-generic-font-family:auto;
	mso-font-charset:0;
	mso-style-name:"60% - Accent5";}
.style19
	{mso-pattern:auto none;
	background:#70AD47;
	color:#FFFFFF;
	font-size:11.0pt;
	font-weight:400;
	font-style:normal;
	text-decoration:none;
	font-family:Calibri;
	mso-generic-font-family:auto;
	mso-font-charset:0;
	mso-style-name:"Accent6";}
.style20
	{mso-pattern:auto none;
	background:#B4C6E7;
	color:#5B6469;
	font-size:11.0pt;
	font-weight:400;
	font-style:normal;
	text-decoration:none;
	font-family:Calibri;
	mso-generic-font-family:auto;
	mso-font-charset:0;
	mso-style-name:"40% - Accent5";}
.style21
	{mso-pattern:auto none;
	background:#D9E1F2;
	color:#5B6469;
	font-size:11.0pt;
	font-weight:400;
	font-style:normal;
	text-decoration:none;
	font-family:Calibri;
	mso-generic-font-family:auto;
	mso-font-charset:0;
	mso-style-name:"20% - Accent5";}
.style22
	{mso-pattern:auto none;
	background:#FFD966;
	color:#FFFFFF;
	font-size:11.0pt;
	font-weight:400;
	font-style:normal;
	text-decoration:none;
	font-family:Calibri;
	mso-generic-font-family:auto;
	mso-font-charset:0;
	mso-style-name:"60% - Accent4";}
.style23
	{mso-pattern:auto none;
	background:#4472C4;
	color:#FFFFFF;
	font-size:11.0pt;
	font-weight:400;
	font-style:normal;
	text-decoration:none;
	font-family:Calibri;
	mso-generic-font-family:auto;
	mso-font-charset:0;
	mso-style-name:"Accent5";}
.style24
	{mso-pattern:auto none;
	background:#FFE699;
	color:#5B6469;
	font-size:11.0pt;
	font-weight:400;
	font-style:normal;
	text-decoration:none;
	font-family:Calibri;
	mso-generic-font-family:auto;
	mso-font-charset:0;
	mso-style-name:"40% - Accent4";}
.style25
	{mso-pattern:auto none;
	background:#FFC000;
	color:#FFFFFF;
	font-size:11.0pt;
	font-weight:400;
	font-style:normal;
	text-decoration:none;
	font-family:Calibri;
	mso-generic-font-family:auto;
	mso-font-charset:0;
	mso-style-name:"Accent4";}
.style26
	{color:#FA7D00;
	font-size:11.0pt;
	font-weight:400;
	font-style:normal;
	text-decoration:none;
	font-family:Calibri;
	mso-generic-font-family:auto;
	mso-font-charset:0;
	border-bottom:2.0pt double #FF8001;
	mso-style-name:"Linked Cell";}
.style27
	{mso-pattern:auto none;
	background:#DBDBDB;
	color:#5B6469;
	font-size:11.0pt;
	font-weight:400;
	font-style:normal;
	text-decoration:none;
	font-family:Calibri;
	mso-generic-font-family:auto;
	mso-font-charset:0;
	mso-style-name:"40% - Accent3";}
.style28
	{mso-pattern:auto none;
	background:#F4B084;
	color:#FFFFFF;
	font-size:11.0pt;
	font-weight:400;
	font-style:normal;
	text-decoration:none;
	font-family:Calibri;
	mso-generic-font-family:auto;
	mso-font-charset:0;
	mso-style-name:"60% - Accent2";}
.style29
	{mso-pattern:auto none;
	background:#A5A5A5;
	color:#FFFFFF;
	font-size:11.0pt;
	font-weight:400;
	font-style:normal;
	text-decoration:none;
	font-family:Calibri;
	mso-generic-font-family:auto;
	mso-font-charset:0;
	mso-style-name:"Accent3";}
.style30
	{mso-pattern:auto none;
	background:#F8CBAD;
	color:#5B6469;
	font-size:11.0pt;
	font-weight:400;
	font-style:normal;
	text-decoration:none;
	font-family:Calibri;
	mso-generic-font-family:auto;
	mso-font-charset:0;
	mso-style-name:"40% - Accent2";}
.style31
	{mso-pattern:auto none;
	background:#FCE4D6;
	color:#5B6469;
	font-size:11.0pt;
	font-weight:400;
	font-style:normal;
	text-decoration:none;
	font-family:Calibri;
	mso-generic-font-family:auto;
	mso-font-charset:0;
	mso-style-name:"20% - Accent2";}
.style32
	{mso-pattern:auto none;
	background:#ED7D31;
	color:#FFFFFF;
	font-size:11.0pt;
	font-weight:400;
	font-style:normal;
	text-decoration:none;
	font-family:Calibri;
	mso-generic-font-family:auto;
	mso-font-charset:0;
	mso-style-name:"Accent2";}
.style33
	{mso-pattern:auto none;
	background:#BDD7EE;
	color:#5B6469;
	font-size:11.0pt;
	font-weight:400;
	font-style:normal;
	text-decoration:none;
	font-family:Calibri;
	mso-generic-font-family:auto;
	mso-font-charset:0;
	mso-style-name:"40% - Accent1";}
.style34
	{mso-pattern:auto none;
	background:#5B9BD5;
	color:#FFFFFF;
	font-size:11.0pt;
	font-weight:400;
	font-style:normal;
	text-decoration:none;
	font-family:Calibri;
	mso-generic-font-family:auto;
	mso-font-charset:0;
	mso-style-name:"Accent1";}
.style35
	{mso-number-format:"_ * \#\,\#\#0_ \;_ * \\-\#\,\#\#0_ \;_ * \0022-\0022_ \;_ \@_ ";
	mso-style-name:"Comma[0]";
	mso-style-id:6;}
.style36
	{mso-pattern:auto none;
	background:#FFEB9C;
	color:#9C6500;
	font-size:11.0pt;
	font-weight:400;
	font-style:normal;
	text-decoration:none;
	font-family:Calibri;
	mso-generic-font-family:auto;
	mso-font-charset:0;
	mso-style-name:"Neutral";}
.style37
	{mso-pattern:auto none;
	background:#9BC2E6;
	color:#FFFFFF;
	font-size:11.0pt;
	font-weight:400;
	font-style:normal;
	text-decoration:none;
	font-family:Calibri;
	mso-generic-font-family:auto;
	mso-font-charset:0;
	mso-style-name:"60% - Accent1";}
.style38
	{mso-pattern:auto none;
	background:#FFC7CE;
	color:#9C0006;
	font-size:11.0pt;
	font-weight:400;
	font-style:normal;
	text-decoration:none;
	font-family:Calibri;
	mso-generic-font-family:auto;
	mso-font-charset:0;
	mso-style-name:"Bad";}
.style39
	{mso-pattern:auto none;
	background:#FFF2CC;
	color:#5B6469;
	font-size:11.0pt;
	font-weight:400;
	font-style:normal;
	text-decoration:none;
	font-family:Calibri;
	mso-generic-font-family:auto;
	mso-font-charset:0;
	mso-style-name:"20% - Accent4";}
.style40
	{color:#5B6469;
	font-size:11.0pt;
	font-weight:700;
	font-style:normal;
	text-decoration:none;
	font-family:Calibri;
	mso-generic-font-family:auto;
	mso-font-charset:0;
	border-top:.5pt solid #5B9BD5;
	border-bottom:2.0pt double #5B9BD5;
	mso-style-name:"Total";}
.style41
	{mso-pattern:auto none;
	background:#F2F2F2;
	color:#3F3F3F;
	font-size:11.0pt;
	font-weight:700;
	font-style:normal;
	text-decoration:none;
	font-family:Calibri;
	mso-generic-font-family:auto;
	mso-font-charset:0;
	border:.5pt solid #3F3F3F;
	mso-style-name:"Output";}
.style42
	{mso-number-format:"_\(\\$* \#\,\#\#0\.00_\)\;_\(\\$* \\\(\#\,\#\#0\.00\\\)\;_\(\\$* \0022-\0022??_\)\;_\(\@_\)";
	mso-style-name:"Currency";
	mso-style-id:4;}
.style43
	{mso-pattern:auto none;
	background:#EDEDED;
	color:#5B6469;
	font-size:11.0pt;
	font-weight:400;
	font-style:normal;
	text-decoration:none;
	font-family:Calibri;
	mso-generic-font-family:auto;
	mso-font-charset:0;
	mso-style-name:"20% - Accent3";}
.style44
	{mso-pattern:auto none;
	background:#FFFFCC;
	border:.5pt solid #B2B2B2;
	mso-style-name:"Note";}
.style45
	{mso-pattern:auto none;
	background:#FFCC99;
	color:#3F3F76;
	font-size:11.0pt;
	font-weight:400;
	font-style:normal;
	text-decoration:none;
	font-family:Calibri;
	mso-generic-font-family:auto;
	mso-font-charset:0;
	border:.5pt solid #7F7F7F;
	mso-style-name:"Input";}
.style46
	{color:#44546A;
	font-size:11.0pt;
	font-weight:700;
	font-style:normal;
	text-decoration:none;
	font-family:Calibri;
	mso-generic-font-family:auto;
	mso-font-charset:134;
	mso-style-name:"Heading 4";}
.style47
	{mso-pattern:auto none;
	background:#F2F2F2;
	color:#FA7D00;
	font-size:11.0pt;
	font-weight:700;
	font-style:normal;
	text-decoration:none;
	font-family:Calibri;
	mso-generic-font-family:auto;
	mso-font-charset:0;
	border:.5pt solid #7F7F7F;
	mso-style-name:"Calculation";}
.style48
	{mso-pattern:auto none;
	background:#C6EFCE;
	color:#006100;
	font-size:11.0pt;
	font-weight:400;
	font-style:normal;
	text-decoration:none;
	font-family:Calibri;
	mso-generic-font-family:auto;
	mso-font-charset:0;
	mso-style-name:"Good";}
.style49
	{color:#44546A;
	font-size:11.0pt;
	font-weight:700;
	font-style:normal;
	text-decoration:none;
	font-family:Calibri;
	mso-generic-font-family:auto;
	mso-font-charset:134;
	border-bottom:1.0pt solid #ACCCEA;
	mso-style-name:"Heading 3";}
.style50
	{color:#7F7F7F;
	font-size:11.0pt;
	font-weight:400;
	font-style:italic;
	text-decoration:none;
	font-family:Calibri;
	mso-generic-font-family:auto;
	mso-font-charset:0;
	mso-style-name:"CExplanatory Text";}
.style51
	{mso-pattern:auto none;
	background:#C9C9C9;
	color:#FFFFFF;
	font-size:11.0pt;
	font-weight:400;
	font-style:normal;
	text-decoration:none;
	font-family:Calibri;
	mso-generic-font-family:auto;
	mso-font-charset:0;
	mso-style-name:"60% - Accent3";}
.style52
	{mso-number-format:"_\(\\$* \#\,\#\#0_\)\;_\(\\$* \\\(\#\,\#\#0\\\)\;_\(\\$* \0022-\0022_\)\;_\(\@_\)";
	mso-style-name:"Currency[0]";
	mso-style-id:7;}
.style53
	{color:#44546A;
	font-size:15.0pt;
	font-weight:700;
	font-style:normal;
	text-decoration:none;
	font-family:Calibri;
	mso-generic-font-family:auto;
	mso-font-charset:134;
	border-bottom:1.0pt solid #5B9BD5;
	mso-style-name:"Heading 1";}
.style54
	{mso-pattern:auto none;
	background:#E2EFDA;
	color:#5B6469;
	font-size:11.0pt;
	font-weight:400;
	font-style:normal;
	text-decoration:none;
	font-family:Calibri;
	mso-generic-font-family:auto;
	mso-font-charset:0;
	mso-style-name:"20% - Accent6";}
.style55
	{color:#44546A;
	font-size:18.0pt;
	font-weight:700;
	font-style:normal;
	text-decoration:none;
	font-family:Calibri;
	mso-generic-font-family:auto;
	mso-font-charset:134;
	mso-style-name:"Title";}
.style56
	{color:#FF0000;
	font-size:11.0pt;
	font-weight:400;
	font-style:normal;
	text-decoration:none;
	font-family:Calibri;
	mso-generic-font-family:auto;
	mso-font-charset:0;
	mso-style-name:"Warning Text";}
.style57
	{mso-pattern:auto none;
	background:#DDEBF7;
	color:#5B6469;
	font-size:11.0pt;
	font-weight:400;
	font-style:normal;
	text-decoration:none;
	font-family:Calibri;
	mso-generic-font-family:auto;
	mso-font-charset:0;
	mso-style-name:"20% - Accent1";}
.style58
	{color:#0000FF;
	font-size:11.0pt;
	font-weight:400;
	font-style:normal;
	text-decoration:underline;
	text-underline-style:single;
	font-family:Calibri;
	mso-generic-font-family:auto;
	mso-font-charset:0;
	mso-style-name:"Hyperlink";
	mso-style-id:8;}
.style59
	{color:#800080;
	font-size:11.0pt;
	font-weight:400;
	font-style:normal;
	text-decoration:underline;
	text-underline-style:single;
	font-family:Calibri;
	mso-generic-font-family:auto;
	mso-font-charset:0;
	mso-style-name:"Followed Hyperlink";
	mso-style-id:9;}
.style60
	{color:#44546A;
	font-size:13.0pt;
	font-weight:700;
	font-style:normal;
	text-decoration:none;
	font-family:Calibri;
	mso-generic-font-family:auto;
	mso-font-charset:134;
	border-bottom:1.0pt solid #5B9BD5;
	mso-style-name:"Heading 2";}
.style61
	{mso-number-format:"_ * \#\,\#\#0\.00_ \;_ * \\-\#\,\#\#0\.00_ \;_ * \0022-\0022??_ \;_ \@_ ";
	mso-style-name:"Comma";
	mso-style-id:3;}
.style62
	{mso-pattern:auto none;
	background:#A5A5A5;
	color:#FFFFFF;
	font-size:11.0pt;
	font-weight:700;
	font-style:normal;
	text-decoration:none;
	font-family:Calibri;
	mso-generic-font-family:auto;
	mso-font-charset:0;
	border:2.0pt double #3F3F3F;
	mso-style-name:"Check Cell";}
.style63
	{mso-number-format:"0%";
	mso-style-name:"Percent";
	mso-style-id:5;}
td
	{mso-style-parent:style0;
	padding-top:1px;
	padding-right:1px;
	padding-left:1px;
	mso-ignore:padding;
	mso-number-format:"General";
	text-align:general;
	vertical-align:middle;
	white-space:nowrap;
	mso-rotate:0;
	mso-pattern:auto;
	mso-background-source:auto;
	color:#5B6469;
	font-size:11.0pt;
	font-weight:400;
	font-style:normal;
	text-decoration:none;
	font-family:Calibri;
	mso-generic-font-family:auto;
	mso-font-charset:134;
	border:none;
	mso-protection:locked visible;}
.xl65
	{mso-style-parent:style0;
	text-align:center;
	white-space:normal;
	mso-pattern:auto none;
	background:#9B9B9B;
	color:#000000;
	font-size:10.0pt;
	font-weight:700;
	mso-font-charset:134;
	border:.5pt solid windowtext;}
.xl66
	{mso-style-parent:style0;
	text-align:center;
	mso-pattern:auto none;
	background:#9B9B9B;
	color:#000000;
	font-size:10.0pt;
	font-weight:700;
	mso-font-charset:134;
	border:.5pt solid windowtext;}
.xl67
	{mso-style-parent:style0;
	text-align:center;
	white-space:normal;
	mso-pattern:auto none;
	background:#9B9B9B;
	color:#000000;
	font-size:10.0pt;
	font-weight:700;
	mso-font-charset:134;
	border-top:.5pt solid windowtext;
	border-right:.5pt solid windowtext;}
.xl68
	{mso-style-parent:style0;
	text-align:center;
	vertical-align:top;
	white-space:normal;
	color:#000000;
	font-size:10.0pt;
	mso-font-charset:134;
	border:.5pt solid windowtext;}
.xl69
	{mso-style-parent:style0;
	text-align:left;
	vertical-align:top;
	white-space:normal;
	color:#000000;
	font-size:10.0pt;
	font-family:Arial Unicode MS;
	mso-font-charset:134;
	border-left:.5pt solid windowtext;
	border-top:.5pt solid windowtext;
	border-right:.5pt solid windowtext;}
.xl70
	{mso-style-parent:style0;
	text-align:left;
	vertical-align:top;
	white-space:normal;
	color:#000000;
	font-size:10.0pt;
	font-family:Arial Unicode MS;
	mso-font-charset:134;
	border-top:.5pt solid windowtext;}
.xl71
	{mso-style-parent:style0;
	text-align:left;
	vertical-align:top;
	white-space:normal;
	color:#000000;
	font-size:10.0pt;
	font-family:Arial Unicode MS;
	mso-font-charset:134;
	border-top:.5pt solid windowtext;
	border-right:.5pt solid windowtext;}
.xl72
	{mso-style-parent:style0;
	text-align:left;
	vertical-align:top;
	white-space:normal;
	color:#000000;
	font-size:10.0pt;
	font-family:Arial Unicode MS;
	mso-font-charset:134;
	border-left:.5pt solid windowtext;
	border-right:.5pt solid windowtext;}
.xl73
	{mso-style-parent:style0;
	text-align:left;
	vertical-align:top;
	white-space:normal;
	color:#000000;
	font-size:10.0pt;
	font-family:Arial Unicode MS;
	mso-font-charset:134;}
.xl74
	{mso-style-parent:style0;
	text-align:left;
	vertical-align:top;
	white-space:normal;
	color:#000000;
	font-size:10.0pt;
	font-family:Arial Unicode MS;
	mso-font-charset:134;
	border-right:.5pt solid windowtext;}
.xl75
	{mso-style-parent:style0;
	mso-font-charset:134;
	border-left:.5pt solid windowtext;
	border-right:.5pt solid windowtext;}
.xl76
	{mso-style-parent:style0;
	mso-font-charset:134;
	border-right:.5pt solid windowtext;}
.xl77
	{mso-style-parent:style0;
	text-align:center;
	white-space:normal;
	mso-pattern:auto none;
	background:#9B9B9B;
	color:#000000;
	font-size:10.0pt;
	font-weight:700;
	mso-font-charset:134;
	border-left:.5pt solid windowtext;
	border-top:.5pt solid windowtext;
	border-right:.5pt solid windowtext;}
.xl78
	{mso-style-parent:style0;
	text-align:left;
	vertical-align:top;
	white-space:normal;
	color:#000000;
	font-size:10.0pt;
	font-family:Arial Unicode MS;
	mso-font-charset:134;
	border-left:.5pt solid windowtext;
	border-top:.5pt solid windowtext;}
.xl79
	{mso-style-parent:style0;
	text-align:left;
	vertical-align:top;
	white-space:normal;
	color:#000000;
	font-size:10.0pt;
	font-family:Arial Unicode MS;
	mso-font-charset:134;
	border-left:.5pt solid windowtext;}
.xl80
	{mso-style-parent:style0;
	mso-font-charset:134;
	border-left:.5pt solid windowtext;}
.xl81
	{mso-style-parent:style0;
	mso-number-format:"0%";
	text-align:left;
	vertical-align:top;
	white-space:normal;
	color:#000000;
	font-size:10.0pt;
	font-family:Arial Unicode MS;
	mso-font-charset:134;
	border-left:.5pt solid windowtext;
	border-top:.5pt solid windowtext;
	border-right:.5pt solid windowtext;}
.xl82
	{mso-style-parent:style0;
	mso-number-format:"0%";
	text-align:left;
	vertical-align:top;
	white-space:normal;
	color:#000000;
	font-size:10.0pt;
	font-family:Arial Unicode MS;
	mso-font-charset:134;
	border-left:.5pt solid windowtext;
	border-right:.5pt solid windowtext;}
.xl84
	{mso-style-parent:style0;
	mso-font-charset:134;
	border-left:.5pt solid windowtext;
	border-right:.5pt solid windowtext;
	border-bottom:.5pt solid windowtext;}
.xl85
	{mso-style-parent:style0;
	mso-font-charset:134;
	border-bottom:.5pt solid windowtext;}
.xl86
	{mso-style-parent:style0;
	mso-font-charset:134;
	border-right:.5pt solid windowtext;
	border-bottom:.5pt solid windowtext;}
.xl87
	{mso-style-parent:style0;
	mso-font-charset:134;
	border-left:.5pt solid windowtext;
	border-bottom:.5pt solid windowtext;}
.xl88
	{mso-style-parent:style0;
	text-align:left;
	vertical-align:top;
	white-space:normal;
	color:#000000;
	font-size:10.0pt;
	font-family:Arial Unicode MS;
	mso-font-charset:134;
	border-left:.5pt solid windowtext;
	border-right:.5pt solid windowtext;
	border-bottom:.5pt solid windowtext;}
.xl89
	{mso-style-parent:style0;
	mso-number-format:"0%";
	text-align:left;
	vertical-align:top;
	white-space:normal;
	color:#000000;
	font-size:10.0pt;
	font-family:Arial Unicode MS;
	mso-font-charset:134;
	border-left:.5pt solid windowtext;
	border-right:.5pt solid windowtext;
	border-bottom:.5pt solid windowtext;}
.xl92
	{mso-style-parent:style0;
	vertical-align:top;
	white-space:normal;
	color:#000000;
	font-size:10.0pt;
	mso-font-charset:134;
	border:.5pt solid windowtext;}
.xl93
	{mso-style-parent:style0;
	text-align:left;
	vertical-align:top;
	white-space:normal;
	color:#000000;
	font-size:10.0pt;
	font-family:Arial Unicode MS;
	mso-font-charset:134;
	border:.5pt solid windowtext;}
.xl94
	{mso-style-parent:style0;
	text-align:left;
	vertical-align:top;
	white-space:normal;
	color:#000000;
	font-size:10.0pt;
	font-family:Arial Unicode MS;
	mso-font-charset:134;
	border-top:.5pt solid windowtext;
	border-bottom:.5pt solid windowtext;}
.xl95
	{mso-style-parent:style0;
	text-align:left;
	vertical-align:top;
	white-space:normal;
	color:#000000;
	font-size:10.0pt;
	font-family:Arial Unicode MS;
	mso-font-charset:134;
	border-top:.5pt solid windowtext;
	border-right:.5pt solid windowtext;
	border-bottom:.5pt solid windowtext;}
.xl96
	{mso-style-parent:style0;
	text-align:left;
	vertical-align:top;
	white-space:normal;
	color:#000000;
	font-size:10.0pt;
	font-family:Arial Unicode MS;
	mso-font-charset:134;
	border-left:.5pt solid windowtext;
	border-top:.5pt solid windowtext;
	border-bottom:.5pt solid windowtext;}
.xl97
	{mso-style-parent:style0;
	mso-number-format:"0%";
	text-align:left;
	vertical-align:top;
	white-space:normal;
	color:#000000;
	font-size:10.0pt;
	font-family:Arial Unicode MS;
	mso-font-charset:134;
	border:.5pt solid windowtext;}
<!-- @page
	{margin:0.98in 0.75in 0.98in 0.75in;
	mso-header-margin:0.51in;
	mso-footer-margin:0.51in;}
 -->  </style>
 </head>
 <body link="blue" vlink="purple">
  <table width="740.33" border="0" cellpadding="0" cellspacing="0" style='width:555.25pt;border-collapse:collapse;table-layout:fixed;'>
   <col width="30" style='mso-width-source:userset;mso-width-alt:960;'/>
   <col width="202.33" style='mso-width-source:userset;mso-width-alt:6474;'/>
   <col width="41" span="4" style='mso-width-source:userset;mso-width-alt:1312;'/>
   <col width="220" style='mso-width-source:userset;mso-width-alt:5632;'/>
   <col width="48" span="4" style='mso-width-source:userset;mso-width-alt:1344;'/>
   <tr height="18" style='height:13.50pt;mso-height-source:userset;mso-height-alt:270;'>
    <td class="xl65" height="50" width="30" rowspan="2" style='height:37.50pt;width:22.50pt;border-right:.5pt solid windowtext;border-bottom:none;'>No</td>
    <td class="xl66" width="202.33" rowspan="2" style='width:151.75pt;border-right:.5pt solid windowtext;border-bottom:none;'>Server Name &amp; IP</td>
    <td class="xl67" width="82" colspan="2" rowspan="2" style='width:61.50pt;border-right:.5pt solid windowtext;border-bottom:none;'>Memory (GB)</td>
    <td class="xl77" width="82" colspan="2" rowspan="2" style='width:61.50pt;border-right:.5pt solid windowtext;border-bottom:none;'>Processor</td>
    <td class="xl65" width="344" colspan="5" style='width:258.00pt;border-right:.5pt solid windowtext;border-bottom:.5pt solid windowtext;'>Kapasitas Disk (GB)</td>
   </tr>
   <tr height="32" style='height:24.00pt;'>
    <td class="xl77">Partition</td>
    <td class="xl77">Size</td>
    <td class="xl77">Used</td>
    <td class="xl77">Free</td>
    <td class="xl77">Used (%)</td>
   </tr>
EOF
}

footer (){
cat >> report/$lmonth/$devprod/summary.html << EOF
  </table>
 </body>
</html>
EOF

echo -e "\nDone!!\n"
}

option
