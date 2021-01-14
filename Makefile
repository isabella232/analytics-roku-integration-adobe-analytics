#########################################################################
# Makefile Usage:
# > make install ' run app without tests
# > make test ' run app with tests
# > make library ' create distribution package of the library
#
# 1) Make sure that you have the curl command line executable in your path
# 2) Set the variable ROKU_DEV_TARGET in your environment to the IP
#    address of your Roku box. (e.g. export ROKU_DEV_TARGET=192.168.1.1.
#    Set in your this variable in your shell startup (e.g. .bashrc)
# 3) and set up the ROKU_DEV_PASSWORD environment variable, too
##########################################################################

check:
	bsc --project ./.build/bsconfig.json

library:
	echo "Building Adobe integration library package"
	rm -rf SegmentAdobeAnalytics
	rm -rf SegmentAdobeAnalytics.zip
	mkdir -p "SegmentAdobeAnalytics/source/library/Segment SDK/"
	cp source/analytics/SegmentAdobeIntegration.brs "SegmentAdobeAnalytics/source/library/Segment SDK/"
	zip -r SegmentAdobeAnalytics.zip SegmentAdobeAnalytics
	rm -rf SegmentAdobeAnalytics

test: remove install
	echo "Running tests"
	curl -d '' "http://${ROKU_DEV_TARGET}:8060/keypress/home" 
	curl -d '' "http://${ROKU_DEV_TARGET}:8060/launch/dev?RunTests=true"
	sleep 5 | telnet ${ROKU_DEV_TARGET} 8085

remove:
	make -f app.mk remove

install:
	make -f app.mk install
