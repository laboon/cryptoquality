#!/bin/sh
# ^ Shebang allows this script to be called from command line via './nano.sh'

# Sets start time for this script to be used in timing
start=`date +%s`

# Sets the current directory as the 'root' of the nano directory
NANO_PATH=$(pwd)

# Check if directory 'bitcoin-abc' exists, if not, clone it from the repo
# Otherwise, pull from the repo and see if there have been changes
# since this script was run last, if not, exit
if [ ! -d "${NANO_PATH}/raiblocks" ]; then
	git clone https://github.com/nanocurrency/raiblocks.git
	cd raiblocks
else
	cd raiblocks
	GIT_OUTPUT=$(git pull)

	if [ "${GIT_OUTPUT}" = 'Already up-to-date.' ]; then
		echo "No updates since last run, exiting"
		exit
	fi
fi

# Check to see if lizard is installed, if so, run it on the repo and output the results to
# the file 'nanouncomp.txt' otherwise print a message indicating lizard needs to be installed, then exit
if which lizard >/dev/null; then
	echo "Running lizard on uncompiled code"
	lizard -l cpp > ../nanolizarduncomp.txt

	echo "Trimming lizard results"
	../../lizardtrim.py ../nanolizarduncomp.txt
else
	echo "Lizard not found, please install lizard to complete analysis"
	exit
fi

# Check that lcov is installed, if not print a message indicating it needs to be installed
# then exit, otherwise continue with the script
if ! which lcov >/dev/null; then
	echo "lcov not found, please install lcov to complete analysis"
	exit
fi

echo "Pulling docker image"

# Pull or update docker image as needed
sudo docker pull nanocurrency/nano

echo "Making..."

# Configurations and making node are performed in a single line
	# "-d" Starts the docker container as a daemon
	# "-p 7075:7075/udp" Maps the network activity port
	# "-p 7075:7075" Maps the bootstrapping TCP port
	# "-p [::1]:7076:7076" Maps the RPC control port to the local adapter only
	# "~/:root" Maps the host's home directory to the guest /root directory
	# "nanocurrency/nano" Specifies the container to execute
sudo docker run -d -p 7075:7075/udp -p 7075:7075 -p [::1]:7076:7076 -v ~:/root nanocurrency/nano

# Run lizard again on the compiled code and output the results to 'nanolizard.txt'
# Is this the correct directory???
echo "Running lizard on compiled code"
lizard -l cpp > ../nanolizard.txt

# Using the script 'trimlizard.py' parse out the necessary numbers from the lizard results
# Those number will be the number of lines of code and the cyclomatic complexity
# These will be the only two numbers in the file after this script is run
echo "Trimming lizard results"
../../lizardtrim.py ../nanolizard.txt

echo "Running cppcheck..."

# Run cppcheck on the node
	# the -j option indicates how many threads we would like to use to do the checking (The more the merrier right?)
	# the -q option is quiet, we don't want the progress printed to the screen, remove if you'd like to see the progress
	# the --force (or equivalent -f) option tells cppcheck to go down through all the if/else branches and check them, will get an error without this option
	# the --enable-warning option tells cppcheck to output warnings in addition to errors as it checks the code
cppcheck -j 750 -q --force --enable=warning src 2> ../nanocppcheck.txt

# The test executables live here after making, thus move to this directory so they can be run
cd src/test/

# The test_bitcoin executable generates the .gcda files which are necessary for lcov later on
# plus it actually tests the code base, convenient!
#./test_bitcoin

# This step isn't necessary, but it makes repeatedly running this script easier as we keep a
# copy of the .gcno and .gcda files in the data directory, thus we can clear the previous lcov
# test info without messing up future lcov analysis by accidentally deleting a .gcno file or
# something like that
cd data

echo "Clearing previous tests"

# Clears previous lcov findings in the src/test/data directory
lcov --zerocounts --directory . > /dev/null 2>&1

# two lines below copy the .gcno and .gcda files from the src/test/ directory
cp ../*.gcno .

cp ../*.gcda .

echo "Generating test logs"

# This is where the .info file is generated by lcov, which breaks down the code coverage
# The directory option indicates that the .gcno and .gcda files are in the current directory (note the .)
# The capture option indicates we want to collect code coverage information from the .gcno and .gcda files
# The output file option names the resulting .info file whatever we wish to call it (Here, bcc_test)
# The redirect at the end simply directs the output of lcov to null as it spits out a lot of info we don't need
lcov --directory . --capture --output-file bitcoincash_test.info > /dev/null 2>&1

echo "Generating report"

# This generates some html from the .info file we created above
# Again, we redirect the output to null as there's a lot of unneccessary info generated in the process
genhtml -o ../../../../lcov bitcoincash_test.info > /dev/null 2>&1

# Stores the ending time of the running of this script
end=`date +%s`

# Calculates the amount of time it took for this script to be run and outputs the result
# in the file 'bitcoincashtime.txt'
echo $((end - start)) > ../../../../bitcoincashtime.txt

exit

