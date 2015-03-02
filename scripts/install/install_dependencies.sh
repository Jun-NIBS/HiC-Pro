#!/bin/bash
## Nicolas Servant
## HiC-Pro
##
## This script aims in installing most of the dependies of the HiC-Pro tool.
## Serval checks are done to ensure compilation of code.
##


NORMAL="\\033[0;39m"
RED="\\033[0;31m"
BLUE="\\033[0;34m"
SOFT="HiC-Pro"


die() {
    echo -e "$RED""Exit - ""$*""$NORMAL" 1>&2
    exit 1
}

function usage {
    echo -e "Usage : ./install_all.sh"
    echo -e "-c"" <configuration install file>"
    echo -e "-h"" <help>"
    exit;
}

echo -e "$RED""Make sure internet connection works for your shell prompt under current user's privilege ...""$NORMAL";
echo -e "$BLUE""Starting $SOFT installation ...""$NORMAL";


################### Initialize ###################

set -- $(getopt c: "$@")
while [ $# -gt 0 ]
do
    case "$1" in
	(-c) conf=$2; shift;;
	(-h) usage;;
	(--) shift; break;;
	(-*) echo "$0: error - unrecognized option $1" 1>&2; exit 1;;
	(*)  break;;
    esac
    shift
done

################### Read the config file ###################

while read curline_read; do
    curline=${curline_read// /}
    if [[ $curline != \#* && ! -z $curline ]]; then
	var=`echo $curline | awk -F= '{print $1}'`
	val=`echo $curline | awk -F= '{print $2}'`

	if [[ $var =~ "_PATH" ]]
	then
	    if [[ ! -z $val ]]; then
		echo "export $val in PATH"
		export PATH=$val:$PATH
	    fi
	fi
    fi
done < $conf

################### Search standard tools ###################

#check for make
which make > /dev/null;
if [ $? != "0" ]; then
	echo -e "$RED""Can not proceed without make, please install and re-run (Mac users see: http://developer.apple.com/technologies/xcode.html)""NORMAL"
	exit 1;
fi

#check for g++
which g++ > /dev/null;
if [ $? != "0" ]; then
	echo -e "$RED""Can not proceed without g++, please install and re-run""NORMAL"
	exit 1;
fi

# check for unzip (bowtie)
which unzip > /dev/null;
if [ $? != "0" ]; then
    echo -e "$RED""Can not proceed without unzip, please install and re-run""NORMAL"
    exit 1;
fi

# perl
which perl > /dev/null;
if [ $? != "0" ]; then
    echo -e "$RED""Can not proceed without Perl, please install and re-run""NORMAL"
    exit 1;
fi

# python
which python > /dev/null;
if [ $? != "0" ]; then
    echo -e "$RED""Can not proceed without Python, please install and re-run""NORMAL"
    exit 1;
fi

#check OS (Unix/Linux or Mac)
os=`uname`;

# get the right download program
if [ "$os" = "Darwin" ]; then
	# use curl as the download program 
	get="curl -L -o"
else
	# use wget as the download program
	get="wget --no-check-certificate -O"
fi

if [ -d ./tmp ]; then
    rm -r ./tmp
fi
mkdir ./tmp
cd ./tmp

################ Install dependencies  ###################

PREFIX_BIN=/usr/bin

if [ ! -w $PREFIX_BIN ]; then
    PREFIX_BIN=${HOME}/bin;
fi

echo "Where should missing software prerequisites be installed ? [$PREFIX_BIN] "
read ans
ans=${ans:-$PREFIX_BIN}
PREFIX_BIN=$ans
if [ ! -d $PREFIX_BIN ]; then
    echo "Directory $PREFIX_BIN does not exist!"
    echo -n "Do you want to create $PREFIX_BIN folder ? (y/n) [n] : "
    read ans
    if [ XX${ans} = XXy ]; then
        mkdir $PREFIX_BIN || die "Cannot create  $PREFIX_BIN folder. Maybe missing super-user (root) permissions"
    else
        die "Must specify a directory to install required softwares!"
    fi
fi

if [ ! -w $PREFIX_BIN ]; then
    die "Cannot write to directory $PREFIX_BIN. Maybe missing super-user (root) permissions to write there.";
fi 

################  Python  ###################
echo  "Checking dependencies ... "

wasInstalled=0;
echo "Checking Python libraries ..."
python ../scripts/install/check_pythonlib.py > install_packages_check.Rout
if [ $? == "0" ]; then
    echo -e "$BLUE""The required Python libraries appear to be already installed. ""$NORMAL"
    wasInstalled=1;
else
    echo -e "$RED""Can not proceed without the required Python libraries, please install them and re-run""NORMAL"
    exit 1;
fi


################  R  ###################

wasInstalled=0;
which R > /dev/null;
if [ $? == "0" ]; then
    echo "Checking R installation ..."
    R CMD BATCH ../scripts/install/check_Rpackages.R > check_Rpackages.Rout
    check=`grep proc.time check_Rpackages.Rout`;
    if [ $? == "0" ]; then
	echo -e "$BLUE""The required R packages appear to be already installed. ""$NORMAL"
	wasInstalled=1;
    fi
else
    echo -e "$RED""Can not proceed without R, please install and re-run""NORMAL"
    exit 1;
fi

#Install R Packages
if [ $wasInstalled == 0 ]; then
    echo "Installing missing R packages ..."
    R CMD BATCH ../scripts/install/install_Rpackages.R install_Rpackages.Rout

    R CMD BATCH ../scripts/install/check_Rpackages.R > check_Rpackages.Rout
    check=`grep proc.time check_Rpackages.Rout`;
    if [ $? == "0" ]; then
	echo -e "$BLUE""R packages appear to be installed successfully""$NORMAL"
    else
	echo -e "$RED""R packages NOT installed successfully. Look at the tmp/install_Rpackages.Rout for additional informations""$NORMAL"; exit 1;
    fi
fi

################ Bowtie2 ###################

wasInstalled=0;
which bowtie2 > /dev/null;
if [ $? = "0" ]; then
	echo -e "$BLUE""Bowtie2 Aligner appears to be already installed. ""$NORMAL"
	wasInstalled=1;
fi


if [ $wasInstalled == 0 ]; then
    echo "Installing Bowtie2 ..."
    $get bowtie2-2.2.4-source.zip http://sourceforge.net/projects/bowtie-bio/files/bowtie2/2.2.4/bowtie2-2.2.4-source.zip/download
    unzip bowtie2-2.2.4-source.zip
    cd bowtie2-2.2.4
    make
    cd ..
    mv bowtie2-2.2.4 $PREFIX_BIN
    export PATH=$PREFIX_BIN/bowtie2-2.2.4/:$PATH
    wasInstalled=0;
fi
 
#some bowtie tests
if [ $wasInstalled == 0 ]; then
    check=`bowtie2 --version 2>&1`;
    if [ $? = "0" ]; then
	echo -e "$BLUE""Bowtie2 Aligner appears to be installed successfully""$NORMAL"
    else
	echo -e "$RED""Bowtie2 Aligner NOT installed successfully""$NORMAL"; exit 1;
    fi
fi

################ samtools  ###################

wasInstalled=0;
which samtools > /dev/null
if [ $? = "0" ]; then
	echo -e "$BLUE""Samtools appears to be already installed. ""$NORMAL"
	wasInstalled=1;
fi

if [ $wasInstalled == 0 ]; then
    echo "Installing samtools ..."
    #From sources
    $get samtools-1.1.tar.bz2  http://sourceforge.net/projects/samtools/files/samtools/1.1/samtools-1.1.tar.bz2/download
    tar -xvjpf samtools-1.1.tar.bz2
    cd samtools-1.1
    make
    cd ..
    mv samtools-1.1 $PREFIX_BIN
    export PATH=$PREFIX_BIN/samtools-1.1/:$PATH
    wasInstalled=0;
fi

if [ $wasInstalled == 0 ]; then
    check=`samtools view -h 2>&1 | grep -i options`;
    if [ $? = "0" ]; then
	echo -e "$BLUE""samtools appears to be installed successfully""$NORMAL"
    else
	echo -e "$RED""samtools NOT installed successfully""$NORMAL"; exit 1;
    fi
fi

## Clean up
cd ..
rm -rf ./tmp

echo -e "$RED""Dependencies checked !""$NORMAL"

################ Create the config-system file ###################
CUR_DIR=`pwd`
echo -e "$BLUE""Check $SOFT configuration ... ""$NORMAL"

echo "#######################################################################" > config-system.txt
echo "## $SOFT - System settings" >> config-system.txt
echo "#######################################################################" >> config-system.txt

echo "#######################################################################" >> config-system.txt
echo "## Required Software - Specified the DIRECTORY name of the executables" >> config-system.txt
echo "## If not specified, the program will try to locate the executable" >> config-system.txt
echo "## using the 'which' command" >> config-system.txt
echo "#######################################################################" >> config-system.txt

which R > /dev/null
if [ $? = "0" ]; then
    echo "R_PATH = "`dirname $(which R)` >> config-system.txt
else
    die "R_PATH not found. Exit." 
fi

which bowtie2 > /dev/null
if [ $? = "0" ]; then
    echo "BOWTIE2_PATH = "`dirname $(which bowtie2)`  >> config-system.txt
else
    die "BOWTIE2_PATH not found. Exit." 
fi

which samtools > /dev/null
if [ $? = "0" ]; then
    echo "SAMTOOLS_PATH = "`dirname $(which samtools)`  >> config-system.txt
else
    die "SAMTOOLS_PATH not found. Exit." 
fi

which perl > /dev/null
if [ $? = "0" ]; then
    echo "PERL_PATH = "`dirname $(which perl)`  >> config-system.txt
else
    die "PERL_PATH not found. Exit." 
fi

which python > /dev/null
if [ $? = "0" ]; then
    echo "PYTHON_PATH = "`dirname $(which python)` >> config-system.txt
else
    die "PYTHON_PATH not found. Exit."
fi

echo "INSTALL_PATH = $CUR_DIR" >> config-system.txt
echo "SCRIPTS = $CUR_DIR/scripts" >> config-system.txt
echo "SOURCES = $CUR_DIR/scripts/src" >> config-system.txt
echo "ANNOT_DIR = $CUR_DIR/annotation" >> config-system.txt

echo ;
## End of dependencies check ##